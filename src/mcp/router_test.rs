use std::{path::PathBuf, sync::Arc};

use rmcp::{
    model::{CallToolRequestParam, Tool},
    serde_json,
};

use super::*;
use crate::{
    config::Config,
    execution::MockExecutor,
    tools::{ExtensionTool, MockToolExecutor},
};

fn create_test_router() -> ToolRouter<MockExecutor, MockToolExecutor> {
    let config = Config {
        tools_dir: None,
        enable_run_nushell: true,
        sandbox_directory: Some(PathBuf::from("/tmp")),
    };
    let executor = MockExecutor::new("test output".to_string(), "".to_string());
    let tool_executor = MockToolExecutor::new("tool output".to_string());
    ToolRouter::new(config, vec![], executor, tool_executor)
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

    let call_result = result.unwrap();
    assert!(!call_result.content.is_empty());
}

#[tokio::test]
async fn test_router_unknown_tool() {
    let router = create_test_router();

    let request = CallToolRequestParam {
        name: "unknown_tool".into(),
        arguments: None,
    };

    let result = router.route_call(request).await;
    assert!(result.is_err());
}

#[tokio::test]
async fn test_router_extension_tool() {
    let config = Config {
        tools_dir: None,
        enable_run_nushell: true,
        sandbox_directory: Some(PathBuf::from("/tmp")),
    };

    let extension = ExtensionTool {
        module_path: PathBuf::from("/test/path"),
        tool_definition: Tool {
            name: "test_tool".into(),
            description: None,
            input_schema: Arc::new(serde_json::Map::new()),
            annotations: None,
            title: None,
            output_schema: None,
            icons: None,
        },
    };

    let executor = MockExecutor::new("test output".to_string(), "".to_string());
    let tool_executor = MockToolExecutor::new("extension output".to_string());
    let router = ToolRouter::new(config, vec![extension], executor, tool_executor);

    let request = CallToolRequestParam {
        name: "test_tool".into(),
        arguments: None,
    };

    let result = router.route_call(request).await;
    assert!(result.is_ok());

    let call_result = result.unwrap();
    assert!(!call_result.content.is_empty());
}
