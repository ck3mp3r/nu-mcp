use super::validate_path_safety;
use std::path::{Path, PathBuf};

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
fn test_semicolon_in_sandbox_path() {
    // Verifies that semicolons as command separators are handled correctly
    let sandbox_dir = PathBuf::from("/Users/christian/Projects/ck3mp3r/nu-mcp");
    let command = "cd /Users/christian/Projects/ck3mp3r/nu-mcp; cargo test";

    let result = validate_path_safety(command, &[sandbox_dir]);
    assert!(
        result.is_ok(),
        "Path with semicolon separator in sandbox should be allowed: {:?}",
        result
    );
}

#[cfg(test)]
mod cache_tests {
    use super::*;
    use crate::security::PathCache;
    use std::env::current_dir;

    // Helper to create cache and validate with it
    fn validate_with_cache(
        command: &str,
        sandbox_dirs: &[PathBuf],
        cache: &mut PathCache,
    ) -> Result<(), String> {
        crate::security::validate_path_safety_with_cache(command, sandbox_dirs, cache)
    }

    #[test]
    fn test_cache_api_endpoint_non_existent() {
        // RED: This test will fail because PathCache doesn't exist yet
        let sandbox_dir = current_dir().unwrap();
        let mut cache = PathCache::new();

        // First call - /metrics doesn't exist, should be cached
        let result = validate_with_cache(
            "kubectl get --raw /metrics",
            &[sandbox_dir.clone()],
            &mut cache,
        );
        assert!(
            result.is_ok(),
            "First call to non-existent API endpoint should be allowed"
        );

        // Verify /metrics was cached
        assert!(
            cache.contains("/metrics"),
            "Non-existent path /metrics should be cached"
        );

        // Second call - should hit cache (no validation)
        let result = validate_with_cache("kubectl get --raw /metrics", &[sandbox_dir], &mut cache);
        assert!(result.is_ok(), "Second call should be allowed via cache");
    }

    #[test]
    fn test_cache_multiple_api_endpoints() {
        // RED: Will fail - PathCache doesn't exist
        let sandbox_dir = current_dir().unwrap();
        let mut cache = PathCache::new();

        // Call multiple API endpoints
        let endpoints = vec!["/metrics", "/healthz", "/api/v1/pods"];

        for endpoint in &endpoints {
            let command = format!("kubectl get --raw {}", endpoint);
            let result = validate_with_cache(&command, &[sandbox_dir.clone()], &mut cache);
            assert!(
                result.is_ok(),
                "API endpoint {} should be allowed",
                endpoint
            );
        }

        // Verify all were cached
        for endpoint in endpoints {
            assert!(
                cache.contains(endpoint),
                "Endpoint {} should be cached",
                endpoint
            );
        }
    }

    #[test]
    fn test_cache_does_not_cache_existing_files() {
        // RED: Will fail - PathCache doesn't exist
        let sandbox_dir = current_dir().unwrap();
        let mut cache = PathCache::new();

        // Try to access an existing file outside sandbox (should be blocked)
        let result = validate_with_cache("cat /etc/passwd", &[sandbox_dir], &mut cache);
        assert!(
            result.is_err(),
            "Existing file outside sandbox should be blocked"
        );

        // Verify /etc/passwd was NOT cached (it exists)
        assert!(
            !cache.contains("/etc/passwd"),
            "Existing file should NOT be cached"
        );
    }

    #[test]
    fn test_cache_does_not_cache_sandbox_paths() {
        // RED: Will fail - PathCache doesn't exist
        let sandbox_dir = current_dir().unwrap();
        let mut cache = PathCache::new();

        // Create a path within sandbox
        let sandbox_path = sandbox_dir.join("test_file.txt");
        let command = format!("cat {}", sandbox_path.display());

        let result = validate_with_cache(&command, &[sandbox_dir.clone()], &mut cache);
        assert!(result.is_ok(), "Path within sandbox should be allowed");

        // Verify sandbox path was NOT cached (it's in sandbox, handled by sandbox check)
        let path_str = sandbox_path.display().to_string();
        assert!(
            !cache.contains(&path_str),
            "Sandbox path should NOT be cached"
        );
    }

    #[test]
    fn test_cache_persists_across_commands() {
        // RED: Will fail - PathCache doesn't exist
        let sandbox_dir = current_dir().unwrap();
        let mut cache = PathCache::new();

        // First command with /metrics
        validate_with_cache(
            "kubectl get --raw /metrics",
            &[sandbox_dir.clone()],
            &mut cache,
        )
        .expect("First call should succeed");

        // Different command, same path
        validate_with_cache(
            "curl http://localhost:8080/metrics",
            &[sandbox_dir.clone()],
            &mut cache,
        )
        .expect("Second call with cached path should succeed");

        // Third command, different path
        validate_with_cache(
            "kubectl get --raw /healthz",
            &[sandbox_dir.clone()],
            &mut cache,
        )
        .expect("Third call with new path should succeed");

        // Verify both paths are cached
        assert!(cache.contains("/metrics"), "/metrics should be cached");
        assert!(cache.contains("/healthz"), "/healthz should be cached");
    }

    #[test]
    fn test_cache_allows_typos_of_critical_paths() {
        // RED: Will fail - PathCache doesn't exist
        let sandbox_dir = current_dir().unwrap();
        let mut cache = PathCache::new();

        // Typo: /ect instead of /etc (doesn't exist)
        let result = validate_with_cache("cat /ect/passwd", &[sandbox_dir], &mut cache);
        assert!(result.is_ok(), "Non-existent typo path should be allowed");

        // Verify typo was cached
        assert!(
            cache.contains("/ect/passwd"),
            "Typo path should be cached as non-filesystem"
        );
    }

    #[test]
    fn test_cache_short_circuits_validation() {
        // RED: Will fail - PathCache doesn't exist
        let sandbox_dir = current_dir().unwrap();
        let mut cache = PathCache::new();

        // First call - validates and caches
        validate_with_cache("api-tool /api/endpoint", &[sandbox_dir.clone()], &mut cache)
            .expect("First call should succeed");

        // Manually add to cache to verify short-circuit
        cache.remember("/api/endpoint".to_string());

        // Second call - should short-circuit immediately (no path resolution)
        let result =
            validate_with_cache("different-tool /api/endpoint", &[sandbox_dir], &mut cache);
        assert!(
            result.is_ok(),
            "Cached path should short-circuit validation"
        );
    }

    #[test]
    fn test_cache_empty_initially() {
        // RED: Will fail - PathCache doesn't exist
        let cache = PathCache::new();
        assert!(cache.is_empty(), "New cache should be empty");
    }

    #[test]
    fn test_cache_size_grows_with_unique_paths() {
        // RED: Will fail - PathCache doesn't exist
        let sandbox_dir = current_dir().unwrap();
        let mut cache = PathCache::new();

        assert_eq!(cache.len(), 0, "Cache should start empty");

        // Add first path
        validate_with_cache("tool /path1", &[sandbox_dir.clone()], &mut cache).ok();
        assert_eq!(cache.len(), 1, "Cache should have 1 entry");

        // Add second path
        validate_with_cache("tool /path2", &[sandbox_dir.clone()], &mut cache).ok();
        assert_eq!(cache.len(), 2, "Cache should have 2 entries");

        // Same path again - size shouldn't change
        validate_with_cache("tool /path1", &[sandbox_dir], &mut cache).ok();
        assert_eq!(cache.len(), 2, "Cache size should not change for duplicate");
    }
}
