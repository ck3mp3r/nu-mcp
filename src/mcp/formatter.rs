use rmcp::model::{CallToolResult, Content, ErrorData};

pub struct ResultFormatter;

impl ResultFormatter {
    pub fn success(output: String) -> CallToolResult {
        CallToolResult::success(vec![Content::text(output)])
    }

    pub fn success_with_stderr(stdout: String, stderr: String) -> CallToolResult {
        let mut content = vec![Content::text(stdout)];
        if !stderr.is_empty() {
            content.push(Content::text(format!("stderr: {stderr}")));
        }
        CallToolResult::success(content)
    }

    pub fn error(message: String) -> Result<CallToolResult, ErrorData> {
        Err(ErrorData::internal_error(message, None))
    }

    pub fn invalid_request(message: String) -> Result<CallToolResult, ErrorData> {
        Err(ErrorData::invalid_request(message, None))
    }
}
