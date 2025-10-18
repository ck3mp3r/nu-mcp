use std::path::Path;

use super::{CommandExecutor, MockExecutor};

#[tokio::test]
async fn test_mock_executor_success() {
    let executor = MockExecutor::new("Hello World".to_string(), String::new());
    let result = executor.execute("echo hello", Path::new("/tmp")).await;

    assert!(result.is_ok());
    let (stdout, stderr) = result.unwrap();
    assert_eq!(stdout, "Hello World");
    assert_eq!(stderr, "");
}

#[tokio::test]
async fn test_mock_executor_with_stderr() {
    let executor = MockExecutor::new("output".to_string(), "warning message".to_string());
    let result = executor.execute("some command", Path::new("/tmp")).await;

    assert!(result.is_ok());
    let (stdout, stderr) = result.unwrap();
    assert_eq!(stdout, "output");
    assert_eq!(stderr, "warning message");
}

#[tokio::test]
async fn test_mock_executor_failure() {
    let executor = MockExecutor::failing("command not found".to_string());
    let result = executor.execute("invalid command", Path::new("/tmp")).await;

    assert!(result.is_err());
    assert_eq!(result.unwrap_err(), "command not found");
}
