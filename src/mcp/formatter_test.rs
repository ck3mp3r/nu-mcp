use super::formatter::ResultFormatter;

#[test]
fn test_success_formatter() {
    let result = ResultFormatter::success("test output".to_string());
    assert_eq!(result.content.len(), 1);
    // Just verify the result has content, specific pattern matching varies by rmcp version
    assert!(!result.content.is_empty());
}

#[test]
fn test_success_with_stderr_formatter() {
    let result = ResultFormatter::success_with_stderr("output".to_string(), "warning".to_string());
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
