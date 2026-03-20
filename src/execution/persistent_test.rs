use crate::execution::persistent::PersistentShell;
use std::time::Duration;

const DEFAULT_TIMEOUT: Duration = Duration::from_secs(30);

#[test]
fn test_persistent_shell_creates() {
    let result = PersistentShell::new();
    assert!(result.is_ok(), "Failed: {:?}", result.err());
}

#[test]
fn test_detects_osc_133_at_startup() {
    let shell = PersistentShell::new();
    assert!(shell.is_ok());
}

#[test]
fn test_execute_writes_file() {
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    let test_file = std::env::temp_dir().join("nu_mcp_test_output.txt");
    let _ = std::fs::remove_file(&test_file);

    let cmd = format!("'hello' | save -f {}", test_file.display());
    let result = shell.execute(&cmd, DEFAULT_TIMEOUT);
    assert!(result.is_ok(), "Execute failed: {:?}", result.err());

    let content = std::fs::read_to_string(&test_file);
    assert!(content.is_ok(), "File not created");
    assert_eq!(content.unwrap().trim(), "hello");

    let _ = std::fs::remove_file(&test_file);
}

#[test]
fn test_execute_print_output() {
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    let result = shell.execute("print 'hello'", DEFAULT_TIMEOUT);
    assert!(result.is_ok(), "Execute failed: {:?}", result.err());
    let output = result.unwrap();
    assert!(
        output.stdout.contains("hello"),
        "Expected 'hello' in output, got: {:?}",
        output.stdout
    );
    assert_eq!(output.exit_code, 0);
}

#[test]
fn test_execute_expression_output() {
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    let result = shell.execute("1 + 1", DEFAULT_TIMEOUT);
    assert!(result.is_ok(), "Execute failed: {:?}", result.err());
    let output = result.unwrap();
    assert!(
        output.stdout.contains("2"),
        "Expected '2' in output, got: {:?}",
        output.stdout
    );
}

#[test]
fn test_state_persistence_via_file() {
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    let test_file = std::env::temp_dir().join("nu_mcp_test_state.txt");
    let _ = std::fs::remove_file(&test_file);

    let r1 = shell.execute("$env.TEST_VAL = 42", DEFAULT_TIMEOUT);
    assert!(r1.is_ok(), "First cmd failed: {:?}", r1.err());

    let cmd = format!("$env.TEST_VAL | save -f {}", test_file.display());
    let r2 = shell.execute(&cmd, DEFAULT_TIMEOUT);
    assert!(r2.is_ok(), "Second cmd failed: {:?}", r2.err());

    let content = std::fs::read_to_string(&test_file);
    assert!(content.is_ok(), "State file not created");
    assert_eq!(content.unwrap().trim(), "42");

    let _ = std::fs::remove_file(&test_file);
}

#[test]
fn test_execute_with_exit_code() {
    let mut shell = PersistentShell::new().expect("Failed to create shell");
    let result = shell.execute("error make {msg: 'test error'}", DEFAULT_TIMEOUT);

    assert!(result.is_ok(), "Execute failed: {:?}", result.err());
    let output = result.unwrap();
    assert_ne!(output.exit_code, 0, "Expected non-zero exit code for error");
}

// --- Edge case tests ---

#[test]
fn test_multiline_output() {
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    let result = shell.execute("[1 2 3 4 5] | each { |n| print $n }", DEFAULT_TIMEOUT);
    assert!(result.is_ok(), "Execute failed: {:?}", result.err());
    let output = result.unwrap();
    for n in 1..=5 {
        assert!(
            output.stdout.contains(&n.to_string()),
            "Expected '{}' in output, got: {:?}",
            n,
            output.stdout
        );
    }
}

#[test]
fn test_no_output_command() {
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    let result = shell.execute("let x = 1", DEFAULT_TIMEOUT);
    assert!(result.is_ok(), "Execute failed: {:?}", result.err());
    let output = result.unwrap();
    assert_eq!(
        output.stdout, "",
        "Expected empty output, got: {:?}",
        output.stdout
    );
    assert_eq!(output.exit_code, 0);
}

#[test]
fn test_large_output() {
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    let result = shell.execute("1..500 | each { |n| $'line ($n): some padding text to make this longer' } | str join (char newline) | print", DEFAULT_TIMEOUT);
    assert!(result.is_ok(), "Execute failed: {:?}", result.err());
    let output = result.unwrap();
    assert!(
        output.stdout.len() > 8000,
        "Expected >8KB output, got {} bytes",
        output.stdout.len()
    );
    assert!(output.stdout.contains("line 1:"), "Missing first line");
    assert!(output.stdout.contains("line 500:"), "Missing last line");
}

#[test]
fn test_many_sequential_commands() {
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    for i in 1..=10 {
        let result = shell.execute(&format!("print '{}'", i), DEFAULT_TIMEOUT);
        assert!(result.is_ok(), "Command {} failed: {:?}", i, result.err());
        let output = result.unwrap();
        assert!(
            output.stdout.contains(&i.to_string()),
            "Command {}: expected '{}' in output, got: {:?}",
            i,
            i,
            output.stdout
        );
        assert_eq!(output.exit_code, 0);
    }
}

#[test]
fn test_special_characters() {
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    let result = shell.execute(
        r#"print "hello 'world' \"quotes\" $foo {braces} [brackets]""#,
        DEFAULT_TIMEOUT,
    );
    assert!(result.is_ok(), "Execute failed: {:?}", result.err());
    let output = result.unwrap();
    assert!(output.stdout.contains("hello"), "Missing hello");
    assert!(output.stdout.contains("world"), "Missing world");
}

#[test]
fn test_timeout() {
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    let result = shell.execute("sleep 10sec", Duration::from_secs(1));

    assert!(result.is_err(), "Expected timeout error");
    let err = result.unwrap_err();
    assert!(
        err.contains("Timeout"),
        "Expected timeout message, got: {:?}",
        err
    );
}

#[test]
fn test_str_join_pipeline() {
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    let result = shell.execute(r#"["a" "b" "c"] | str join ", ""#, DEFAULT_TIMEOUT);
    assert!(result.is_ok(), "Execute failed: {:?}", result.err());
    let output = result.unwrap();
    assert_eq!(output.stdout, "a, b, c");
}

#[test]
fn test_each_with_str_join() {
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    let result = shell.execute(
        "[1 2 3 4 5] | each { |n| $n * $n } | str join \", \"",
        DEFAULT_TIMEOUT,
    );
    assert!(result.is_ok(), "Execute failed: {:?}", result.err());
    let output = result.unwrap();
    assert_eq!(output.stdout, "1, 4, 9, 16, 25");
}
