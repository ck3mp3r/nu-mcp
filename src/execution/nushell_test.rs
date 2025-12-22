use std::env;

use super::{CommandExecutor, NushellExecutor};

#[tokio::test]
async fn test_nushell_executor_basic_command() {
    let executor = NushellExecutor;
    let work_dir = env::current_dir().unwrap();

    let result = executor.execute("echo 'hello'", &work_dir, None).await;

    assert!(result.is_ok());
    let (stdout, _stderr) = result.unwrap();
    assert!(stdout.contains("hello"));
}

#[tokio::test]
async fn test_nushell_executor_timeout_short_command() {
    // Short command should complete within default timeout
    let executor = NushellExecutor;
    let work_dir = env::current_dir().unwrap();

    let result = executor.execute("sleep 1sec", &work_dir, None).await;

    assert!(result.is_ok());
}

#[tokio::test]
async fn test_nushell_executor_timeout_with_parameter() {
    // Explicitly pass timeout parameter (5 seconds)
    let executor = NushellExecutor;
    let work_dir = env::current_dir().unwrap();

    // Command that takes 10 seconds should timeout with 5s limit
    let result = executor.execute("sleep 10sec", &work_dir, Some(5)).await;

    assert!(result.is_err());
    let error = result.unwrap_err();
    assert!(
        error.contains("timed out"),
        "Expected timeout error, got: {}",
        error
    );
    assert!(
        error.contains("5 seconds"),
        "Expected timeout message to mention 5 seconds, got: {}",
        error
    );
}

#[tokio::test]
async fn test_nushell_executor_stderr_preserved() {
    let executor = NushellExecutor;
    let work_dir = env::current_dir().unwrap();

    // Command that outputs to stderr
    let result = executor
        .execute("print -e 'error message'", &work_dir, None)
        .await;

    assert!(result.is_ok());
    let (_stdout, stderr) = result.unwrap();
    assert!(stderr.contains("error message"));
}
