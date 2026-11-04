use std::env;

use super::{CommandExecutor, NushellExecutor};

type Result<T> = core::result::Result<T, Box<dyn std::error::Error>>;

#[tokio::test]
async fn test_nushell_executor_basic_command() -> Result<()> {
    let executor = NushellExecutor;
    let work_dir = env::current_dir()?;

    let result = executor.execute("echo 'hello'", &work_dir, None).await;

    assert!(result.is_ok());
    let (stdout, _stderr) = result?;
    assert!(stdout.contains("hello"));
    Ok(())
}

#[tokio::test]
async fn test_nushell_executor_timeout_short_command() -> Result<()> {
    // Short command should complete within default timeout
    let executor = NushellExecutor;
    let work_dir = env::current_dir()?;

    let result = executor.execute("sleep 1sec", &work_dir, None).await;

    assert!(result.is_ok());
    Ok(())
}

#[tokio::test]
async fn test_nushell_executor_timeout_with_parameter() -> Result<()> {
    // Explicitly pass timeout parameter (5 seconds)
    let executor = NushellExecutor;
    let work_dir = env::current_dir()?;

    // Command that takes 10 seconds should timeout with 5s limit
    let result = executor.execute("sleep 10sec", &work_dir, Some(5)).await;

    assert!(result.is_err());
    let error = result.err().ok_or("command should time out")?;
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
    Ok(())
}

#[tokio::test]
async fn test_nushell_executor_stderr_preserved() -> Result<()> {
    let executor = NushellExecutor;
    let work_dir = env::current_dir()?;

    // Command that outputs to stderr
    let result = executor
        .execute("print -e 'error message'", &work_dir, None)
        .await;

    assert!(result.is_ok());
    let (_stdout, stderr) = result?;
    assert!(stderr.contains("error message"));
    Ok(())
}

#[tokio::test]
async fn test_nushell_executor_nonzero_exit_is_error() -> Result<()> {
    let executor = NushellExecutor;
    let work_dir = env::current_dir()?;

    // Command that exits with a non-zero status
    let result = executor.execute("exit 1", &work_dir, None).await;

    assert!(result.is_err());
    let error = result.err().ok_or("command should fail on non-zero exit")?;
    assert!(
        error.contains("nu exited with"),
        "Expected non-zero exit error, got: {}",
        error
    );
    Ok(())
}
