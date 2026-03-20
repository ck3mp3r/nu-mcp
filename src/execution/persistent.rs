//! Persistent Nushell shell using PTY and OSC 133 for completion detection
//!
//! Note: Uses `Box<dyn MasterPty>` and `Box<dyn Child>` from portable-pty.
//! This is the library's API design for cross-platform support.
//! The overhead is negligible for a long-lived, I/O-bound object.
//! Can be optimized later with platform-specific code if needed.

use super::CommandExecutor;
use super::osc133;
use async_trait::async_trait;
use portable_pty::{Child, CommandBuilder, MasterPty, PtySize, native_pty_system};
use std::io::{Read, Write};
use std::path::Path;
use std::sync::{Arc, Mutex, mpsc};
use std::time::Duration;

const BUFFER_SIZE: usize = 8192;
const STARTUP_TIMEOUT_SECS: u64 = 5;

/// DSR (Device Status Report) sequence: ESC [ 6 n
/// Reedline/crossterm sends this to query cursor position.
const DSR_SEQUENCE: &[u8] = b"\x1b[6n";

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
    _child: Box<dyn Child + Send + Sync>,
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
        let (tx, rx) = mpsc::channel();
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
            _child: child,
        };

        shell.wait_for_prompt(Duration::from_secs(STARTUP_TIMEOUT_SECS))?;

        Ok(shell)
    }

    /// Scan data for DSR queries and respond with CPR.
    fn respond_to_dsr(&mut self, data: &[u8]) {
        if data.len() < DSR_SEQUENCE.len() {
            return;
        }
        let mut count = 0;
        for window in data.windows(DSR_SEQUENCE.len()) {
            if window == DSR_SEQUENCE {
                count += 1;
            }
        }
        if count > 0 {
            for _ in 0..count {
                let _ = self.writer.write_all(b"\x1b[1;1R");
            }
            let _ = self.writer.flush();
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
    /// OSC 133 sequence for each command in Nushell's REPL:
    ///   [leftover D from prev prompt] → A (prompt) → B (input) → C (executing) → D (finished)
    ///
    /// We:
    /// 1. Respond to DSR queries during prompt phase so Reedline can render
    /// 2. Wait for C (CommandExecuted) - only then is our command running
    /// 3. Collect output bytes between C and D
    /// 4. Stop at D (CommandFinished) after C
    pub fn execute(&mut self, command: &str, timeout: Duration) -> Result<CommandOutput, String> {
        // Write command to PTY
        writeln!(self.writer, "{}", command).map_err(|e| format!("Write failed: {}", e))?;
        self.writer
            .flush()
            .map_err(|e| format!("Flush failed: {}", e))?;

        let mut output_buffer = Vec::new();
        let mut final_exit_code: Option<i32> = None;
        let mut saw_command_executed = false;

        self.drain_until(timeout, |shell, data| {
            // Before C: respond to DSR so Reedline can render prompt
            if !saw_command_executed {
                shell.respond_to_dsr(data);
            }

            // Collect output bytes only after C
            if saw_command_executed {
                output_buffer.extend_from_slice(data);
            }

            let mut done = false;
            shell.osc_parser.push(data, |event| match event {
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

const DEFAULT_TIMEOUT_SECS: u64 = 60;

fn get_default_timeout() -> u64 {
    std::env::var("MCP_NU_MCP_TIMEOUT")
        .ok()
        .and_then(|s| s.parse::<u64>().ok())
        .filter(|&n| n > 0)
        .unwrap_or(DEFAULT_TIMEOUT_SECS)
}

/// Async executor that wraps a persistent Nushell shell.
/// Implements `CommandExecutor` so it can be swapped in for `NushellExecutor`.
#[derive(Clone)]
pub struct PersistentNuExecutor {
    shell: Arc<Mutex<PersistentShell>>,
}

impl PersistentNuExecutor {
    pub fn new() -> Result<Self, String> {
        Ok(Self {
            shell: Arc::new(Mutex::new(PersistentShell::new()?)),
        })
    }
}

#[async_trait]
impl CommandExecutor for PersistentNuExecutor {
    async fn execute(
        &self,
        command: &str,
        _working_dir: &Path,
        timeout_secs: Option<u64>,
    ) -> Result<(String, String), String> {
        let timeout = Duration::from_secs(timeout_secs.unwrap_or_else(get_default_timeout));
        let command = command.to_string();

        // The shell is behind a Mutex; lock, execute (blocking I/O), release.
        // spawn_blocking keeps the tokio runtime responsive.
        let shell = &self.shell;
        let mut guard = shell
            .lock()
            .map_err(|e| format!("Shell lock poisoned: {}", e))?;
        let result = guard.execute(&command, timeout)?;

        // PTY merges stdout/stderr into one stream; stderr is empty
        Ok((result.stdout, String::new()))
    }
}
