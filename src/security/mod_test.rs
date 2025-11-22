use super::validate_path_safety;
use std::{env::current_dir, path::Path};

fn default_sandbox_dir() -> &'static Path {
    Path::new("/tmp/test_sandbox")
}

// NOTE: Quote-based tests removed because quotes don't prevent filesystem access!
// cat "/etc/passwd" will still read the file even though it's quoted.
// The allowlist approach handles specific safe patterns instead.

#[test]
fn test_string_interpolation_with_paths_allowed() {
    // String interpolation with double quotes
    assert!(
        validate_path_safety(r#"echo $"Config at /etc/app.conf""#, default_sandbox_dir()).is_ok(),
        "String interpolation with path should be allowed"
    );

    // String interpolation with single quotes
    assert!(
        validate_path_safety(
            r#"echo $'Log file: /var/log/app.log'"#,
            default_sandbox_dir()
        )
        .is_ok(),
        "String interpolation with single quotes should be allowed"
    );
}

#[test]
fn test_multiline_quoted_strings_allowed() {
    // Multiline double-quoted string with paths
    let multiline_command = r#"gh pr create --body "
This PR fixes /etc/config
And updates /var/log/app.log

See details in the description
""#;
    assert!(
        validate_path_safety(multiline_command, default_sandbox_dir()).is_ok(),
        "Multiline double-quoted string with paths should be allowed"
    );

    // Multiline single-quoted string
    let single_quote = r#"echo '
Line with /etc/passwd
Line with /home/user
'"#;
    assert!(
        validate_path_safety(single_quote, default_sandbox_dir()).is_ok(),
        "Multiline single-quoted string with paths should be allowed"
    );
}

#[test]
fn test_urls_allowed() {
    // HTTP URLs
    assert!(
        validate_path_safety(
            "curl http://example.com/api/v1/users",
            default_sandbox_dir()
        )
        .is_ok(),
        "HTTP URL should be allowed"
    );

    // HTTPS URLs
    assert!(
        validate_path_safety(
            "wget https://github.com/user/repo/file.txt",
            default_sandbox_dir()
        )
        .is_ok(),
        "HTTPS URL should be allowed"
    );

    // Git URLs
    assert!(
        validate_path_safety(
            "git clone git://example.com/repo.git",
            default_sandbox_dir()
        )
        .is_ok(),
        "Git URL should be allowed"
    );

    // URLs in quoted strings
    assert!(
        validate_path_safety(
            r#"gh pr create --body "See https://github.com/user/repo/issues/123""#,
            default_sandbox_dir()
        )
        .is_ok(),
        "Quoted URL should be allowed"
    );
}

#[test]
fn test_command_options_with_slashes_allowed() {
    // Options with equals sign and paths
    assert!(
        validate_path_safety("command --format=json/yaml", default_sandbox_dir()).is_ok(),
        "Command option with slash should be allowed"
    );

    assert!(
        validate_path_safety("tool --output=path/to/file", default_sandbox_dir()).is_ok(),
        "Command option with path-like value should be allowed"
    );
}

#[test]
fn test_absolute_paths_blocked() {
    let sandbox_dir = current_dir().unwrap();

    // Absolute paths should be blocked (quoted or not)
    assert!(
        validate_path_safety("cat /etc/passwd", &sandbox_dir).is_err(),
        "Absolute path should be blocked"
    );

    assert!(
        validate_path_safety("cat \"/etc/passwd\"", &sandbox_dir).is_err(),
        "Quoted absolute path should also be blocked"
    );

    assert!(
        validate_path_safety("ls /tmp/secret", &sandbox_dir).is_err(),
        "Absolute path to /tmp should be blocked"
    );
}

#[test]
fn test_multiline_with_paths_blocked() {
    let sandbox_dir = current_dir().unwrap();

    // Multiline commands with absolute paths
    let command = "echo something\ncat /etc/passwd";
    assert!(
        validate_path_safety(command, &sandbox_dir).is_err(),
        "Absolute path in multiline command should be blocked"
    );
}

#[test]
fn test_path_traversal_in_multiline_blocked() {
    // Path traversal that would escape sandbox should be blocked
    let sandbox_dir = current_dir().unwrap();
    let command = r#"echo "test"
cd ../../../../../etc"#;
    assert!(
        validate_path_safety(command, &sandbox_dir).is_err(),
        "Path traversal that escapes sandbox should be blocked"
    );
}

#[test]
fn test_github_cli_pr_scenarios() {
    // Real-world GitHub CLI scenarios that were causing false positives

    // PR with URL and path mentions
    assert!(
        validate_path_safety(
            r#"gh pr create --title "Fix bug" --body "See https://github.com/user/repo/issues/123 for /etc/config details""#,
            default_sandbox_dir()
        ).is_ok(),
        "GitHub PR with URL and path mentions should be allowed"
    );

    // PR with code snippets
    assert!(
        validate_path_safety(
            r#"gh issue comment 42 --body "The issue is in src/components/Header.tsx and /app/routes/index.ts""#,
            default_sandbox_dir()
        ).is_ok(),
        "GitHub issue comment with file paths should be allowed"
    );

    // PR with multiline body containing paths
    let pr_body = r#"gh pr create --title "Update config" --body "
Changed configuration files:
- /etc/nginx/nginx.conf
- /var/www/html/index.html

Tested on production server
""#;
    assert!(
        validate_path_safety(pr_body, default_sandbox_dir()).is_ok(),
        "GitHub PR with multiline body containing paths should be allowed"
    );
}

// New tests for context-aware path traversal validation

#[test]
fn test_path_traversal_within_sandbox_allowed() {
    // IMPORTANT: The sandbox_dir is the ROOT of the sandbox, not the CWD!
    // Commands execute FROM the sandbox root by default
    // So cd ../ from the sandbox root would ESCAPE - that should be blocked!

    // This test needs to simulate being in a subdirectory of the sandbox
    // But since we only validate against the sandbox root, ANY ../ will escape
    // Unless we're checking paths that stay within the sandbox even after resolution

    let sandbox_dir = current_dir().unwrap();

    // Paths that reference subdirectories using ../ but stay in sandbox
    // Example: sandbox/a/../b/file.txt => sandbox/b/file.txt (stays in sandbox)
    assert!(
        validate_path_safety("cat subdir/../file.txt", &sandbox_dir).is_ok(),
        "Path with ../ that resolves within sandbox should be allowed"
    );

    // Nested traversal that stays in sandbox
    assert!(
        validate_path_safety("ls ./a/b/../../c/file.txt", &sandbox_dir).is_ok(),
        "Complex path with multiple ../ that stays in sandbox should be allowed"
    );
}

#[test]
fn test_path_traversal_escape_sandbox_blocked() {
    let sandbox_dir = current_dir().unwrap();

    // Try to escape the sandbox by going too many levels up
    // This should be blocked
    let too_many_levels = "../".repeat(20); // Way more than needed
    let command = format!("cat {}etc/passwd", too_many_levels);

    assert!(
        validate_path_safety(&command, &sandbox_dir).is_err(),
        "Path traversal escaping sandbox should be blocked"
    );
}

#[test]
fn test_mixed_paths_with_traversal() {
    let sandbox_dir = current_dir().unwrap();

    // Relative path with ./ and ../ that stays in sandbox
    // ./subdir/../file.txt resolves to ./file.txt (sandbox root)
    assert!(
        validate_path_safety("ls subdir/../file.txt", &sandbox_dir).is_ok(),
        "Path with ../ that resolves to sandbox should be allowed"
    );

    // Path with multiple .. components that stays in sandbox
    // ./a/b/../../c/file.txt resolves to ./c/file.txt
    assert!(
        validate_path_safety("cat a/b/../../c/file.txt", &sandbox_dir).is_ok(),
        "Complex path with multiple traversals should be allowed if stays in sandbox"
    );
}

#[test]
fn test_relative_paths_allowed() {
    assert!(validate_path_safety("ls ./foo-bar", default_sandbox_dir()).is_ok());
    assert!(validate_path_safety("cat ./foo/bar", default_sandbox_dir()).is_ok());
    assert!(validate_path_safety("cat foo/bar.txt", default_sandbox_dir()).is_ok());
    assert!(validate_path_safety("echo hello", default_sandbox_dir()).is_ok());
}

#[test]
fn test_absolute_paths_in_sandbox_allowed() {
    // Use the current directory as sandbox for testing (it definitely exists)
    let sandbox_dir = current_dir().unwrap();
    let sandbox_subdir = sandbox_dir.join("subdir");
    // This should be allowed as it's within the sandbox
    assert!(
        validate_path_safety(&format!("ls {}", sandbox_subdir.display()), &sandbox_dir).is_ok()
    );
}

#[test]
fn test_absolute_paths_outside_sandbox_blocked() {
    // Use the current directory as sandbox for testing (it definitely exists)
    let sandbox_dir = current_dir().unwrap();
    // These should be blocked as they escape the sandbox
    assert!(validate_path_safety("ls /etc/passwd", &sandbox_dir).is_err());
    assert!(validate_path_safety("cat /tmp/other", &sandbox_dir).is_err());
}

#[test]
fn test_home_directory_paths_within_sandbox_allowed() {
    // Use the current directory as sandbox (it definitely exists)
    let sandbox_dir = current_dir().unwrap();

    if let Ok(home_dir) = std::env::var("HOME") {
        let home_path = Path::new(&home_dir);

        // Only test if sandbox is within home directory
        if sandbox_dir.starts_with(home_path) {
            // Get the relative path from home to sandbox
            let relative = sandbox_dir.strip_prefix(home_path).unwrap();
            let home_prefix_path = format!("~/{}", relative.display());

            // Commands with home directory paths within the sandbox should be allowed
            let test_path = format!("ls {}/file.txt", home_prefix_path);
            assert!(
                validate_path_safety(&test_path, &sandbox_dir).is_ok(),
                "Home directory path within sandbox should be allowed"
            );

            let test_path2 = format!("cat {}/subdir/data.txt", home_prefix_path);
            assert!(
                validate_path_safety(&test_path2, &sandbox_dir).is_ok(),
                "Home directory subpath within sandbox should be allowed"
            );
        }
    }
}

#[test]
fn test_home_directory_paths_outside_sandbox_blocked() {
    // Use the current directory as sandbox (it definitely exists)
    let sandbox_dir = current_dir().unwrap();

    if let Ok(home_dir) = std::env::var("HOME") {
        let home_path = Path::new(&home_dir);

        // Test paths that are definitely outside the sandbox
        // These should be blocked regardless of where sandbox is
        let test_path = format!("ls ~/.bashrc");
        let result = validate_path_safety(&test_path, &sandbox_dir);

        // Only assert if the file exists (so we can properly test)
        let bashrc_path = home_path.join(".bashrc");
        if bashrc_path.exists() {
            assert!(
                result.is_err(),
                "Home directory path to config files should be blocked"
            );
        }

        // Test with a path that definitely doesn't match sandbox
        let test_path2 = format!("cat ~/definitely_outside_sandbox_xyz123/file.txt");
        assert!(
            validate_path_safety(&test_path2, &sandbox_dir).is_err(),
            "Home directory path outside sandbox should be blocked"
        );
    }
}

#[test]
fn test_home_directory_paths_with_current_dir_sandbox() {
    // Use current directory as sandbox (not in home directory)
    let sandbox_dir = std::env::current_dir().unwrap();

    // If sandbox is not in home directory, all home directory paths should be blocked
    if let Ok(home_dir) = std::env::var("HOME") {
        let home_path = Path::new(&home_dir);
        if !sandbox_dir.starts_with(home_path) {
            assert!(
                validate_path_safety("ls ~/file.txt", &sandbox_dir).is_err(),
                "Home directory paths should be blocked when sandbox is outside home"
            );
        }
    }
}

#[test]
fn test_tilde_alone_blocked_when_outside_sandbox() {
    // Use current directory as sandbox
    let sandbox_dir = std::env::current_dir().unwrap();

    // If sandbox is not in home directory, ~ alone should be blocked
    if let Ok(home_dir) = std::env::var("HOME") {
        let home_path = Path::new(&home_dir);
        if !sandbox_dir.starts_with(home_path) {
            assert!(
                validate_path_safety("ls ~", &sandbox_dir).is_err(),
                "Tilde alone should be blocked when home is outside sandbox"
            );
            assert!(
                validate_path_safety("cd ~", &sandbox_dir).is_err(),
                "Tilde alone in cd command should be blocked"
            );
        }
    }
}

#[test]
fn test_tilde_alone_allowed_when_within_sandbox() {
    // Use current directory as sandbox
    let sandbox_dir = std::env::current_dir().unwrap();

    // If sandbox is in home directory, ~ alone should be allowed only if it points to sandbox or subdirectory
    if let Ok(home_dir) = std::env::var("HOME") {
        let home_path = Path::new(&home_dir);
        if sandbox_dir == home_path {
            assert!(
                validate_path_safety("ls ~", &sandbox_dir).is_ok(),
                "Tilde alone should be allowed when sandbox is home directory itself"
            );
        }
    }
}

// Tests for whitelist-based safe command patterns

#[test]
fn test_github_api_commands_whitelisted() {
    let sandbox_dir = current_dir().unwrap();

    // GitHub API commands should be whitelisted (bypass path validation)
    assert!(
        validate_path_safety("gh api /repos/owner/repo/contents/file.yml", &sandbox_dir).is_ok(),
        "gh api with API endpoint should be whitelisted"
    );

    assert!(
        validate_path_safety(
            "gh api repos/owner/repo/contents/file.yml | from json",
            &sandbox_dir
        )
        .is_ok(),
        "gh api without leading slash should be whitelisted"
    );

    assert!(
        validate_path_safety(
            "gh api /repos/owner/repo/contents/file.yml | from json | get content | decode base64",
            &sandbox_dir
        )
        .is_ok(),
        "gh api with full pipeline should be whitelisted"
    );
}

#[test]
fn test_kubectl_api_commands_whitelisted() {
    let sandbox_dir = current_dir().unwrap();

    // kubectl with API resource paths should be whitelisted
    assert!(
        validate_path_safety("kubectl get /apis/apps/v1/deployments", &sandbox_dir).is_ok(),
        "kubectl get with /apis path should be whitelisted"
    );

    assert!(
        validate_path_safety("kubectl describe /api/v1/pods", &sandbox_dir).is_ok(),
        "kubectl describe with /api path should be whitelisted"
    );

    assert!(
        validate_path_safety("kubectl delete /apis/batch/v1/jobs/myjob", &sandbox_dir).is_ok(),
        "kubectl delete with API path should be whitelisted"
    );
}

#[test]
fn test_argocd_commands_whitelisted() {
    let sandbox_dir = current_dir().unwrap();

    // argocd app commands with /argocd/ paths should be whitelisted
    assert!(
        validate_path_safety("argocd app get /argocd/myapp", &sandbox_dir).is_ok(),
        "argocd app get with /argocd path should be whitelisted"
    );

    assert!(
        validate_path_safety("argocd app sync /argocd/production/app", &sandbox_dir).is_ok(),
        "argocd app sync with /argocd path should be whitelisted"
    );
}

#[test]
fn test_http_commands_whitelisted() {
    let sandbox_dir = current_dir().unwrap();

    // HTTP client commands with URLs should be whitelisted
    assert!(
        validate_path_safety("curl https://api.github.com/repos/owner/repo", &sandbox_dir).is_ok(),
        "curl with URL should be whitelisted"
    );

    assert!(
        validate_path_safety("wget http://example.com/file.txt", &sandbox_dir).is_ok(),
        "wget with URL should be whitelisted"
    );

    assert!(
        validate_path_safety("http get https://api.example.com/data", &sandbox_dir).is_ok(),
        "http get with URL should be whitelisted"
    );

    assert!(
        validate_path_safety("http post https://api.example.com/submit", &sandbox_dir).is_ok(),
        "http post with URL should be whitelisted"
    );
}

#[test]
fn test_non_whitelisted_commands_still_validated() {
    let sandbox_dir = current_dir().unwrap();

    // Regular commands should still undergo path validation
    assert!(
        validate_path_safety("cat /etc/passwd", &sandbox_dir).is_err(),
        "cat with absolute path outside sandbox should be blocked"
    );

    assert!(
        validate_path_safety("ls /tmp/secret", &sandbox_dir).is_err(),
        "ls with absolute path outside sandbox should be blocked"
    );

    // gh commands that DON'T match the pattern should still be validated
    assert!(
        validate_path_safety("gh repo clone /some/path", &sandbox_dir).is_err(),
        "gh repo (not 'gh api') should still validate paths"
    );
}

#[test]
fn test_whitelist_pattern_specificity() {
    let sandbox_dir = current_dir().unwrap();

    // Patterns should be specific to avoid over-matching
    // kubectl without /api prefix should still validate paths
    assert!(
        validate_path_safety("kubectl get pods", &sandbox_dir).is_ok(),
        "kubectl get pods (no paths) should be allowed"
    );

    // But if it has an absolute non-API path, should be blocked
    assert!(
        validate_path_safety("kubectl apply -f /etc/config.yaml", &sandbox_dir).is_err(),
        "kubectl with filesystem path outside sandbox should be blocked"
    );
}
