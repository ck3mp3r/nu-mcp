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

#[tokio::test]
async fn test_nushell_executor_stdin_closed_prevents_blocking() {
    // Commands that would block waiting for stdin should complete immediately
    // because stdin is set to Stdio::null()
    let executor = NushellExecutor;
    let work_dir = env::current_dir().unwrap();

    use std::time::Instant;
    let start = Instant::now();

    // 'cat' without input would normally block waiting for stdin
    // With stdin closed (Stdio::null()), it should return immediately
    let result = executor.execute("^cat", &work_dir, Some(5)).await;

    let elapsed = start.elapsed().as_millis();

    // Should complete successfully (empty output) - not hang or timeout
    assert!(
        result.is_ok(),
        "Command should complete, but got: {:?}",
        result
    );

    let (stdout, _stderr) = result.unwrap();
    assert_eq!(stdout, "", "cat with no input should produce empty output");

    // CRITICAL: Should complete nearly instantly, not wait for timeout
    assert!(
        elapsed < 1000,
        "Command should complete instantly, but took {} ms. Stdin not closed properly!",
        elapsed
    );
}

#[tokio::test]
async fn test_nushell_executor_timeout_kills_long_running_process() {
    // Test that timeout actually kills long-running processes
    let executor = NushellExecutor;
    let work_dir = env::current_dir().unwrap();

    use std::time::Instant;
    let start = Instant::now();

    // Infinite loop - should be killed by timeout
    let result = executor
        .execute("loop { sleep 100ms }", &work_dir, Some(2))
        .await;

    let elapsed = start.elapsed().as_secs();

    // Verify it timed out
    assert!(
        result.is_err(),
        "Command should timeout, but got: {:?}",
        result
    );

    let error = result.unwrap_err();
    assert!(
        error.contains("timed out"),
        "Expected timeout error, got: {}",
        error
    );

    // Should timeout within ~2 seconds (with 1 second grace)
    assert!(
        elapsed <= 3,
        "Command should timeout in ~2 seconds, but took {} seconds",
        elapsed
    );
}
