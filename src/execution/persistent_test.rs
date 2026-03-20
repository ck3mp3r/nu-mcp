use crate::execution::CommandExecutor;
use crate::execution::persistent::PersistentNuExecutor;
use crate::execution::persistent::PersistentShell;
use serial_test::serial;
use std::path::PathBuf;
use std::time::Duration;

const DEFAULT_TIMEOUT: Duration = Duration::from_secs(30);

/// Skip test if a persistent shell cannot be created (e.g., no PTY in CI/Nix sandbox).
macro_rules! skip_if_no_pty {
    () => {
        match PersistentShell::new() {
            Ok(_) => {}
            Err(e) => {
                eprintln!("Skipping: PTY/Nushell not available: {}", e);
                return;
            }
        }
    };
}

#[test]
#[serial]
fn test_shell_creation_and_basic_output() {
    skip_if_no_pty!();
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    // Expression output
    let r1 = shell.execute("1 + 1", DEFAULT_TIMEOUT);
    assert!(r1.is_ok(), "Expression failed: {:?}", r1.err());
    let out1 = r1.unwrap();
    assert!(out1.stdout.contains("2"), "Expected '2', got: {:?}", out1.stdout);

    // Print output
    let r2 = shell.execute("print 'hello'", DEFAULT_TIMEOUT);
    assert!(r2.is_ok(), "Print failed: {:?}", r2.err());
    let out2 = r2.unwrap();
    assert!(out2.stdout.contains("hello"), "Expected 'hello', got: {:?}", out2.stdout);
    assert_eq!(out2.exit_code, 0);

    // No-output command
    let r3 = shell.execute("let x = 1", DEFAULT_TIMEOUT);
    assert!(r3.is_ok(), "Let failed: {:?}", r3.err());
    assert_eq!(r3.unwrap().stdout, "");

    // Error exit code
    let r4 = shell.execute("error make {msg: 'test error'}", DEFAULT_TIMEOUT);
    assert!(r4.is_ok(), "Error cmd failed: {:?}", r4.err());
    assert_ne!(r4.unwrap().exit_code, 0);
}

#[test]
#[serial]
fn test_state_persistence_and_file_io() {
    skip_if_no_pty!();
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    let test_file = std::env::temp_dir().join("nu_mcp_test_state.txt");
    let _ = std::fs::remove_file(&test_file);

    // Set env var, then read it back via file to prove state persists
    let r1 = shell.execute("$env.TEST_VAL = 42", DEFAULT_TIMEOUT);
    assert!(r1.is_ok(), "Set env failed: {:?}", r1.err());

    let cmd = format!("$env.TEST_VAL | save -f {}", test_file.display());
    let r2 = shell.execute(&cmd, DEFAULT_TIMEOUT);
    assert!(r2.is_ok(), "Save failed: {:?}", r2.err());

    let content = std::fs::read_to_string(&test_file).expect("File not created");
    assert_eq!(content.trim(), "42");

    let _ = std::fs::remove_file(&test_file);
}

#[test]
#[serial]
fn test_sequential_commands_and_pipelines() {
    skip_if_no_pty!();
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    // Simple sequential commands
    for i in 1..=5 {
        let result = shell.execute(&format!("print '{}'", i), DEFAULT_TIMEOUT);
        assert!(result.is_ok(), "Command {} failed: {:?}", i, result.err());
        let output = result.unwrap();
        assert!(output.stdout.contains(&i.to_string()),
            "Command {}: expected '{}', got: {:?}", i, i, output.stdout);
        assert_eq!(output.exit_code, 0);
    }

    // str join pipeline (previously a regression)
    let r1 = shell.execute(r#"["a" "b" "c"] | str join ", ""#, DEFAULT_TIMEOUT);
    assert!(r1.is_ok(), "str join failed: {:?}", r1.err());
    assert_eq!(r1.unwrap().stdout, "a, b, c");

    // each + str join pipeline
    let r2 = shell.execute(
        "[1 2 3 4 5] | each { |n| $n * $n } | str join \", \"",
        DEFAULT_TIMEOUT,
    );
    assert!(r2.is_ok(), "each+str join failed: {:?}", r2.err());
    assert_eq!(r2.unwrap().stdout, "1, 4, 9, 16, 25");
}

#[test]
#[serial]
fn test_multiline_and_large_output() {
    skip_if_no_pty!();
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    // Multiline
    let r1 = shell.execute("[1 2 3 4 5] | each { |n| print $n }", DEFAULT_TIMEOUT);
    assert!(r1.is_ok(), "Multiline failed: {:?}", r1.err());
    let out1 = r1.unwrap();
    for n in 1..=5 {
        assert!(out1.stdout.contains(&n.to_string()),
            "Expected '{}' in output, got: {:?}", n, out1.stdout);
    }

    // Large output (>8KB)
    let r2 = shell.execute(
        "1..500 | each { |n| $'line ($n): some padding text to make this longer' } | str join (char newline) | print",
        DEFAULT_TIMEOUT,
    );
    assert!(r2.is_ok(), "Large output failed: {:?}", r2.err());
    let out2 = r2.unwrap();
    assert!(out2.stdout.len() > 8000, "Expected >8KB, got {} bytes", out2.stdout.len());
    assert!(out2.stdout.contains("line 1:"), "Missing first line");
    assert!(out2.stdout.contains("line 500:"), "Missing last line");
}

#[test]
#[serial]
fn test_special_characters() {
    skip_if_no_pty!();
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
#[serial]
fn test_timeout() {
    skip_if_no_pty!();
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    let result = shell.execute("sleep 10sec", Duration::from_secs(1));

    assert!(result.is_err(), "Expected timeout error");
    let err = result.unwrap_err();
    assert!(err.contains("Timeout"), "Expected timeout message, got: {:?}", err);
}

// --- Reset tests (via PersistentNuExecutor) ---

#[tokio::test]
#[serial]
async fn test_reset() {
    skip_if_no_pty!();
    let executor = PersistentNuExecutor::new().expect("Failed to create executor");
    let work_dir = PathBuf::from(".");

    // Set state
    let r1 = executor
        .execute("$env.RESET_TEST = 'before'", &work_dir, Some(30))
        .await;
    assert!(r1.is_ok(), "Set state failed: {:?}", r1.err());

    // Verify state exists
    let r2 = executor
        .execute("$env.RESET_TEST", &work_dir, Some(30))
        .await;
    assert!(r2.is_ok());
    assert!(r2.unwrap().0.contains("before"), "State should exist before reset");

    // Reset
    executor.reset().expect("Reset failed");

    // State should be gone
    let r3 = executor
        .execute("$env.RESET_TEST? | default 'gone'", &work_dir, Some(30))
        .await;
    assert!(r3.is_ok(), "Post-reset command failed: {:?}", r3.err());
    assert!(r3.unwrap().0.contains("gone"), "State should be cleared after reset");

    // Shell should still work after reset
    let r4 = executor
        .execute("print 'alive'", &work_dir, Some(30))
        .await;
    assert!(r4.is_ok(), "Post-reset execute failed: {:?}", r4.err());
    assert!(r4.unwrap().0.contains("alive"));
}
