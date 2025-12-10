use super::validate_path_safety;
use std::{
    env::current_dir,
    path::{Path, PathBuf},
    slice::from_ref,
};

fn default_sandbox_dir() -> &'static Path {
    Path::new("/tmp/test_sandbox")
}

// Helper function for tests - wraps sandbox_dir in a Vec
fn validate_path_safety_test(command: &str, sandbox_dir: &Path) -> Result<(), String> {
    validate_path_safety(command, &[sandbox_dir.to_path_buf()])
}

// NOTE: Quote-based tests removed because quotes don't prevent filesystem access!
// cat "/etc/passwd" will still read the file even though it's quoted.
// The allowlist approach handles specific safe patterns instead.

#[test]
fn test_string_interpolation_with_paths_allowed() {
    // String interpolation with double quotes
    assert!(
        validate_path_safety_test(r#"echo $"Config at /etc/app.conf""#, default_sandbox_dir())
            .is_ok(),
        "String interpolation with path should be allowed"
    );

    // String interpolation with single quotes
    assert!(
        validate_path_safety_test(
            r#"echo $'Log file: /var/log/app.log'"#,
            default_sandbox_dir()
        )
        .is_ok(),
        "String interpolation with single quotes should be allowed"
    );

    // String interpolation with single quotes
    assert!(
        validate_path_safety_test(
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
        validate_path_safety_test(multiline_command, default_sandbox_dir()).is_ok(),
        "Multiline double-quoted string with paths should be allowed"
    );

    // Multiline single-quoted string
    let single_quote = r#"echo '
Line with /etc/passwd
Line with /home/user
'"#;
    assert!(
        validate_path_safety_test(single_quote, default_sandbox_dir()).is_ok(),
        "Multiline single-quoted string with paths should be allowed"
    );
}

#[test]
fn test_urls_allowed() {
    // HTTP URLs
    assert!(
        validate_path_safety_test(
            "curl http://example.com/api/v1/users",
            default_sandbox_dir()
        )
        .is_ok(),
        "HTTP URL should be allowed"
    );

    // HTTPS URLs
    assert!(
        validate_path_safety_test(
            "wget https://github.com/user/repo/file.txt",
            default_sandbox_dir()
        )
        .is_ok(),
        "HTTPS URL should be allowed"
    );

    // Git URLs
    assert!(
        validate_path_safety_test(
            "git clone git://example.com/repo.git",
            default_sandbox_dir()
        )
        .is_ok(),
        "Git URL should be allowed"
    );

    // URLs in quoted strings
    assert!(
        validate_path_safety_test(
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
        validate_path_safety_test("command --format=json/yaml", default_sandbox_dir()).is_ok(),
        "Command option with slash should be allowed"
    );

    assert!(
        validate_path_safety_test("tool --output=path/to/file", default_sandbox_dir()).is_ok(),
        "Command option with path-like value should be allowed"
    );
}

#[test]
fn test_absolute_paths_blocked() {
    let sandbox_dir = current_dir().unwrap();

    // Absolute paths should be blocked (quoted or not)
    assert!(
        validate_path_safety_test("cat /etc/passwd", &sandbox_dir).is_err(),
        "Absolute path should be blocked"
    );

    assert!(
        validate_path_safety_test("cat \"/etc/passwd\"", &sandbox_dir).is_err(),
        "Quoted absolute path should also be blocked"
    );

    assert!(
        validate_path_safety_test("ls /tmp/secret", &sandbox_dir).is_err(),
        "Absolute path to /tmp should be blocked"
    );
}

#[test]
fn test_multiline_with_paths_blocked() {
    let sandbox_dir = current_dir().unwrap();

    // Multiline commands with absolute paths
    let command = "echo something\ncat /etc/passwd";
    assert!(
        validate_path_safety_test(command, &sandbox_dir).is_err(),
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
        validate_path_safety_test(command, &sandbox_dir).is_err(),
        "Path traversal that escapes sandbox should be blocked"
    );
}

#[test]
fn test_github_cli_pr_scenarios() {
    // Real-world GitHub CLI scenarios that were causing false positives

    // PR with URL and path mentions
    assert!(
        validate_path_safety_test(
            r#"gh pr create --title "Fix bug" --body "See https://github.com/user/repo/issues/123 for /etc/config details""#,
            default_sandbox_dir()
        ).is_ok(),
        "GitHub PR with URL and path mentions should be allowed"
    );

    // PR with code snippets
    assert!(
        validate_path_safety_test(
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
        validate_path_safety_test(pr_body, default_sandbox_dir()).is_ok(),
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
        validate_path_safety_test("cat subdir/../file.txt", &sandbox_dir).is_ok(),
        "Path with ../ that resolves within sandbox should be allowed"
    );

    // Nested traversal that stays in sandbox
    assert!(
        validate_path_safety_test("ls ./a/b/../../c/file.txt", &sandbox_dir).is_ok(),
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
        validate_path_safety_test(&command, &sandbox_dir).is_err(),
        "Path traversal escaping sandbox should be blocked"
    );
}

#[test]
fn test_mixed_paths_with_traversal() {
    let sandbox_dir = current_dir().unwrap();

    // Relative path with ./ and ../ that stays in sandbox
    // ./subdir/../file.txt resolves to ./file.txt (sandbox root)
    assert!(
        validate_path_safety_test("ls subdir/../file.txt", &sandbox_dir).is_ok(),
        "Path with ../ that resolves to sandbox should be allowed"
    );

    // Path with multiple .. components that stays in sandbox
    // ./a/b/../../c/file.txt resolves to ./c/file.txt
    assert!(
        validate_path_safety_test("cat a/b/../../c/file.txt", &sandbox_dir).is_ok(),
        "Complex path with multiple traversals should be allowed if stays in sandbox"
    );
}

#[test]
fn test_relative_paths_allowed() {
    assert!(validate_path_safety_test("ls ./foo-bar", default_sandbox_dir()).is_ok());
    assert!(validate_path_safety_test("cat ./foo/bar", default_sandbox_dir()).is_ok());
    assert!(validate_path_safety_test("cat foo/bar.txt", default_sandbox_dir()).is_ok());
    assert!(validate_path_safety_test("echo hello", default_sandbox_dir()).is_ok());
}

#[test]
fn test_absolute_paths_in_sandbox_allowed() {
    // Use the current directory as sandbox for testing (it definitely exists)
    let sandbox_dir = current_dir().unwrap();
    let sandbox_subdir = sandbox_dir.join("subdir");
    // This should be allowed as it's within the sandbox
    assert!(
        validate_path_safety_test(&format!("ls {}", sandbox_subdir.display()), &sandbox_dir)
            .is_ok()
    );
}

#[test]
fn test_absolute_paths_outside_sandbox_blocked() {
    // Use the current directory as sandbox for testing (it definitely exists)
    let sandbox_dir = current_dir().unwrap();
    // These should be blocked as they escape the sandbox
    assert!(validate_path_safety_test("ls /etc/passwd", &sandbox_dir).is_err());
    assert!(validate_path_safety_test("cat /tmp/other", &sandbox_dir).is_err());
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
                validate_path_safety_test(&test_path, &sandbox_dir).is_ok(),
                "Home directory path within sandbox should be allowed"
            );

            let test_path2 = format!("cat {}/subdir/data.txt", home_prefix_path);
            assert!(
                validate_path_safety_test(&test_path2, &sandbox_dir).is_ok(),
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
        let test_path = "ls ~/.bashrc".to_string();
        let result = validate_path_safety_test(&test_path, &sandbox_dir);

        // Only assert if the file exists (so we can properly test)
        let bashrc_path = home_path.join(".bashrc");
        if bashrc_path.exists() {
            assert!(
                result.is_err(),
                "Home directory path to config files should be blocked"
            );
        }

        // Test with a path that definitely doesn't match sandbox
        let test_path2 = "cat ~/definitely_outside_sandbox_xyz123/file.txt".to_string();
        assert!(
            validate_path_safety_test(&test_path2, &sandbox_dir).is_err(),
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
                validate_path_safety_test("ls ~/file.txt", &sandbox_dir).is_err(),
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
                validate_path_safety_test("ls ~", &sandbox_dir).is_err(),
                "Tilde alone should be blocked when home is outside sandbox"
            );
            assert!(
                validate_path_safety_test("cd ~", &sandbox_dir).is_err(),
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
                validate_path_safety_test("ls ~", &sandbox_dir).is_ok(),
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
        validate_path_safety_test("gh api /repos/owner/repo/contents/file.yml", &sandbox_dir)
            .is_ok(),
        "gh api with API endpoint should be whitelisted"
    );

    assert!(
        validate_path_safety_test(
            "gh api repos/owner/repo/contents/file.yml | from json",
            &sandbox_dir
        )
        .is_ok(),
        "gh api without leading slash should be whitelisted"
    );

    assert!(
        validate_path_safety_test(
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
        validate_path_safety_test("kubectl get /apis/apps/v1/deployments", &sandbox_dir).is_ok(),
        "kubectl get with /apis path should be whitelisted"
    );

    assert!(
        validate_path_safety_test("kubectl describe /api/v1/pods", &sandbox_dir).is_ok(),
        "kubectl describe with /api path should be whitelisted"
    );

    assert!(
        validate_path_safety_test("kubectl delete /apis/batch/v1/jobs/myjob", &sandbox_dir).is_ok(),
        "kubectl delete with API path should be whitelisted"
    );
}

#[test]
fn test_argocd_commands_whitelisted() {
    let sandbox_dir = current_dir().unwrap();

    // argocd app commands with /argocd/ paths should be whitelisted
    assert!(
        validate_path_safety_test("argocd app get /argocd/myapp", &sandbox_dir).is_ok(),
        "argocd app get with /argocd path should be whitelisted"
    );

    assert!(
        validate_path_safety_test("argocd app sync /argocd/production/app", &sandbox_dir).is_ok(),
        "argocd app sync with /argocd path should be whitelisted"
    );
}

#[test]
fn test_http_commands_whitelisted() {
    let sandbox_dir = current_dir().unwrap();

    // HTTP client commands with URLs should be whitelisted
    assert!(
        validate_path_safety_test("curl https://api.github.com/repos/owner/repo", &sandbox_dir)
            .is_ok(),
        "curl with URL should be whitelisted"
    );

    assert!(
        validate_path_safety_test("wget http://example.com/file.txt", &sandbox_dir).is_ok(),
        "wget with URL should be whitelisted"
    );

    assert!(
        validate_path_safety_test("http get https://api.example.com/data", &sandbox_dir).is_ok(),
        "http get with URL should be whitelisted"
    );

    assert!(
        validate_path_safety_test("http post https://api.example.com/submit", &sandbox_dir).is_ok(),
        "http post with URL should be whitelisted"
    );
}

#[test]
fn test_non_whitelisted_commands_still_validated() {
    let sandbox_dir = current_dir().unwrap();

    // Regular commands should still undergo path validation
    assert!(
        validate_path_safety_test("cat /etc/passwd", &sandbox_dir).is_err(),
        "cat with absolute path outside sandbox should be blocked"
    );

    assert!(
        validate_path_safety_test("ls /tmp/secret", &sandbox_dir).is_err(),
        "ls with absolute path outside sandbox should be blocked"
    );

    // gh commands that DON'T match the pattern should still be validated
    assert!(
        validate_path_safety_test("gh repo clone /some/path", &sandbox_dir).is_err(),
        "gh repo (not 'gh api') should still validate paths"
    );
}

#[test]
fn test_whitelist_pattern_specificity() {
    let sandbox_dir = current_dir().unwrap();

    // Patterns should be specific to avoid over-matching
    // kubectl without /api prefix should still validate paths
    assert!(
        validate_path_safety_test("kubectl get pods", &sandbox_dir).is_ok(),
        "kubectl get pods (no paths) should be allowed"
    );

    // But if it has an absolute non-API path, should be blocked
    assert!(
        validate_path_safety_test("kubectl apply -f /etc/config.yaml", &sandbox_dir).is_err(),
        "kubectl with filesystem path outside sandbox should be blocked"
    );
}

// Tests for multiple sandbox directories

#[test]
fn test_multiple_sandbox_directories() {
    let sandbox1 = current_dir().unwrap();
    let sandbox2 = sandbox1.parent().unwrap().to_path_buf();

    // Path in first sandbox
    let path1 = format!("cat {}/file1.txt", sandbox1.display());
    assert!(
        validate_path_safety(&path1, &[sandbox1.clone(), sandbox2.clone()]).is_ok(),
        "Path in first sandbox should be allowed"
    );

    // Path in second sandbox
    let path2 = format!("cat {}/file2.txt", sandbox2.display());
    assert!(
        validate_path_safety(&path2, &[sandbox1, sandbox2]).is_ok(),
        "Path in second sandbox should be allowed"
    );
}

#[test]
fn test_path_outside_all_sandboxes_blocked() {
    let sandbox1 = current_dir().unwrap();
    let sandbox2 = sandbox1.parent().unwrap().to_path_buf();

    // Path outside both sandboxes
    assert!(
        validate_path_safety("cat /etc/passwd", &[sandbox1, sandbox2]).is_err(),
        "Path outside all sandboxes should be blocked"
    );
}

#[test]
fn test_nonexistent_sandbox_ignored() {
    let sandbox1 = current_dir().unwrap();
    let nonexistent_sandbox = PathBuf::from("/nonexistent/sandbox");

    // If a sandbox doesn't exist, it's ignored (canonicalization fails)
    // Path in existing sandbox should still work
    let path = format!("cat {}/file.txt", sandbox1.display());
    assert!(
        validate_path_safety(&path, &[sandbox1, nonexistent_sandbox]).is_ok(),
        "Path in existing sandbox should be allowed even if another sandbox doesn't exist"
    );
}

#[test]
fn test_absolute_path_to_sandbox_subdir_allowed() {
    let sandbox_dir = current_dir().unwrap();

    // Create an absolute path to a subdirectory of the sandbox
    let absolute_subdir = sandbox_dir.join("src").join("lib.rs");
    let command = format!("cat {}", absolute_subdir.display());

    println!("Testing command: {}", command);
    println!("Sandbox dir: {}", sandbox_dir.display());
    println!("Absolute path: {}", absolute_subdir.display());

    // This should be allowed since the absolute path is within the sandbox
    assert!(
        validate_path_safety(&command, &[sandbox_dir]).is_ok(),
        "Absolute path within sandbox should be allowed"
    );
}

#[test]
fn test_absolute_path_to_nonexistent_file_in_sandbox() {
    let sandbox_dir = current_dir().unwrap();

    // Create an absolute path to a non-existent file within sandbox
    let absolute_path = sandbox_dir.join("nonexistent.txt");
    let command = format!("touch {}", absolute_path.display());

    println!("Testing command: {}", command);
    println!("Sandbox dir: {}", sandbox_dir.display());
    println!("Absolute path: {}", absolute_path.display());

    // This should be allowed since the absolute path (even though file doesn't exist) is within sandbox
    assert!(
        validate_path_safety(&command, &[sandbox_dir]).is_ok(),
        "Absolute path to non-existent file within sandbox should be allowed"
    );
}

#[test]
fn test_debug_absolute_path_validation() {
    let sandbox_dir = current_dir().unwrap();
    let canonical_sandbox = sandbox_dir.canonicalize().unwrap();

    // Test an absolute path that's definitely within sandbox
    let test_file = sandbox_dir.join("Cargo.toml");
    let command = format!("cat {}", test_file.display());

    println!("\n=== Debug Info ===");
    println!("Command: {}", command);
    println!("Sandbox dir: {}", sandbox_dir.display());
    println!("Canonical sandbox: {}", canonical_sandbox.display());
    println!("Test file: {}", test_file.display());
    println!("Test file canonical: {:?}", test_file.canonicalize());
    println!(
        "Test file starts_with sandbox: {}",
        test_file.starts_with(&sandbox_dir)
    );
    if let Ok(canonical_test) = test_file.canonicalize() {
        println!(
            "Canonical test starts_with canonical sandbox: {}",
            canonical_test.starts_with(&canonical_sandbox)
        );
    }

    let result = validate_path_safety(&command, from_ref(&sandbox_dir));
    println!("Validation result: {:?}", result);
    println!("==================\n");

    assert!(
        result.is_ok(),
        "Absolute path to existing file in sandbox should be allowed"
    );
}

#[test]
fn test_shell_metacharacters_stripped() {
    let sandbox_dir = current_dir().unwrap();

    // Test semicolon
    let result =
        validate_path_safety_test(&format!("cd {}; ls", sandbox_dir.display()), &sandbox_dir);
    assert!(
        result.is_ok(),
        "Path with trailing semicolon should be stripped and allowed: {:?}",
        result
    );

    // Test ampersand
    let result =
        validate_path_safety_test(&format!("cd {} & ls", sandbox_dir.display()), &sandbox_dir);
    assert!(
        result.is_ok(),
        "Path with trailing ampersand should be stripped and allowed: {:?}",
        result
    );

    // Test pipe
    let result =
        validate_path_safety_test(&format!("cd {} | ls", sandbox_dir.display()), &sandbox_dir);
    assert!(
        result.is_ok(),
        "Path with trailing pipe should be stripped and allowed: {:?}",
        result
    );

    // Test redirect
    let result = validate_path_safety_test(
        &format!("cd {} > output.txt", sandbox_dir.display()),
        &sandbox_dir,
    );
    assert!(
        result.is_ok(),
        "Path with trailing redirect should be stripped and allowed: {:?}",
        result
    );
}
