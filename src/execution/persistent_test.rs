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
fn test_execute_writes_file() {
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    let test_file = std::env::temp_dir().join("nu_mcp_test_output.txt");
    let _ = std::fs::remove_file(&test_file);

    let cmd = format!("'hello' | save -f {}", test_file.display());
    let result = shell.execute(&cmd);
    assert!(result.is_ok(), "Execute failed: {:?}", result.err());

    let content = std::fs::read_to_string(&test_file);
    assert!(content.is_ok(), "File not created");
    assert_eq!(content.unwrap().trim(), "hello");

    let _ = std::fs::remove_file(&test_file);
}

#[test]
fn test_execute_print_output() {
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    let result = shell.execute("print 'hello'");
    assert!(result.is_ok(), "Execute failed: {:?}", result.err());
    let output = result.unwrap();
    eprintln!("STDOUT: {:?}", output.stdout);
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

    let result = shell.execute("1 + 1");
    assert!(result.is_ok(), "Execute failed: {:?}", result.err());
    let output = result.unwrap();
    eprintln!("STDOUT: {:?}", output.stdout);
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

    let r1 = shell.execute("$env.TEST_VAL = 42");
    assert!(r1.is_ok(), "First cmd failed: {:?}", r1.err());

    let cmd = format!("$env.TEST_VAL | save -f {}", test_file.display());
    let r2 = shell.execute(&cmd);
    assert!(r2.is_ok(), "Second cmd failed: {:?}", r2.err());

    let content = std::fs::read_to_string(&test_file);
    assert!(content.is_ok(), "State file not created");
    assert_eq!(content.unwrap().trim(), "42");

    let _ = std::fs::remove_file(&test_file);
}

#[test]
fn test_execute_with_exit_code() {
    let mut shell = PersistentShell::new().expect("Failed to create shell");
    let result = shell.execute("error make {msg: 'test error'}");

    assert!(result.is_ok(), "Execute failed: {:?}", result.err());
    let output = result.unwrap();
    eprintln!(
        "EXIT CODE: {}, STDOUT: {:?}",
        output.exit_code, output.stdout
    );
    assert_ne!(output.exit_code, 0, "Expected non-zero exit code for error");
}
