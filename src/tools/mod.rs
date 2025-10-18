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
pub mod mock;
#[cfg(test)]
pub use mock::MockToolExecutor;

#[cfg(test)]
mod discovery_test;
#[cfg(test)]
mod execution_test;
#[cfg(test)]
mod mod_test;
