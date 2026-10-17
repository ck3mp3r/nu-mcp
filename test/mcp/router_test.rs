use rmcp::{model::Tool, serde_json};

use super::*;
use crate::{
    config::Config,
    execution::NushellExecutor,
    tools::{ExtensionTool, MockToolExecutor},
};
use std::sync::Arc;

fn create_test_router() -> ToolRouter<NushellExecutor, MockToolExecutor> {
    // Use current directory as sandbox so tests can run from anywhere
    let cwd = env::current_dir().unwrap();
    let config = Config {
        tools_dir: None,
        enable_nu: true,
        sandbox_directories: vec![cwd],
        block_network: false,
        bypass_protection: vec![],
        read_only_paths: vec![],
    };
    let stateless_executor = NushellExecutor;
    let tool_executor = MockToolExecutor::new("tool output".to_string());
    ToolRouter::new(config, vec![], stateless_executor, tool_executor)
}

#[tokio::test]
async fn test_router_run_stateless() {
    let router = create_test_router();

    let mut args = serde_json::Map::new();
    args.insert(
        "command".to_string(),
        serde_json::Value::String("echo hello".to_string()),
    );

    let request = CallToolRequestParams::new("run").with_arguments(args);

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
        enable_nu: true,
        sandbox_directories: vec![cwd],
        block_network: false,
        bypass_protection: vec![],
        read_only_paths: vec![],
    };
    let stateless_executor = NushellExecutor;
    let tool_executor = MockToolExecutor::new("tool output".to_string());

    // Create a fake extension tool
    let extension = ExtensionTool {
        module_path: std::path::PathBuf::from("/fake/path"),
        tool_definition: Tool::new("test_tool", "Test tool", Arc::new(serde_json::Map::new())),
    };

    let router = ToolRouter::new(config, vec![extension], stateless_executor, tool_executor);

    let mut args = serde_json::Map::new();
    args.insert(
        "param".to_string(),
        serde_json::Value::String("value".to_string()),
    );

    let request = CallToolRequestParams::new("test_tool").with_arguments(args);

    let result = router.route_call(request).await;
    assert!(result.is_ok());
}

#[tokio::test]
async fn test_router_unknown_tool() {
    let router = create_test_router();

    let request = CallToolRequestParams::new("nonexistent_tool");

    let result = router.route_call(request).await;
    assert!(result.is_err());
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

    let cwd = env::current_dir().unwrap();
    let config = Config {
        tools_dir: None,
        enable_nu: true,
        sandbox_directories: vec![cwd],
        block_network: false,
        bypass_protection: vec![],
        read_only_paths: vec![],
    };
    let stateless_executor = NushellExecutor;
    let tool_executor = MockToolExecutor::new("tool output".to_string());

    let router = Arc::new(ToolRouter::new(
        config,
        vec![],
        stateless_executor,
        tool_executor,
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
                serde_json::Value::String(format!("echo test{}", i)),
            );

            let request = CallToolRequestParams::new("run").with_arguments(args);

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
