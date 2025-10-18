use super::CommandExecutor;
use async_trait::async_trait;
use std::path::Path;

pub struct MockExecutor {
    pub stdout: String,
    pub stderr: String,
    pub should_fail: bool,
}

impl MockExecutor {
    pub fn new(stdout: String, stderr: String) -> Self {
        Self {
            stdout,
            stderr,
            should_fail: false,
        }
    }

    pub fn failing(error: String) -> Self {
        Self {
            stdout: String::new(),
            stderr: error.clone(),
            should_fail: true,
        }
    }
}

#[async_trait]
impl CommandExecutor for MockExecutor {
    async fn execute(
        &self,
        _command: &str,
        _working_dir: &Path,
    ) -> Result<(String, String), String> {
        if self.should_fail {
            Err(self.stderr.clone())
        } else {
            Ok((self.stdout.clone(), self.stderr.clone()))
        }
    }
}
