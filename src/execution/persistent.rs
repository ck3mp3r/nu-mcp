//! Persistent Nushell shell using PTY and OSC 133 for completion detection
//!
//! Note: Uses `Box<dyn MasterPty>` and `Box<dyn Child>` from portable-pty.
//! This is the library's API design for cross-platform support.
//! The overhead is negligible for a long-lived, I/O-bound object.
//! Can be optimized later with platform-specific code if needed.

use super::osc133;
use portable_pty::{native_pty_system, Child, CommandBuilder, MasterPty, PtySize};
use std::env;
use std::io::{Read, Write};
use std::time::{Duration, Instant};

const BUFFER_SIZE: usize = 8192;
const STARTUP_TIMEOUT_SECS: u64 = 5;
const DEFAULT_COMMAND_TIMEOUT_SECS: u64 = 60;

/// DSR (Device Status Report) sequence: ESC [ 6 n
/// Reedline/crossterm sends this to query cursor position.
const DSR_SEQUENCE: &[u8] = b"\x1b[6n";

pub struct PersistentShell {
    master: Box<dyn MasterPty + Send>,
    writer: Box<dyn Write + Send>,
    osc_parser: osc133::Parser,
    _buffer: [u8; BUFFER_SIZE],
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

        // Set environment variables to ensure Nushell sees this as a terminal
        cmd.env("TERM", "xterm-256color");
        cmd.env("COLORTERM", "truecolor");

        // Disable bracketed paste which might interfere
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

        let mut shell = Self {
            master,
            writer,
            osc_parser: osc133::Parser::new(),
            _buffer: [0u8; BUFFER_SIZE],
            _child: child,
        };

        shell.wait_for_prompt(Duration::from_secs(STARTUP_TIMEOUT_SECS))?;

        Ok(shell)
    }

    /// Scan PTY output for DSR (Device Status Report) queries and respond with CPR.
    ///
    /// Reedline (via crossterm) sends `\x1b[6n` to query the cursor position and blocks
    /// up to 2 seconds waiting for a CPR (Cursor Position Report) response in the format
    /// `\x1b[{row};{col}R`. Without this response, Reedline's prompt repainting uses an
    /// incorrect position, causing screen clears that erase command output.
    ///
    /// This method scans the given data for DSR sequences and writes back a CPR response
    /// `\x1b[1;1R` (row 1, col 1) to the child's stdin via the PTY writer.
    fn respond_to_dsr(&mut self, data: &[u8]) {
        // Scan for all occurrences of \x1b[6n in the data
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
            // Write CPR response for each DSR query: ESC [ row ; col R (1-based)
            for _ in 0..count {
                let _ = self.writer.write_all(b"\x1b[1;1R");
            }
            let _ = self.writer.flush();
        }
    }

    fn wait_for_prompt(&mut self, timeout: Duration) -> Result<(), String> {
        let start = Instant::now();
        let mut got_marker = false;

        loop {
            if start.elapsed() > timeout {
                return Err(format!(
                    "Timeout waiting for Nushell. OSC 133 may be disabled. Final zone: {:?}",
                    self.osc_parser.zone()
                ));
            }

            let mut reader = self
                .master
                .try_clone_reader()
                .map_err(|e| format!("Failed to clone reader: {}", e))?;

            let mut temp_buf = [0u8; 1024];
            match reader.read(&mut temp_buf) {
                Ok(0) => return Err("PTY EOF during startup".to_string()),
                Ok(n) => {
                    let data = &temp_buf[..n];

                    // Respond to DSR queries from Reedline/crossterm
                    self.respond_to_dsr(data);

                    self.osc_parser.push(data, |_event| {
                        // Accept ANY OSC marker as sign that shell integration is working
                        got_marker = true;
                    });

                    if got_marker {
                        return Ok(());
                    }
                }
                Err(_) => {
                    std::thread::sleep(Duration::from_millis(100));
                }
            }
        }
    }

    /// Execute a command and collect output
    ///
    /// OSC 133 sequence for each command in Nushell's REPL:
    ///   [leftover D from prev prompt] → A (prompt) → B (input) → C (executing) → D (finished)
    ///
    /// We must:
    /// 1. Respond to DSR queries during prompt phase so Reedline can render
    /// 2. Wait for C (CommandExecuted) - only then is our command running
    /// 3. Collect output bytes only while zone == Output (between C and D)
    /// 4. Stop at D (CommandFinished) after C - that's the real completion
    pub fn execute(&mut self, command: &str) -> Result<CommandOutput, String> {
        let timeout_secs = env::var("MCP_NU_MCP_TIMEOUT")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(DEFAULT_COMMAND_TIMEOUT_SECS);
        let timeout = Duration::from_secs(timeout_secs);

        // Write command to PTY
        writeln!(self.writer, "{}", command).map_err(|e| format!("Write failed: {}", e))?;
        self.writer
            .flush()
            .map_err(|e| format!("Flush failed: {}", e))?;

        let start = Instant::now();
        let mut output_buffer = Vec::new();
        let mut final_exit_code: Option<i32> = None;
        let mut saw_command_executed = false;

        // Event loop: read PTY until command finishes
        loop {
            if start.elapsed() > timeout {
                return Err(format!("Timeout after {} seconds", timeout_secs));
            }

            let mut reader = self
                .master
                .try_clone_reader()
                .map_err(|e| format!("Clone reader failed: {}", e))?;

            let mut chunk = [0u8; BUFFER_SIZE];
            match reader.read(&mut chunk) {
                Ok(0) => return Err("PTY EOF".to_string()),
                Ok(n) => {
                    let data = &chunk[..n];

                    // Before CommandExecuted (C): respond to DSR so Reedline can render prompt
                    if !saw_command_executed {
                        self.respond_to_dsr(data);
                    }

                    // Only collect output bytes after CommandExecuted (zone == Output)
                    if saw_command_executed {
                        output_buffer.extend_from_slice(data);
                    }

                    // Parse OSC events
                    let mut done = false;
                    self.osc_parser.push(data, |event| match event {
                        osc133::Event::CommandExecuted => {
                            saw_command_executed = true;
                        }
                        osc133::Event::CommandFinished { exit_code } => {
                            // Only treat D as completion if we already saw C
                            if saw_command_executed {
                                final_exit_code = exit_code;
                                done = true;
                            }
                        }
                        _ => {}
                    });

                    if done {
                        break;
                    }
                }
                Err(_) => {
                    std::thread::sleep(Duration::from_millis(10));
                }
            }
        }

        // Strip ANSI escape codes
        let clean = strip_ansi_escapes::strip(&output_buffer);
        let stdout = String::from_utf8_lossy(&clean).to_string();

        // Trim whitespace
        let stdout = stdout.trim().to_string();

        Ok(CommandOutput {
            stdout,
            exit_code: final_exit_code.unwrap_or(0),
        })
    }
}

/// Output from a command execution
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CommandOutput {
    pub stdout: String,
    pub exit_code: i32,
}
