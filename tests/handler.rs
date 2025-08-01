use nu_mcp::filter::Config;
use nu_mcp::handler::NushellTool;
use rmcp::handler::server::ServerHandler;

#[test]
fn test_get_info_includes_allowed_and_denied() {
    let config = Config {
        allowed_commands: vec!["ls".into(), "cat".into()],
        denied_commands: vec!["rm".into(), "shutdown".into()],
        allow_sudo: true,
    };
    let tool = NushellTool { config };
    let info = tool.get_info();
    let instructions = info.instructions.unwrap();
    assert!(instructions.contains("ls"));
    assert!(instructions.contains("cat"));
    assert!(instructions.contains("rm"));
    assert!(instructions.contains("shutdown"));
    assert!(instructions.contains("Sudo allowed: yes"));
}

#[test]
fn test_get_info_empty_lists() {
    let config = Config {
        allowed_commands: vec![],
        denied_commands: vec![],
        allow_sudo: false,
    };
    let tool = NushellTool { config };
    let info = tool.get_info();
    let instructions = info.instructions.unwrap();
    assert!(instructions.contains("(none specified)"));
    assert!(instructions.contains("Sudo allowed: no"));
}
