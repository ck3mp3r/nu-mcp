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
                    self.osc_parser.push(&temp_buf[..n], |_event| {
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
    /// Event-driven architecture following Atuin pattern:
    /// - Parser tracks Zone state internally (Unknown/Prompt/Input/Output)
    /// - Collect ALL bytes while parser.zone() == Zone::Output
    /// - Return when CommandFinished event received
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
        let mut finished = false;
        let mut read_one_more = false; // Read one more chunk after OSC 133;D

        // Event loop: read PTY until command finishes
        loop {
            if start.elapsed() > timeout {
                return Err(format!(
                    "Timeout after {} seconds (zone: {:?}, collected: {} bytes)",
                    timeout_secs,
                    self.osc_parser.zone(),
                    output_buffer.len()
                ));
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

                    // Collect BEFORE parsing (so we get this chunk even if it contains OSC 133;D)
                    output_buffer.extend_from_slice(data);

                    // Parse OSC events
                    self.osc_parser.push(data, |event| {
                        if let osc133::Event::CommandFinished { exit_code } = event {
                            final_exit_code = exit_code;
                            finished = true;
                        }
                    });

                    // If we just saw OSC 133;D, read one more chunk to get trailing output
                    if finished && !read_one_more {
                        read_one_more = true;
                        finished = false; // Keep going for one more iteration
                        continue;
                    }

                    // Command finished AND we've read the extra chunk - process and return
                    if read_one_more {
                        eprintln!(
                            "RAW BUFFER ({} bytes): {:?}",
                            output_buffer.len(),
                            output_buffer
                        );

                        // Strip ANSI escape codes (including OSC sequences)
                        let clean = strip_ansi_escapes::strip(&output_buffer);
                        eprintln!(
                            "AFTER STRIP ({} bytes): {:?}",
                            clean.len(),
                            String::from_utf8_lossy(&clean)
                        );

                        let mut stdout = String::from_utf8_lossy(&clean).to_string();

                        // Remove the command echo (first line in PTY output)
                        // The command we wrote is echoed back, followed by actual output
                        let lines: Vec<&str> = stdout.lines().collect();
                        eprintln!("LINES: {:?}", lines);

                        if lines.len() > 1 {
                            // Skip first line (command echo), join the rest
                            stdout = lines[1..].join("\n");
                        } else if lines.len() == 1 {
                            // Only one line - it's the command echo with no output
                            stdout = String::new();
                        }

                        // Trim whitespace
                        let stdout = stdout.trim().to_string();

                        return Ok(CommandOutput {
                            stdout,
                            exit_code: final_exit_code.unwrap_or(0),
                        });
                    }
                }
                Err(_) => {
                    // Non-blocking read, sleep briefly
                    std::thread::sleep(Duration::from_millis(10));
                }
            }
        }
    }
}

/// Output from a command execution
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CommandOutput {
    pub stdout: String,
    pub exit_code: i32,
}
