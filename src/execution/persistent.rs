//! Persistent Nushell shell using PTY and OSC 133 for completion detection

use super::osc133;
use portable_pty::{native_pty_system, Child, CommandBuilder, MasterPty, PtySize};
use std::io::Read;
use std::time::{Duration, Instant};

const BUFFER_SIZE: usize = 8192;
const STARTUP_TIMEOUT_SECS: u64 = 5;

pub struct PersistentShell {
    master: Box<dyn MasterPty + Send>,
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

        let mut shell = Self {
            master,
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
                return Err("Timeout waiting for Nushell. OSC 133 may be disabled.".to_string());
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
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_persistent_shell_creates() {
        let result = PersistentShell::new();
        assert!(
            result.is_ok(),
            "Failed to create persistent shell: {:?}",
            result.err()
        );
    }

    #[test]
    fn test_detects_osc_133_at_startup() {
        let shell = PersistentShell::new();
        assert!(shell.is_ok(), "Should detect OSC 133 during startup");
    }
}
