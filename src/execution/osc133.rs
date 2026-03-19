//! OSC 133 (FinalTerm semantic prompt) parser for detecting command completion
//!
//! OSC 133 marks four regions of shell interaction:
//! - A: Prompt start
//! - B: Command input start (prompt ended)
//! - C: Command execution start (command submitted)
//! - D: Command finished (with optional exit code)
//!
//! Wire format: ESC ] 133 ; <cmd> [; <params>] ST
//! where ST is either BEL (0x07) or ESC \ (0x1B 0x5C)

const ESC: u8 = 0x1B;
const BEL: u8 = 0x07;
const BACKSLASH: u8 = b'\\';
const RIGHT_BRACKET: u8 = b']';
const PARAM_BUF_CAP: usize = 32;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum State {
    Ground,
    Esc,
    OscParam,
    OscEsc,
}

/// Events emitted when OSC 133 markers are detected
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Event {
    /// OSC 133;A - Shell about to display prompt
    PromptStart,
    /// OSC 133;B - Prompt ended, user can type command
    CommandStart,
    /// OSC 133;C - Command submitted for execution
    CommandExecuted,
    /// OSC 133;D[;exit_code] - Command finished
    CommandFinished { exit_code: Option<i32> },
}

/// Streaming parser for OSC 133 sequences
pub struct Parser {
    state: State,
    param_buf: [u8; PARAM_BUF_CAP],
    param_len: usize,
}

impl Parser {
    /// Create a new parser
    pub fn new() -> Self {
        Self {
            state: State::Ground,
            param_buf: [0u8; PARAM_BUF_CAP],
            param_len: 0,
        }
    }

    /// Process a chunk of bytes, calling callback for each OSC 133 event detected
    pub fn push(&mut self, data: &[u8], mut on_event: impl FnMut(Event)) {
        for &byte in data {
            match self.state {
                State::Ground => {
                    if byte == ESC {
                        self.state = State::Esc;
                    }
                }
                State::Esc => {
                    if byte == RIGHT_BRACKET {
                        self.state = State::OscParam;
                        self.param_len = 0;
                    } else {
                        self.state = State::Ground;
                    }
                }
                State::OscParam => {
                    if byte == BEL {
                        self.dispatch(&mut on_event);
                        self.state = State::Ground;
                    } else if byte == ESC {
                        self.state = State::OscEsc;
                    } else if self.param_len < PARAM_BUF_CAP {
                        self.param_buf[self.param_len] = byte;
                        self.param_len += 1;
                    }
                }
                State::OscEsc => {
                    if byte == BACKSLASH {
                        self.dispatch(&mut on_event);
                    }
                    self.state = State::Ground;
                }
            }
        }
    }

    fn dispatch(&mut self, on_event: &mut impl FnMut(Event)) {
        let params = &self.param_buf[..self.param_len];

        // Must start with "133;"
        if params.len() < 5 || &params[..4] != b"133;" {
            return;
        }

        let cmd = params[4];
        let event = match cmd {
            b'A' => Event::PromptStart,
            b'B' => Event::CommandStart,
            b'C' => Event::CommandExecuted,
            b'D' => {
                let exit_code = if params.len() > 6 && params[5] == b';' {
                    std::str::from_utf8(&params[6..])
                        .ok()
                        .and_then(|s| s.parse::<i32>().ok())
                } else {
                    None
                };
                Event::CommandFinished { exit_code }
            }
            _ => return,
        };

        on_event(event);
    }
}

impl Default for Parser {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_prompt_start_with_bel() {
        let mut parser = Parser::new();
        let mut events = Vec::new();

        parser.push(b"\x1b]133;A\x07", |e| events.push(e));

        assert_eq!(events, vec![Event::PromptStart]);
    }

    #[test]
    fn test_command_start_with_bel() {
        let mut parser = Parser::new();
        let mut events = Vec::new();

        parser.push(b"\x1b]133;B\x07", |e| events.push(e));

        assert_eq!(events, vec![Event::CommandStart]);
    }

    #[test]
    fn test_command_executed_with_bel() {
        let mut parser = Parser::new();
        let mut events = Vec::new();

        parser.push(b"\x1b]133;C\x07", |e| events.push(e));

        assert_eq!(events, vec![Event::CommandExecuted]);
    }

    #[test]
    fn test_command_finished_no_exit_code() {
        let mut parser = Parser::new();
        let mut events = Vec::new();

        parser.push(b"\x1b]133;D\x07", |e| events.push(e));

        assert_eq!(events, vec![Event::CommandFinished { exit_code: None }]);
    }

    #[test]
    fn test_command_finished_exit_code_zero() {
        let mut parser = Parser::new();
        let mut events = Vec::new();

        parser.push(b"\x1b]133;D;0\x07", |e| events.push(e));

        assert_eq!(events, vec![Event::CommandFinished { exit_code: Some(0) }]);
    }

    #[test]
    fn test_command_finished_exit_code_nonzero() {
        let mut parser = Parser::new();
        let mut events = Vec::new();

        parser.push(b"\x1b]133;D;127\x07", |e| events.push(e));

        assert_eq!(
            events,
            vec![Event::CommandFinished {
                exit_code: Some(127)
            }]
        );
    }

    #[test]
    fn test_st_terminator() {
        let mut parser = Parser::new();
        let mut events = Vec::new();

        // ESC ] 133 ; A ESC \ (ST terminator)
        parser.push(b"\x1b]133;A\x1b\\", |e| events.push(e));

        assert_eq!(events, vec![Event::PromptStart]);
    }

    #[test]
    fn test_split_sequence_across_chunks() {
        let mut parser = Parser::new();
        let mut events = Vec::new();

        // Split ESC ] 133 ; A BEL across multiple pushes
        parser.push(b"\x1b", |e| events.push(e));
        parser.push(b"]133", |e| events.push(e));
        parser.push(b";A\x07", |e| events.push(e));

        assert_eq!(events, vec![Event::PromptStart]);
    }

    #[test]
    fn test_ignore_non_osc133_sequences() {
        let mut parser = Parser::new();
        let mut events = Vec::new();

        // OSC 0 (set title) - should be ignored
        parser.push(b"\x1b]0;title\x07", |e| events.push(e));

        assert!(events.is_empty());
    }

    #[test]
    fn test_invalid_exit_code() {
        let mut parser = Parser::new();
        let mut events = Vec::new();

        // Invalid exit code should parse as None
        parser.push(b"\x1b]133;D;invalid\x07", |e| events.push(e));

        assert_eq!(events, vec![Event::CommandFinished { exit_code: None }]);
    }

    #[test]
    fn test_multiple_events_in_one_chunk() {
        let mut parser = Parser::new();
        let mut events = Vec::new();

        // Multiple OSC sequences in one push
        parser.push(b"\x1b]133;A\x07\x1b]133;B\x07\x1b]133;C\x07", |e| {
            events.push(e)
        });

        assert_eq!(
            events,
            vec![
                Event::PromptStart,
                Event::CommandStart,
                Event::CommandExecuted,
            ]
        );
    }

    #[test]
    fn test_mixed_content_with_osc() {
        let mut parser = Parser::new();
        let mut events = Vec::new();

        // Normal text mixed with OSC sequences
        parser.push(b"hello\x1b]133;A\x07world", |e| events.push(e));

        assert_eq!(events, vec![Event::PromptStart]);
    }
}
