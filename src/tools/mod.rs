use rmcp::model::Tool;
use std::path::PathBuf;

#[derive(Debug, Clone)]
pub struct ExtensionTool {
    pub module_path: PathBuf,
    pub tool_definition: Tool,
}

pub mod discovery;
pub mod execution;

pub use discovery::discover_tools;
pub use execution::{NushellToolExecutor, ToolExecutor};

#[cfg(test)]
#[path = "../../test/tools/mock.rs"]
pub mod mock;
#[cfg(test)]
pub use mock::MockToolExecutor;

#[cfg(test)]
#[path = "../../test/tools/discovery_test.rs"]
mod discovery_test;
#[cfg(test)]
#[path = "../../test/tools/execution_test.rs"]
mod execution_test;
#[cfg(test)]
#[path = "../../test/tools/mod_test.rs"]
mod mod_test;
