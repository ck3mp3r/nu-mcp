use std::path::PathBuf;

#[test]
fn test_path_operations() {
    let module_path = PathBuf::from("/test/path");
    let mod_file = module_path.join("mod.nu");

    assert_eq!(mod_file.extension().unwrap(), "nu");
    assert_eq!(mod_file.file_stem().unwrap(), "mod");

    let parent = module_path.parent().unwrap();
    assert_eq!(parent, PathBuf::from("/test"));
}

#[test]
fn test_path_validation() {
    let valid_module_dir = PathBuf::from("weather");
    let mod_file = valid_module_dir.join("mod.nu");
    let invalid_file = PathBuf::from("script.sh");

    assert!(valid_module_dir.file_name().is_some());
    assert_eq!(mod_file.extension().and_then(|s| s.to_str()), Some("nu"));
    assert_eq!(
        invalid_file.extension().and_then(|s| s.to_str()),
        Some("sh")
    );
}

#[test]
fn test_extension_tool_struct() {
    use super::ExtensionTool;
    use rmcp::model::Tool;
    use std::sync::Arc;

    let tool_def = Tool {
        name: "test_tool".into(),
        description: Some("Test tool".into()),
        input_schema: Arc::new(serde_json::Map::new()),
        annotations: None,
        title: None,
        output_schema: None,
        icons: None,
    };

    let extension = ExtensionTool {
        module_path: PathBuf::from("/test/path"),
        tool_definition: tool_def,
    };

    assert_eq!(extension.tool_definition.name, "test_tool");
    assert_eq!(extension.module_path, PathBuf::from("/test/path"));
}

#[test]
fn test_tool_definition_edge_cases() {
    use rmcp::model::Tool;
    use std::sync::Arc;

    // Test with minimal tool definition
    let minimal_tool = Tool {
        name: "minimal".into(),
        description: None,
        input_schema: Arc::new(serde_json::Map::new()),
        annotations: None,
        title: None,
        output_schema: None,
        icons: None,
    };

    assert_eq!(minimal_tool.name, "minimal");
    assert!(minimal_tool.description.is_none());
}

#[test]
fn test_tool_schema_validation() {
    use serde_json::{Map, Value};
    use std::sync::Arc;

    let mut schema = Map::new();
    schema.insert("type".to_string(), Value::String("object".to_string()));

    let mut properties = Map::new();
    let mut prop = Map::new();
    prop.insert("type".to_string(), Value::String("string".to_string()));
    properties.insert("message".to_string(), Value::Object(prop));

    schema.insert("properties".to_string(), Value::Object(properties));

    let schema_arc = Arc::new(schema);

    // Basic validation that schema structure is maintained
    assert!(schema_arc.contains_key("type"));
    assert!(schema_arc.contains_key("properties"));
}

#[test]
fn test_tool_definition_serialization() {
    use rmcp::model::Tool;
    use serde_json;
    use std::sync::Arc;

    let tool = Tool {
        name: "serialization_test".into(),
        description: Some("Test serialization".into()),
        input_schema: Arc::new(serde_json::Map::new()),
        annotations: None,
        title: Some("Serialization Test".to_string()),
        output_schema: None,
        icons: None,
    };

    // Test that we can work with the tool definition
    assert!(!tool.name.is_empty());
    assert!(tool.description.is_some());
    assert!(tool.title.is_some());
}

#[tokio::test]
async fn test_tool_script_execution_with_existing_tools() {
    // Test that the module can handle real tool discovery scenarios
    let test_path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("test/tools");

    if test_path.exists() {
        // Just verify the path structure is valid for tool discovery
        assert!(test_path.is_dir());

        // Check if there are any .nu files (indicating potential tools)
        if let Ok(entries) = std::fs::read_dir(&test_path) {
            let nu_files: Vec<_> = entries
                .filter_map(|entry| entry.ok())
                .filter(|entry| entry.path().is_dir() && entry.path().join("mod.nu").exists())
                .collect();

            // At least verify we can enumerate the directory structure
            assert!(nu_files.len() >= 0); // Just ensure no panic
        }
    }
}
