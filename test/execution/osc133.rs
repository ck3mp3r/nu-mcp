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
