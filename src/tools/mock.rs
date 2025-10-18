use super::{ExtensionTool, execution::ToolExecutor};
use async_trait::async_trait;

pub struct MockToolExecutor {
    pub output: String,
    pub should_fail: bool,
    pub error_message: String,
}

impl MockToolExecutor {
    pub fn new(output: String) -> Self {
        Self {
            output,
            should_fail: false,
            error_message: String::new(),
        }
    }

    pub fn failing(error: String) -> Self {
        Self {
            output: String::new(),
            should_fail: true,
            error_message: error,
        }
    }
}

#[async_trait]
impl ToolExecutor for MockToolExecutor {
    async fn execute_tool(
        &self,
        _extension: &ExtensionTool,
        _tool_name: &str,
        _args: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        if self.should_fail {
            Err(self.error_message.clone().into())
        } else {
            Ok(self.output.clone())
        }
    }
}
