use crate::execution::CommandExecutor;
use crate::execution::persistent::PersistentNuExecutor;
use crate::execution::persistent::PersistentShell;
use serial_test::serial;
use std::path::PathBuf;
use std::time::Duration;

const DEFAULT_TIMEOUT: Duration = Duration::from_secs(30);

/// Skip test when running in CI — persistent shell tests need a real PTY with Nushell.
macro_rules! skip_in_ci {
    () => {
        if std::env::var("CI").is_ok() {
            eprintln!("Skipping PTY test in CI environment");
            return;
        }
    };
}

#[test]
#[serial]
fn test_persistent_shell_creates() {
    skip_in_ci!();
    let result = PersistentShell::new();
    assert!(result.is_ok(), "Failed: {:?}", result.err());
}

#[test]
#[serial]
fn test_detects_osc_133_at_startup() {
    skip_in_ci!();
    let shell = PersistentShell::new();
    assert!(shell.is_ok());
}

#[test]
#[serial]
fn test_execute_writes_file() {
    skip_in_ci!();
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
#[serial]
fn test_execute_print_output() {
    skip_in_ci!();
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
#[serial]
fn test_execute_expression_output() {
    skip_in_ci!();
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
#[serial]
fn test_state_persistence_via_file() {
    skip_in_ci!();
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
#[serial]
fn test_execute_with_exit_code() {
    skip_in_ci!();
    let mut shell = PersistentShell::new().expect("Failed to create shell");
    let result = shell.execute("error make {msg: 'test error'}", DEFAULT_TIMEOUT);

    assert!(result.is_ok(), "Execute failed: {:?}", result.err());
    let output = result.unwrap();
    assert_ne!(output.exit_code, 0, "Expected non-zero exit code for error");
}

// --- Edge case tests ---

#[test]
#[serial]
fn test_multiline_output() {
    skip_in_ci!();
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
#[serial]
fn test_no_output_command() {
    skip_in_ci!();
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
#[serial]
fn test_large_output() {
    skip_in_ci!();
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
#[serial]
fn test_many_sequential_commands() {
    skip_in_ci!();
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
#[serial]
fn test_special_characters() {
    skip_in_ci!();
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
    skip_in_ci!();
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
#[serial]
fn test_str_join_pipeline() {
    skip_in_ci!();
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    let result = shell.execute(r#"["a" "b" "c"] | str join ", ""#, DEFAULT_TIMEOUT);
    assert!(result.is_ok(), "Execute failed: {:?}", result.err());
    let output = result.unwrap();
    assert_eq!(output.stdout, "a, b, c");
}

#[test]
#[serial]
fn test_each_with_str_join() {
    skip_in_ci!();
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    let result = shell.execute(
        "[1 2 3 4 5] | each { |n| $n * $n } | str join \", \"",
        DEFAULT_TIMEOUT,
    );
    assert!(result.is_ok(), "Execute failed: {:?}", result.err());
    let output = result.unwrap();
    assert_eq!(output.stdout, "1, 4, 9, 16, 25");
}

#[test]
#[serial]
fn test_str_join_after_prior_command() {
    skip_in_ci!();
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    // First a simple command
    let r1 = shell.execute("print 'hello'", DEFAULT_TIMEOUT);
    assert!(r1.is_ok(), "First cmd failed: {:?}", r1.err());
    assert_eq!(r1.unwrap().stdout, "hello");

    // Then the problematic str join with space
    let r2 = shell.execute(r#"["a" "b" "c"] | str join ", ""#, DEFAULT_TIMEOUT);
    assert!(r2.is_ok(), "str join failed: {:?}", r2.err());
    assert_eq!(r2.unwrap().stdout, "a, b, c");
}

// --- Reset tests (via PersistentNuExecutor) ---

#[tokio::test]
#[serial]
async fn test_reset_clears_state() {
    skip_in_ci!();
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
    assert!(
        r2.unwrap().0.contains("before"),
        "State should exist before reset"
    );

    // Reset
    executor.reset().expect("Reset failed");

    // State should be gone
    let r3 = executor
        .execute("$env.RESET_TEST? | default 'gone'", &work_dir, Some(30))
        .await;
    assert!(r3.is_ok(), "Post-reset command failed: {:?}", r3.err());
    assert!(
        r3.unwrap().0.contains("gone"),
        "State should be cleared after reset"
    );
}

#[tokio::test]
#[serial]
async fn test_reset_shell_still_works() {
    skip_in_ci!();
    let executor = PersistentNuExecutor::new().expect("Failed to create executor");
    let work_dir = PathBuf::from(".");

    // Use the shell
    let r1 = executor
        .execute("print 'before reset'", &work_dir, Some(30))
        .await;
    assert!(r1.is_ok());
    assert!(r1.unwrap().0.contains("before reset"));

    // Reset
    executor.reset().expect("Reset failed");

    // Shell should still work
    let r2 = executor
        .execute("print 'after reset'", &work_dir, Some(30))
        .await;
    assert!(r2.is_ok(), "Post-reset execute failed: {:?}", r2.err());
    assert!(r2.unwrap().0.contains("after reset"));
}
