//! Persistent Nushell shell using PTY and OSC 133 for completion detection
//!
//! Note: Uses `Box<dyn MasterPty>` and `Box<dyn Child>` from portable-pty.
//! This is the library's API design for cross-platform support.
//! The overhead is negligible for a long-lived, I/O-bound object.
//! Can be optimized later with platform-specific code if needed.

use super::CommandExecutor;
use super::osc133;
use portable_pty::{Child, ChildKiller, CommandBuilder, MasterPty, PtySize, native_pty_system};
use std::io::{Read, Write};
use std::path::Path;
use std::sync::{Arc, Mutex, TryLockError, mpsc};
use std::time::Duration;

const BUFFER_SIZE: usize = 8192;
const STARTUP_TIMEOUT_SECS: u64 = 10;
/// Max queued PTY read chunks before the reader thread blocks (backpressure).
/// 64 chunks * 8KB = 512KB max buffered data.
const CHANNEL_CAPACITY: usize = 64;

/// DSR (Device Status Report) sequence: ESC [ 6 n
/// Reedline/crossterm sends this to query cursor position.
const DSR_SEQUENCE: &[u8] = b"\x1b[6n";

/// CPR (Cursor Position Report) response: row 1, col 1.
/// Reedline uses this to set prompt_start_row = 0.
const CPR_RESPONSE: &[u8] = b"\x1b[1;1R";

/// Messages sent from the background reader thread to the main thread.
enum PtyRead {
    Data(Vec<u8>),
    Eof,
    Error(String),
}

pub struct PersistentShell {
    writer: Box<dyn Write + Send>,
    osc_parser: osc133::Parser,
    reader_rx: mpsc::Receiver<PtyRead>,
    _master: Box<dyn MasterPty + Send>,
    child: Box<dyn Child + Send + Sync>,
}

impl Drop for PersistentShell {
    fn drop(&mut self) {
        // Kill the child process (sends SIGHUP then SIGKILL)
        if let Err(e) = self.child.kill() {
            eprintln!("Failed to kill shell process: {e}");
        }
        // Reap the process to avoid zombies
        if let Err(e) = self.child.wait() {
            eprintln!("Failed to wait on shell process: {e}");
        }
        // reader thread exits naturally when _master is dropped (PTY fd closes)
        // and reader_rx is dropped (tx.send fails)
    }
}

impl PersistentShell {
    /// Create a new persistent Nushell process
    pub fn new() -> Result<Self, String> {
        let pty_system = native_pty_system();
        let (rows, cols) = (24, 80);

        let pair = pty_system
            .openpty(PtySize {
                rows,
                cols,
                pixel_width: 0,
                pixel_height: 0,
            })
            .map_err(|e| format!("Failed to create PTY: {}", e))?;

        let mut cmd = CommandBuilder::new("nu");
        cmd.cwd(std::env::current_dir().map_err(|e| e.to_string())?);

        cmd.env("TERM", "xterm-256color");
        cmd.env("COLORTERM", "truecolor");
        cmd.env("NO_COLOR", "1");

        let child = pair
            .slave
            .spawn_command(cmd)
            .map_err(|e| format!("Failed to spawn nu: {}", e))?;

        drop(pair.slave);

        let master = pair.master;
        let writer = master
            .take_writer()
            .map_err(|e| format!("Failed to take writer: {}", e))?;

        // Spawn background reader thread: reads PTY in a loop, sends chunks via channel
        let mut reader = master
            .try_clone_reader()
            .map_err(|e| format!("Failed to clone reader: {}", e))?;
        let (tx, rx) = mpsc::sync_channel(CHANNEL_CAPACITY);
        std::thread::spawn(move || {
            let mut buf = [0u8; BUFFER_SIZE];
            loop {
                match reader.read(&mut buf) {
                    Ok(0) => {
                        let _ = tx.send(PtyRead::Eof);
                        break;
                    }
                    Ok(n) => {
                        if tx.send(PtyRead::Data(buf[..n].to_vec())).is_err() {
                            break; // receiver dropped
                        }
                    }
                    Err(e) => {
                        let _ = tx.send(PtyRead::Error(e.to_string()));
                        break;
                    }
                }
            }
        });

        let mut shell = Self {
            writer,
            osc_parser: osc133::Parser::new(),
            reader_rx: rx,
            _master: master,
            child,
        };

        shell.wait_for_prompt(Duration::from_secs(STARTUP_TIMEOUT_SECS))?;

        Ok(shell)
    }

    /// Get the process ID of the child Nushell process (for testing)
    #[cfg(test)]
    pub(crate) fn process_id(&self) -> Option<u32> {
        self.child.process_id()
    }

    /// Clone the child killer handle for signaling from another thread.
    /// This enables reset() to kill a running command without blocking on the shell mutex.
    pub fn clone_killer(&self) -> Box<dyn ChildKiller + Send + Sync> {
        self.child.clone_killer()
    }

    /// Scan data for DSR queries and respond with CPR.
    /// Reedline sends DSR to query cursor position; we respond so it can proceed.
    fn respond_to_dsr(&mut self, data: &[u8]) {
        if data.len() < DSR_SEQUENCE.len() {
            return;
        }
        for window in data.windows(DSR_SEQUENCE.len()) {
            if window == DSR_SEQUENCE {
                let _ = self.writer.write_all(CPR_RESPONSE);
                let _ = self.writer.flush();
                return;
            }
        }
    }

    /// Drain the reader channel, processing each chunk. Returns on timeout or error.
    fn drain_until<F>(&mut self, timeout: Duration, mut handler: F) -> Result<(), String>
    where
        F: FnMut(&mut Self, &[u8]) -> ControlFlow,
    {
        let deadline = std::time::Instant::now() + timeout;

        loop {
            let remaining = deadline
                .checked_duration_since(std::time::Instant::now())
                .unwrap_or(Duration::ZERO);

            if remaining.is_zero() {
                return Err(format!("Timeout after {} seconds", timeout.as_secs()));
            }

            match self.reader_rx.recv_timeout(remaining) {
                Ok(PtyRead::Data(data)) => {
                    if let ControlFlow::Break = handler(self, &data) {
                        return Ok(());
                    }
                }
                Ok(PtyRead::Eof) => return Err("PTY EOF".to_string()),
                Ok(PtyRead::Error(e)) => return Err(format!("PTY read error: {}", e)),
                Err(mpsc::RecvTimeoutError::Timeout) => {
                    return Err(format!("Timeout after {} seconds", timeout.as_secs()));
                }
                Err(mpsc::RecvTimeoutError::Disconnected) => {
                    return Err("PTY reader disconnected".to_string());
                }
            }
        }
    }

    fn wait_for_prompt(&mut self, timeout: Duration) -> Result<(), String> {
        let mut got_marker = false;

        self.drain_until(timeout, |shell, data| {
            shell.respond_to_dsr(data);
            shell.osc_parser.push(data, |_event| {
                got_marker = true;
            });
            if got_marker {
                ControlFlow::Break
            } else {
                ControlFlow::Continue
            }
        })?;

        if got_marker {
            Ok(())
        } else {
            Err("No OSC 133 marker detected".to_string())
        }
    }

    /// Execute a command and collect output.
    ///
    /// After wait_for_prompt / previous execute, Reedline is in event::read()
    /// waiting for input (A and B markers already emitted and consumed).
    ///
    /// We:
    /// 1. Write the command — Reedline processes it and returns to Nushell
    /// 2. Wait for C (CommandExecuted) — Nushell is about to run the command
    /// 3. Collect output between C and D (CommandFinished)
    pub fn execute(&mut self, command: &str, timeout: Duration) -> Result<CommandOutput, String> {
        // Trace file for debugging (only when MCP_PTY_TRACE is set)
        let trace = std::env::var("MCP_PTY_TRACE").is_ok();
        let mut trace_file = if trace {
            use std::fs::OpenOptions;
            OpenOptions::new()
                .create(true)
                .append(true)
                .open("/tmp/pty_trace.log")
                .ok()
        } else {
            None
        };

        macro_rules! trace_log {
            ($($arg:tt)*) => {
                if let Some(ref mut f) = trace_file {
                    use std::io::Write;
                    let _ = writeln!(f, $($arg)*);
                    let _ = f.flush();
                }
            };
        }

        trace_log!("=== EXECUTE: {:?} ===", command);

        // Establish single deadline for entire operation (command execution + prompt wait)
        let deadline = std::time::Instant::now() + timeout;

        // Write command — Reedline is in event::read(), ready for input
        writeln!(self.writer, "{}", command).map_err(|e| format!("Write failed: {}", e))?;
        self.writer
            .flush()
            .map_err(|e| format!("Flush failed: {}", e))?;

        // Wait for C→D, respond to DSR during prompt rendering phase
        let mut output_buffer = Vec::new();
        let mut final_exit_code: Option<i32> = None;
        let mut saw_command_executed = false;

        self.drain_until(timeout, |shell, data| {
            trace_log!("CHUNK len={} saw_c={}", data.len(), saw_command_executed,);

            // Respond to DSR during prompt phase (before C)
            if !saw_command_executed {
                shell.respond_to_dsr(data);
            }

            // Collect output bytes only after C
            if saw_command_executed {
                output_buffer.extend_from_slice(data);
            }

            let mut done = false;
            shell.osc_parser.push(data, |event| {
                trace_log!("  EVENT: {:?}", event);
                match event {
                    osc133::Event::CommandExecuted => {
                        saw_command_executed = true;
                    }
                    osc133::Event::CommandFinished { exit_code } => {
                        if saw_command_executed {
                            final_exit_code = exit_code;
                            done = true;
                        }
                    }
                    _ => {}
                }
            });

            if done {
                ControlFlow::Break
            } else {
                ControlFlow::Continue
            }
        })?;

        // Strip ANSI escape codes
        let clean = strip_ansi_escapes::strip(&output_buffer);
        let stdout = String::from_utf8_lossy(&clean).trim().to_string();

        // After D, the next prompt cycle starts (DSR queries → A → B).
        // Drain until B (CommandStart) so Reedline is back at event::read()
        // before we return. This prevents CPR response bytes from leaking
        // into the next command's input.
        //
        // Use remaining time from original deadline, with a 2s minimum floor
        // to allow prompt rendering. If this times out, we still return the
        // command output successfully - the next execute() handles re-sync naturally.
        let remaining = deadline
            .checked_duration_since(std::time::Instant::now())
            .unwrap_or(Duration::ZERO);
        let prompt_timeout = if remaining < Duration::from_secs(1) {
            Duration::from_secs(2)
        } else {
            remaining
        };

        let mut saw_next_ready = false;
        let prompt_wait_result = self.drain_until(prompt_timeout, |shell, data| {
            shell.respond_to_dsr(data);
            shell.osc_parser.push(data, |event| {
                if matches!(event, osc133::Event::CommandStart) {
                    saw_next_ready = true;
                }
            });
            if saw_next_ready {
                ControlFlow::Break
            } else {
                ControlFlow::Continue
            }
        });

        // If prompt wait timed out, log warning but don't fail - output was collected
        if prompt_wait_result.is_err() && !saw_next_ready {
            trace_log!("WARNING: Prompt wait timed out - shell may need re-sync on next command");
        }

        trace_log!(
            "=== RETURNING stdout={:?} exit={:?} ===",
            stdout,
            final_exit_code
        );

        Ok(CommandOutput {
            stdout,
            exit_code: final_exit_code.unwrap_or(0),
        })
    }
}

/// Control flow for drain_until handler
enum ControlFlow {
    Continue,
    Break,
}

/// Output from a command execution
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CommandOutput {
    pub stdout: String,
    pub exit_code: i32,
}

/// Async executor that wraps a persistent Nushell shell.
/// Implements `CommandExecutor` so it can be swapped in for `NushellExecutor`.
/// Uses try_lock() to reject concurrent execute() calls with a clear error.
/// Uses clone_killer() for forcible reset while a command is running.
#[derive(Clone)]
pub struct PersistentNuExecutor {
    shell: Arc<Mutex<PersistentShell>>,
    killer: Arc<Mutex<Box<dyn ChildKiller + Send + Sync>>>,
}

impl PersistentNuExecutor {
    pub fn new() -> Result<Self, String> {
        let shell = PersistentShell::new()?;
        let killer = shell.clone_killer();
        Ok(Self {
            shell: Arc::new(Mutex::new(shell)),
            killer: Arc::new(Mutex::new(killer)),
        })
    }
}

impl CommandExecutor for PersistentNuExecutor {
    async fn execute(
        &self,
        command: &str,
        _working_dir: &Path,
        timeout_secs: Option<u64>,
    ) -> Result<(String, String), String> {
        let timeout = Duration::from_secs(timeout_secs.unwrap_or_else(super::get_default_timeout));
        let command = command.to_string();
        let shell = Arc::clone(&self.shell);

        // The shell does blocking I/O (PTY reads via recv_timeout).
        // Must run on a blocking thread to avoid starving the tokio runtime,
        // which needs to stay responsive for MCP protocol heartbeats.
        let result = tokio::task::spawn_blocking(move || {
            // Use try_lock to reject concurrent calls
            let mut guard = shell.try_lock().map_err(|e| match e {
                TryLockError::WouldBlock => {
                    "Shell is busy executing another command. Wait for the current command to complete before sending the next one. Use the 'run' tool for independent concurrent commands.".to_string()
                }
                TryLockError::Poisoned(_) => {
                    "Shell mutex poisoned — a previous command panicked. Send reset=true to recover.".to_string()
                }
            })?;
            guard.execute(&command, timeout)
        })
        .await
        .map_err(|e| format!("Shell task failed: {}", e))??;

        // PTY merges stdout/stderr into one stream; stderr is empty
        Ok((result.stdout, String::new()))
    }

    /// Tear down the current shell and create a fresh one.
    /// This gives a clean environment (no env vars, aliases, etc.).
    /// 
    /// If a command is currently running, this:
    /// 1. Kills the child process (via clone_killer)
    /// 2. Waits for the shell mutex to be released (execute() returns after PTY EOF)
    /// 3. Creates a new shell and replaces both shell and killer
    async fn reset(&self) -> Result<(), String> {
        // Step 1: Kill the child process via the killer handle.
        // This does NOT require the shell mutex — killer has its own mutex.
        // If a command is currently running (shell mutex locked by execute()),
        // killing the child causes the PTY read to return EOF/error,
        // which makes shell.execute() return an error, releasing the shell mutex.
        {
            let mut killer = self.killer.lock()
                .map_err(|_| "Killer mutex poisoned".to_string())?;
            let _ = killer.kill(); // Best effort — process may already be dead
        }
        
        // Step 2: Lock the shell mutex. If execute() was in progress,
        // it should have returned by now (child was killed, PTY returned EOF).
        // Use lock() (blocking wait), not try_lock() — reset MUST succeed.
        let shell_arc = Arc::clone(&self.shell);
        let killer_arc = Arc::clone(&self.killer);
        tokio::task::spawn_blocking(move || {
            let mut shell_guard = shell_arc.lock()
                .map_err(|_| "Shell mutex poisoned after kill".to_string())?;
            
            // Step 3: Create new shell
            let new_shell = PersistentShell::new()?;
            let new_killer = new_shell.clone_killer();
            
            // Step 4: Replace shell and killer
            *shell_guard = new_shell;
            drop(shell_guard); // Release shell mutex before locking killer
            
            let mut killer_guard = killer_arc.lock()
                .map_err(|_| "Killer mutex poisoned".to_string())?;
            *killer_guard = new_killer;
            
            Ok::<(), String>(())
        })
        .await
        .map_err(|e| format!("Reset task failed: {}", e))?
    }
}
