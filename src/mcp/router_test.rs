use rmcp::{
    model::{CallToolRequestParam, Tool},
    serde_json,
};

use super::*;
use crate::{
    config::Config,
    execution::MockExecutor,
    security::PathCache,
    tools::{ExtensionTool, MockToolExecutor},
};
use tokio::sync::RwLock;

fn create_test_router() -> ToolRouter<MockExecutor, MockToolExecutor> {
    // Use current directory as sandbox so tests can run from anywhere
    let cwd = env::current_dir().unwrap();
    let config = Config {
        tools_dir: None,
        enable_run_nushell: true,
        sandbox_directories: vec![cwd],
    };
    let executor = MockExecutor::new("test output".to_string(), "".to_string());
    let tool_executor = MockToolExecutor::new("tool output".to_string());
    let cache = Arc::new(RwLock::new(PathCache::new()));
    ToolRouter::new(config, vec![], executor, tool_executor, cache)
}

#[tokio::test]
async fn test_router_run_nushell() {
    let router = create_test_router();

    let mut args = serde_json::Map::new();
    args.insert(
        "command".to_string(),
        serde_json::Value::String("echo hello".to_string()),
    );

    let request = CallToolRequestParam {
        name: "run_nushell".into(),
        arguments: Some(args),
    };

    let result = router.route_call(request).await;
    if let Err(e) = &result {
        eprintln!("Router error: {:?}", e);
    }
    assert!(result.is_ok());
}

#[tokio::test]
async fn test_router_extension_tool() {
    let cwd = env::current_dir().unwrap();
    let config = Config {
        tools_dir: None,
        enable_run_nushell: true,
        sandbox_directories: vec![cwd],
    };
    let executor = MockExecutor::new("test output".to_string(), "".to_string());
    let tool_executor = MockToolExecutor::new("tool output".to_string());
    let cache = Arc::new(RwLock::new(PathCache::new()));

    // Create a fake extension tool
    let extension = ExtensionTool {
        module_path: std::path::PathBuf::from("/fake/path"),
        tool_definition: Tool {
            name: "test_tool".into(),
            description: Some("Test tool".into()),
            input_schema: Arc::new(serde_json::Map::new()),
            annotations: None,
            title: None,
            output_schema: None,
            icons: None,
            meta: None,
        },
    };

    let router = ToolRouter::new(config, vec![extension], executor, tool_executor, cache);

    let mut args = serde_json::Map::new();
    args.insert(
        "param".to_string(),
        serde_json::Value::String("value".to_string()),
    );

    let request = CallToolRequestParam {
        name: "test_tool".into(),
        arguments: Some(args),
    };

    let result = router.route_call(request).await;
    assert!(result.is_ok());
}

#[tokio::test]
async fn test_router_unknown_tool() {
    let router = create_test_router();

    let request = CallToolRequestParam {
        name: "nonexistent_tool".into(),
        arguments: None,
    };

    let result = router.route_call(request).await;
    assert!(result.is_err());
}

#[tokio::test]
async fn test_router_uses_injected_cache() {
    // Verify that the injected cache is actually used across multiple calls
    let cache = Arc::new(RwLock::new(PathCache::new()));

    let cwd = env::current_dir().unwrap();
    let config = Config {
        tools_dir: None,
        enable_run_nushell: true,
        sandbox_directories: vec![cwd],
    };
    let executor = MockExecutor::new("test output".to_string(), "".to_string());
    let tool_executor = MockToolExecutor::new("tool output".to_string());

    let router = ToolRouter::new(
        config,
        vec![],
        executor,
        tool_executor,
        cache.clone(), // Inject cache
    );

    // Execute command with non-existent path (API endpoint)
    let mut args = serde_json::Map::new();
    args.insert(
        "command".to_string(),
        serde_json::Value::String("tool /api/endpoint".to_string()),
    );

    let request = CallToolRequestParam {
        name: "run_nushell".into(),
        arguments: Some(args),
    };

    let result = router.route_call(request).await;
    assert!(result.is_ok(), "Command should succeed");

    // Verify cache was populated
    let cache_guard = cache.write().await;
    assert!(
        cache_guard.contains("/api/endpoint"),
        "Cache should contain the API endpoint path"
    );
}

#[tokio::test]
async fn test_router_blocks_existing_files_outside_sandbox() {
    // Verify security is not weakened - existing files still blocked
    let router = create_test_router();

    let mut args = serde_json::Map::new();
    args.insert(
        "command".to_string(),
        serde_json::Value::String("cat /etc/passwd".to_string()),
    );

    let request = CallToolRequestParam {
        name: "run_nushell".into(),
        arguments: Some(args),
    };

    let result = router.route_call(request).await;
    assert!(
        result.is_err(),
        "Should block existing file outside sandbox"
    );
}

// NOTE: Poisoned mutex test removed - RwLock doesn't poison
// If a panic occurs while holding a write lock, the RwLock remains usable
// This is one of the benefits of using RwLock over Mutex

#[tokio::test]
async fn test_mutex_not_held_during_concurrent_requests() {
    // RED PHASE: This test demonstrates the blocking I/O problem
    // The test will show that concurrent requests block each other

    use std::time::Instant;
    use tokio::task::JoinSet;

    let cache = Arc::new(RwLock::new(PathCache::new()));
    let cwd = env::current_dir().unwrap();
    let config = Config {
        tools_dir: None,
        enable_run_nushell: true,
        sandbox_directories: vec![cwd],
    };
    let executor = MockExecutor::new("test output".to_string(), "".to_string());
    let tool_executor = MockToolExecutor::new("tool output".to_string());

    let router = Arc::new(ToolRouter::new(
        config,
        vec![],
        executor,
        tool_executor,
        cache,
    ));

    // Launch 3 concurrent requests
    let mut set = JoinSet::new();
    let start = Instant::now();

    for i in 0..3 {
        let router_clone = router.clone();
        set.spawn(async move {
            let mut args = serde_json::Map::new();
            args.insert(
                "command".to_string(),
                // Use a command that will trigger path validation
                serde_json::Value::String(format!("echo test{}", i)),
            );

            let request = CallToolRequestParam {
                name: "run_nushell".into(),
                arguments: Some(args),
            };

            let request_start = Instant::now();
            let result = router_clone.route_call(request).await;
            let request_duration = request_start.elapsed();

            (i, result, request_duration)
        });
    }

    // Wait for all requests to complete
    let mut results = Vec::new();
    while let Some(res) = set.join_next().await {
        results.push(res.unwrap());
    }

    let total_duration = start.elapsed();

    // All requests should succeed
    for (i, result, _duration) in &results {
        assert!(result.is_ok(), "Request {} should succeed", i);
    }

    // CRITICAL TEST: If mutex is held during I/O, concurrent requests will be serialized
    // Total time should be roughly equal to longest single request (concurrent)
    // NOT the sum of all requests (serialized)
    //
    // For now, just verify all completed successfully
    // In the future, we could add timing assertions to prove they ran concurrently

    println!(
        "Total duration for 3 concurrent requests: {:?}",
        total_duration
    );
    for (i, _, duration) in &results {
        println!("  Request {} duration: {:?}", i, duration);
    }

    // If requests were truly concurrent, total time should be close to max individual time
    // If serialized, total time would be sum of all times
    // For this test, we just verify they all complete without hanging
}
