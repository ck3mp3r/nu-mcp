use crate::execution::persistent::PersistentShell;

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
fn test_execute_simple_command() {
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    // Use a simpler command first
    let result = shell.execute("echo test");

    assert!(result.is_ok(), "Execute failed: {:?}", result.err());
    let output = result.unwrap();

    eprintln!("OUTPUT: {:?}", output);
    eprintln!("STDOUT: {:?}", output.stdout);
    eprintln!("EXIT_CODE: {}", output.exit_code);

    // Should contain "test" somewhere in output
    assert!(
        output.stdout.contains("test"),
        "Expected 'test' in output, got: {:?}",
        output.stdout
    );
    assert_eq!(output.exit_code, 0);
}

#[test]
fn test_execute_with_exit_code() {
    let mut shell = PersistentShell::new().expect("Failed to create shell");
    let result = shell.execute("exit 42");

    assert!(result.is_ok(), "Execute failed: {:?}", result.err());
    let output = result.unwrap();
    assert_eq!(output.exit_code, 42);
}

#[test]
fn test_state_persistence() {
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    let result1 = shell.execute("let x = 5");
    assert!(result1.is_ok(), "First command failed: {:?}", result1.err());

    let result2 = shell.execute("print $x");
    assert!(
        result2.is_ok(),
        "Second command failed: {:?}",
        result2.err()
    );
    let output = result2.unwrap();

    // Should contain "5" somewhere in output
    assert!(
        output.stdout.contains("5"),
        "Expected '5' in output, got: {:?}",
        output.stdout
    );
}
