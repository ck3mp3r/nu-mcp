use std::path::Path;

use super::{CommandExecutor, MockExecutor};

type Result<T> = core::result::Result<T, Box<dyn std::error::Error>>;

#[tokio::test]
async fn test_mock_executor_success() -> Result<()> {
    let executor = MockExecutor::new("Hello World".to_string(), String::new());
    let result = executor
        .execute("echo hello", Path::new("/tmp"), None)
        .await;

    assert!(result.is_ok());
    let (stdout, stderr) = result?;
    assert_eq!(stdout, "Hello World");
    assert_eq!(stderr, "");
    Ok(())
}

#[tokio::test]
async fn test_mock_executor_with_stderr() -> Result<()> {
    let executor = MockExecutor::new("output".to_string(), "warning message".to_string());
    let result = executor
        .execute("some command", Path::new("/tmp"), None)
        .await;

    assert!(result.is_ok());
    let (stdout, stderr) = result?;
    assert_eq!(stdout, "output");
    assert_eq!(stderr, "warning message");
    Ok(())
}

#[tokio::test]
async fn test_mock_executor_failure() -> Result<()> {
    let executor = MockExecutor::failing("command not found".to_string());
    let result = executor
        .execute("invalid command", Path::new("/tmp"), None)
        .await;

    assert!(result.is_err());
    let err = result.err().ok_or("failing executor should return Err")?;
    assert_eq!(err, "command not found");
    Ok(())
}
