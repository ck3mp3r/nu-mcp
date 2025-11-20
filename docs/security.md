# Security

## Sandbox Security
- Commands execute within a directory sandbox (configurable with `--sandbox-dir`)
- Path traversal is context-aware: `../` is allowed if it stays within the sandbox
- Absolute paths outside the sandbox directory are blocked
- Extensions run in the same security context as the server process
- The sandbox provides directory isolation but does not restrict system resources, network access, or process spawning

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