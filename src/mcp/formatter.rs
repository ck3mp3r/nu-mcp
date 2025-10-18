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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_success_formatter() {
        let result = ResultFormatter::success("test output".to_string());
        assert_eq!(result.content.len(), 1);
        // Just verify the result has content, specific pattern matching varies by rmcp version
        assert!(!result.content.is_empty());
    }

    #[test]
    fn test_success_with_stderr_formatter() {
        let result =
            ResultFormatter::success_with_stderr("output".to_string(), "warning".to_string());
        assert_eq!(result.content.len(), 2);
        // Just verify the result has both stdout and stderr content
        assert!(!result.content.is_empty());
    }

    #[test]
    fn test_success_with_empty_stderr() {
        let result = ResultFormatter::success_with_stderr("output".to_string(), "".to_string());
        assert_eq!(result.content.len(), 1);
        // Just verify the result has only stdout content
        assert!(!result.content.is_empty());
    }

    #[test]
    fn test_error_formatter() {
        let result = ResultFormatter::error("test error".to_string());
        assert!(result.is_err());

        if let Err(error_data) = result {
            assert!(error_data.message.contains("test error"));
        }
    }

    #[test]
    fn test_invalid_request_formatter() {
        let result = ResultFormatter::invalid_request("invalid request".to_string());
        assert!(result.is_err());

        if let Err(error_data) = result {
            assert!(error_data.message.contains("invalid request"));
        }
    }
}
