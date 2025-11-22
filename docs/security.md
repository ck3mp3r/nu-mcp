# Security

## Sandbox Security
- Commands execute within a directory sandbox (configurable with `--sandbox-dir`)
- Path traversal is context-aware: `../` is allowed if it stays within the sandbox
- Absolute paths outside the sandbox directory are blocked
- Extensions run in the same security context as the server process
- The sandbox provides directory isolation but does not restrict system resources, network access, or process spawning

## Safe Command Whitelist

Some commands accept path-like arguments (starting with `/`) that are **NOT** filesystem paths. These include:
- API endpoints (e.g., `/repos/owner/repo`)
- Resource identifiers (e.g., `/apis/apps/v1/deployments`)
- URL paths (e.g., `https://api.example.com/endpoint`)

The sandbox validation uses a **regex whitelist** to identify and allow these safe patterns.

### Whitelisted Command Patterns

The following command patterns bypass filesystem path validation:

1. **GitHub CLI API commands**
   - Pattern: `gh api <endpoint>`
   - Examples:
     - `gh api /repos/owner/repo/contents/file.yml`
     - `gh api repos/owner/repo | from json`

2. **kubectl API resource paths**
   - Pattern: `kubectl <verb> /api*`
   - Examples:
     - `kubectl get /apis/apps/v1/deployments`
     - `kubectl describe /api/v1/pods`
     - `kubectl delete /apis/batch/v1/jobs/myjob`

3. **ArgoCD application paths**
   - Pattern: `argocd app <command> /argocd/*`
   - Examples:
     - `argocd app get /argocd/myapp`
     - `argocd app sync /argocd/production/app`

4. **HTTP clients with URLs**
   - Patterns: `curl <url>`, `wget <url>`, `http <url>`
   - Examples:
     - `curl https://api.github.com/repos/owner/repo`
     - `wget http://example.com/file.txt`
     - `http get https://api.example.com/data`

5. **Nushell HTTP commands**
   - Pattern: `http <verb> <url>`
   - Examples:
     - `http get https://api.example.com/data`
     - `http post https://api.example.com/submit`

### Adding New Allowlist Patterns

Safe command patterns are loaded from `src/security/safe_command_patterns.txt` at **compile time**.

To add support for new tools:

1. **Edit** `src/security/safe_command_patterns.txt`
2. **Add your regex pattern** (one per line, comments start with #):

```
# Your new tool - API endpoint patterns
# Matches: your-tool api /endpoint/...
^your-tool\s+api\s+/
```

3. **Important**: Only add commands with NON-filesystem path arguments
   - ✅ API endpoints: `gh api /repos/...`
   - ✅ Resource IDs: `kubectl get /apis/...`
   - ✅ URLs: `curl https://...`
   - ❌ File paths: `cat /etc/passwd` (should be validated!)

4. **Add tests** in `src/security/mod_test.rs`:

```rust
#[test]
fn test_your_tool_in_allowlist() {
    let sandbox_dir = current_dir().unwrap();
    assert!(
        validate_path_safety("your-tool api /endpoint", &sandbox_dir).is_ok(),
        "your-tool api commands should be in allowlist"
    );
}
```

5. **Run tests**: `cargo test`
6. **Rebuild**: The pattern file is embedded at compile time, so rebuild to see changes

### Whitelist Design Principles

- **Specific patterns**: Patterns should be as specific as possible to avoid over-matching
- **Command-based**: Match on command structure, not just presence of `/`
- **Conservative**: When in doubt, don't whitelist (let path validation run)
- **Documented**: Each pattern should have a comment explaining its purpose

## Quote-Aware Path Validation

The security validator understands Nushell's quoting rules to reduce false positives:

### Allowed Content
The following are **NOT** validated as filesystem paths and will not trigger security blocks:

- **Quoted strings** containing paths:
  - `gh pr create --body "Fixed issue in /etc/config"`
  - `echo 'The file /etc/passwd is important'`
  - Backtick-quoted: `` echo `text with /slashes` ``
  
- **String interpolation** with paths:
  - `$"Config at /etc/app.conf"`
  - `$'Log file: /var/log/app.log'`

- **Multiline quoted strings** (including newlines):
  ```nushell
  gh pr create --body "
  This PR fixes /etc/config
  And updates /var/log/app.log
  "
  ```

- **URLs** (any protocol):
  - `curl https://example.com/api/v1/users`
  - `git clone git://example.com/repo.git`

- **Command options** with slashes:
  - `command --format=json/yaml`
  - `tool --output=path/to/file`

### Blocked Content
The following will still be blocked as potential sandbox escapes:

- **Bare absolute paths** outside sandbox (not in quotes):
  - `cat /etc/passwd` ❌
  - `ls /tmp/secret` ❌

- **Path traversal that escapes sandbox**:
  - `cd ../../../../etc` ❌ (escapes sandbox root)
  - `ls ../../../secret` ❌ (goes above sandbox)
  
- **Allowed path traversal within sandbox**:
  - `cd subdir/../otherdir` ✅ (stays in sandbox)
  - `ls ./a/b/../../file.txt` ✅ (resolves to `./file.txt`)

- **Home directory paths** outside sandbox:
  - `cat ~/.bashrc` ❌ (if home is outside sandbox)

### How It Works

The validator implements Nushell-aware parsing with context-aware path traversal checking:
1. Extracts only **non-quoted words** from commands
2. Skips validation for content inside single quotes `'...'`, double quotes `"..."`, backticks `` `...` ``, and string interpolation `$"..."` / `$'...'`
3. Handles multiline strings correctly (newlines inside quotes are treated as content, not separators)
4. Distinguishes URLs from filesystem paths
5. Ignores command options that contain slashes (like `--format=/path`)
6. **Resolves path traversal** (`../`) relative to sandbox and checks if result stays within bounds
7. Only validates words that look like paths (contain `/`, `\`, or start with `~`)

## Security Considerations
- Review tool implementations before deployment
- Use appropriate sandbox directories for your use case
- Monitor network access from tools that make external API calls
- Consider running multiple instances with different permission levels
- Tools have access to environment variables and can execute system commands within the sandbox

## Disclaimer

**USE AT YOUR OWN RISK**: This software is provided "as is" without warranty of any kind. The author(s) accept no responsibility or liability for any damage, data loss, security breaches, or other issues that may result from using this software. Users are solely responsible for:

- Reviewing and understanding the security implications before deployment
- Properly configuring sandbox directories and access controls
- Testing thoroughly in non-production environments
- Monitoring and securing their systems when running this software
- Any consequences resulting from the execution of commands or scripts

By using this software, you acknowledge that you understand these risks and agree to use it at your own discretion and responsibility.