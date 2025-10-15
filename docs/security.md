# Security

## Sandbox Security
- Commands execute within a directory sandbox (configurable with `--sandbox-dir`)
- Path traversal patterns (`../`) are blocked to prevent escaping the sandbox
- Absolute paths outside the sandbox directory are blocked
- Extensions run in the same security context as the server process
- The sandbox provides directory isolation but does not restrict system resources, network access, or process spawning

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