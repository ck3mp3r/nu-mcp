use super::*;

#[test]
fn test_extract_output_single_chunk_coalesced() {
    // REGRESSION: C marker, output, and D marker all coalesced into one
    // PTY read chunk (kernel buffering on slow/loaded systems). Output
    // must still be recovered.
    let raw = b"\x1b]133;C\x07a, b, c\x1b]133;D;0\x07";
    assert_eq!(extract_output(raw), b"a, b, c");
}

#[test]
fn test_extract_output_chunked() {
    // Common path: output bytes arrive between C and D in later chunks
    let raw = b"\x1b]133;C\x07a, b, c\r\n\x1b]133;D;0\x07";
    assert_eq!(extract_output(raw), b"a, b, c\r\n");
}

#[test]
fn test_extract_output_st_terminators() {
    // Markers can use ESC \ (ST) instead of BEL as terminator
    let raw = b"\x1b]133;C\x1b\\output\x1b]133;D\x1b\\";
    assert_eq!(extract_output(raw), b"output");
}

#[test]
fn test_extract_output_no_command_finished() {
    // D marker never arrived (drain interrupted) — return what we have
    let raw = b"\x1b]133;C\x07partial output";
    assert_eq!(extract_output(raw), b"partial output");
}

#[test]
fn test_extract_output_no_command_executed() {
    // No C marker at all (e.g. output-only transcript) — empty result
    let raw = b"some prompt text with no markers";
    assert_eq!(extract_output(raw), b"");
}

#[test]
fn test_extract_output_empty_transcript() {
    assert_eq!(extract_output(b""), b"");
}

#[test]
fn test_extract_output_prompt_and_echo_excluded() {
    // Everything before C (prompt, echoed command) must be excluded;
    // everything from D on (next prompt) must be excluded
    let raw = b"\x1b]133;A\x07prompt> \x1b]133;B\x07echoed\x1b]133;C\x07real output\x1b]133;D;0\x07next prompt";
    assert_eq!(extract_output(raw), b"real output");
}
