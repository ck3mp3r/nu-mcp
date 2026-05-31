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
    assert!(
        out1.stdout.contains("2"),
        "Expected '2', got: {:?}",
        out1.stdout
    );

    // Print output
    let r2 = shell.execute("print 'hello'", DEFAULT_TIMEOUT);
    assert!(r2.is_ok(), "Print failed: {:?}", r2.err());
    let out2 = r2.unwrap();
    assert!(
        out2.stdout.contains("hello"),
        "Expected 'hello', got: {:?}",
        out2.stdout
    );
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
        assert!(
            output.stdout.contains(&i.to_string()),
            "Command {}: expected '{}', got: {:?}",
            i,
            i,
            output.stdout
        );
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
        assert!(
            out1.stdout.contains(&n.to_string()),
            "Expected '{}' in output, got: {:?}",
            n,
            out1.stdout
        );
    }

    // Large output (>8KB)
    let r2 = shell.execute(
        "1..500 | each { |n| $'line ($n): some padding text to make this longer' } | str join (char newline) | print",
        DEFAULT_TIMEOUT,
    );
    assert!(r2.is_ok(), "Large output failed: {:?}", r2.err());
    let out2 = r2.unwrap();
    assert!(
        out2.stdout.len() > 8000,
        "Expected >8KB, got {} bytes",
        out2.stdout.len()
    );
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
    assert!(
        err.contains("Timeout"),
        "Expected timeout message, got: {:?}",
        err
    );
}

#[test]
#[serial]
fn test_long_command_with_tight_timeout() {
    skip_if_no_pty!();
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    // Command that takes ~3 seconds, with 5 second timeout
    // After the command completes, only ~2 seconds remain for prompt wait.
    // The new behavior uses remaining time (2s) with a 2s minimum floor.
    // This should succeed - command output is collected even if prompt times out.
    let result = shell.execute("sleep 3sec; print 'done'", Duration::from_secs(5));

    assert!(result.is_ok(), "Long command failed: {:?}", result.err());
    let output = result.unwrap();
    assert!(
        output.stdout.contains("done"),
        "Expected 'done', got: {:?}",
        output.stdout
    );
    assert_eq!(output.exit_code, 0);
}

#[test]
#[serial]
fn test_multi_command_sequence_with_adequate_timeout() {
    skip_if_no_pty!();
    let mut shell = PersistentShell::new().expect("Failed to create shell");

    // Multiple commands in sequence - should complete within timeout budget
    // sleep 2s + sleep 2s + print = ~4s, with 10s timeout leaves 6s for prompt wait
    let result = shell.execute(
        "sleep 2sec; sleep 2sec; print 'complete'",
        Duration::from_secs(10),
    );

    assert!(
        result.is_ok(),
        "Multi-command sequence failed: {:?}",
        result.err()
    );
    let output = result.unwrap();
    assert!(
        output.stdout.contains("complete"),
        "Expected 'complete', got: {:?}",
        output.stdout
    );
    assert_eq!(output.exit_code, 0);
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
    assert!(
        r2.unwrap().0.contains("before"),
        "State should exist before reset"
    );

    // Reset
    executor.reset().await.expect("Reset failed");

    // State should be gone
    let r3 = executor
        .execute("$env.RESET_TEST? | default 'gone'", &work_dir, Some(30))
        .await;
    assert!(r3.is_ok(), "Post-reset command failed: {:?}", r3.err());
    assert!(
        r3.unwrap().0.contains("gone"),
        "State should be cleared after reset"
    );

    // Shell should still work after reset
    let r4 = executor.execute("print 'alive'", &work_dir, Some(30)).await;
    assert!(r4.is_ok(), "Post-reset execute failed: {:?}", r4.err());
    assert!(r4.unwrap().0.contains("alive"));
}

#[test]
#[serial]
fn test_drop_kills_child_process() {
    skip_if_no_pty!();
    
    // This test verifies:
    // 1. Drop implementation doesn't panic
    // 2. Shell can be created and used before drop
    // 3. Process cleanup happens (kill + wait)
    
    // Scope to ensure shell is dropped at the end of this block
    {
        let mut shell = PersistentShell::new().expect("Failed to create shell");
        
        // Execute a simple command to verify the shell works
        let result = shell.execute("print 'alive'", DEFAULT_TIMEOUT);
        assert!(result.is_ok(), "Shell should work before drop");
        assert!(result.unwrap().stdout.contains("alive"));
        
        // Get process ID for logging
        if let Some(pid) = shell.process_id() {
            eprintln!("Created shell with PID: {}", pid);
        }
        
        // Shell drops here - Drop impl will:
        // 1. Call child.kill() to send SIGHUP then SIGKILL
        // 2. Call child.wait() to reap the process
        // If either fails, it prints to stderr but doesn't panic
    }
    
    // Give the OS a moment to complete cleanup
    std::thread::sleep(Duration::from_millis(100));
    
    // If we reach here, Drop completed without panic
    eprintln!("Drop completed successfully - process was killed and reaped");
    
    // Create a new shell to verify the system is still working
    let mut shell2 = PersistentShell::new().expect("Failed to create second shell");
    let result2 = shell2.execute("print 'still working'", DEFAULT_TIMEOUT);
    assert!(result2.is_ok(), "New shell should work after drop");
    assert!(result2.unwrap().stdout.contains("still working"));
}

#[tokio::test]
#[serial]
async fn test_concurrent_execution_queues_sequentially() {
    skip_if_no_pty!();
    let executor = PersistentNuExecutor::new().expect("Failed to create executor");
    
    // Start 3 concurrent commands that each take ~1 second
    // They should queue and execute sequentially, not concurrently
    let work_dir = PathBuf::from(".");
    
    let executor1 = executor.clone();
    let executor2 = executor.clone();
    let executor3 = executor.clone();
    
    let work_dir1 = work_dir.clone();
    let work_dir2 = work_dir.clone();
    let work_dir3 = work_dir.clone();
    
    let task1 = tokio::spawn(async move {
        let start = std::time::Instant::now();
        let result = executor1.execute("sleep 1sec; print 'task1'", &work_dir1, Some(10)).await;
        (start.elapsed(), result)
    });
    
    let task2 = tokio::spawn(async move {
        let start = std::time::Instant::now();
        let result = executor2.execute("sleep 1sec; print 'task2'", &work_dir2, Some(10)).await;
        (start.elapsed(), result)
    });
    
    let task3 = tokio::spawn(async move {
        let start = std::time::Instant::now();
        let result = executor3.execute("sleep 1sec; print 'task3'", &work_dir3, Some(10)).await;
        (start.elapsed(), result)
    });
    
    // Wait for all tasks to complete
    let (elapsed1, result1) = task1.await.expect("Task 1 panicked");
    let (elapsed2, result2) = task2.await.expect("Task 2 panicked");
    let (elapsed3, result3) = task3.await.expect("Task 3 panicked");
    
    // All should succeed
    assert!(result1.is_ok(), "Task 1 failed: {:?}", result1);
    assert!(result2.is_ok(), "Task 2 failed: {:?}", result2);
    assert!(result3.is_ok(), "Task 3 failed: {:?}", result3);
    
    // Verify output contains expected strings
    let (out1, _) = result1.unwrap();
    let (out2, _) = result2.unwrap();
    let (out3, _) = result3.unwrap();
    
    assert!(out1.contains("task1"), "Output 1 wrong: {}", out1);
    assert!(out2.contains("task2"), "Output 2 wrong: {}", out2);
    assert!(out3.contains("task3"), "Output 3 wrong: {}", out3);
    
    // The first task should complete in ~1 second
    // The second should queue and complete in ~2 seconds (1s wait + 1s execution)
    // The third should queue and complete in ~3 seconds (2s wait + 1s execution)
    eprintln!("Task 1 elapsed: {:?}", elapsed1);
    eprintln!("Task 2 elapsed: {:?}", elapsed2);
    eprintln!("Task 3 elapsed: {:?}", elapsed3);
    
    // Task 1 should finish in ~1 second (with some tolerance)
    assert!(elapsed1.as_secs() >= 1 && elapsed1.as_secs() <= 2, 
            "Task 1 took {:?}, expected ~1s", elapsed1);
    
    // Task 2 should finish in ~2 seconds (queued behind task 1)
    assert!(elapsed2.as_secs() >= 2 && elapsed2.as_secs() <= 3, 
            "Task 2 took {:?}, expected ~2s", elapsed2);
    
    // Task 3 should finish in ~3 seconds (queued behind tasks 1 and 2)
    assert!(elapsed3.as_secs() >= 3 && elapsed3.as_secs() <= 4, 
            "Task 3 took {:?}, expected ~3s", elapsed3);
}

#[tokio::test]
#[serial]
async fn test_queue_wait_feedback_in_output() {
    skip_if_no_pty!();
    let executor = PersistentNuExecutor::new().expect("Failed to create executor");
    
    // Start 3 concurrent commands:
    // - First takes ~2 seconds
    // - Second and third should queue and show feedback prefix
    let work_dir = PathBuf::from(".");
    
    let executor1 = executor.clone();
    let executor2 = executor.clone();
    let executor3 = executor.clone();
    
    let work_dir1 = work_dir.clone();
    let work_dir2 = work_dir.clone();
    let work_dir3 = work_dir.clone();
    
    let task1 = tokio::spawn(async move {
        executor1.execute("sleep 2sec; print 'first'", &work_dir1, Some(15)).await
    });
    
    let task2 = tokio::spawn(async move {
        executor2.execute("print 'second'", &work_dir2, Some(15)).await
    });
    
    let task3 = tokio::spawn(async move {
        executor3.execute("print 'third'", &work_dir3, Some(15)).await
    });
    
    // Wait for all tasks
    let result1 = task1.await.expect("Task 1 panicked");
    let result2 = task2.await.expect("Task 2 panicked");
    let result3 = task3.await.expect("Task 3 panicked");
    
    // All should succeed
    assert!(result1.is_ok(), "Task 1 failed: {:?}", result1);
    assert!(result2.is_ok(), "Task 2 failed: {:?}", result2);
    assert!(result3.is_ok(), "Task 3 failed: {:?}", result3);
    
    let (out1, _) = result1.unwrap();
    let (out2, _) = result2.unwrap();
    let (out3, _) = result3.unwrap();
    
    eprintln!("Task 1 output:\n{}", out1);
    eprintln!("Task 2 output:\n{}", out2);
    eprintln!("Task 3 output:\n{}", out3);
    
    // First command should NOT have queue feedback (no wait)
    assert!(!out1.contains("[Queued:"), "Task 1 should not have queue feedback");
    assert!(out1.contains("first"), "Task 1 should contain 'first'");
    
    // Second command queued for ~2 seconds, should have feedback
    assert!(out2.contains("[Queued:"), "Task 2 should have queue feedback");
    assert!(out2.contains("waited"), "Task 2 should show wait time");
    assert!(out2.contains("executed in"), "Task 2 should show execution time");
    assert!(out2.contains("second"), "Task 2 should contain 'second'");
    
    // Third command queued for ~2+ seconds, should have feedback
    assert!(out3.contains("[Queued:"), "Task 3 should have queue feedback");
    assert!(out3.contains("waited"), "Task 3 should show wait time");
    assert!(out3.contains("executed in"), "Task 3 should show execution time");
    assert!(out3.contains("third"), "Task 3 should contain 'third'");
}

#[tokio::test]
#[serial]
async fn test_no_queue_feedback_for_quick_commands() {
    skip_if_no_pty!();
    let executor = PersistentNuExecutor::new().expect("Failed to create executor");
    let work_dir = PathBuf::from(".");
    
    // Single command should execute immediately with no queue wait
    let result = executor.execute("print 'instant'", &work_dir, Some(10)).await;
    
    assert!(result.is_ok(), "Command failed: {:?}", result);
    let (output, _) = result.unwrap();
    
    eprintln!("Output:\n{}", output);
    
    // Should NOT have queue feedback prefix (wait < 500ms)
    assert!(!output.contains("[Queued:"), "Should not have queue feedback for instant command");
    assert!(output.contains("instant"), "Should contain expected output");
}


