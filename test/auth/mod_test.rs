use super::{parse_env_credentials, run_credential_phase};
use crate::config::Config;
use nono::CapabilitySet;
use std::path::{Path, PathBuf};

type Result<T> = core::result::Result<T, Box<dyn std::error::Error>>;

// region:    --- Parse

#[test]
fn test_auth_parse_env_credentials_file_uri_maps_pair() -> Result<()> {
    // -- Setup & Fixtures
    let values = vec!["file:///run/secrets/api-token=MY_API_KEY".to_string()];

    // -- Exec
    let pairs = parse_env_credentials(&values)?;

    // -- Check
    assert_eq!(
        pairs,
        vec![(
            "file:///run/secrets/api-token".to_string(),
            "MY_API_KEY".to_string()
        )]
    );
    Ok(())
}

#[test]
fn test_auth_parse_env_credentials_last_equals_wins() -> Result<()> {
    // -- Setup & Fixtures
    let values = vec!["file:///a=b.txt=X".to_string()];

    // -- Exec
    let pairs = parse_env_credentials(&values)?;

    // -- Check
    assert_eq!(
        pairs,
        vec![("file:///a=b.txt".to_string(), "X".to_string())]
    );
    Ok(())
}

#[test]
fn test_auth_parse_env_credentials_trims_value_and_halves() -> Result<()> {
    // -- Setup & Fixtures
    let values = vec!["  env://SRC_TOKEN = TARGET_TOKEN  ".to_string()];

    // -- Exec
    let pairs = parse_env_credentials(&values)?;

    // -- Check
    assert_eq!(
        pairs,
        vec![("env://SRC_TOKEN".to_string(), "TARGET_TOKEN".to_string())]
    );
    Ok(())
}

#[test]
fn test_auth_parse_env_credentials_empty_input_returns_empty() -> Result<()> {
    // -- Setup & Fixtures
    let values: Vec<String> = vec![];

    // -- Exec
    let pairs = parse_env_credentials(&values)?;

    // -- Check
    assert!(pairs.is_empty(), "no values should produce no pairs");
    Ok(())
}

#[test]
fn test_auth_parse_env_credentials_missing_equals_errors() -> Result<()> {
    // -- Setup & Fixtures
    let values = vec!["file:///run/secrets/api-token".to_string()];

    // -- Exec
    let err = parse_env_credentials(&values)
        .err()
        .ok_or("value without '=' should fail")?;

    // -- Check
    assert!(
        err.to_string().contains("file:///run/secrets/api-token"),
        "error should name the offending value, got: {err}"
    );
    Ok(())
}

#[test]
fn test_auth_parse_env_credentials_empty_target_errors() -> Result<()> {
    // -- Setup & Fixtures
    let values = vec!["file:///run/secrets/api-token=".to_string()];

    // -- Exec
    let err = parse_env_credentials(&values)
        .err()
        .ok_or("empty target should fail")?;

    // -- Check
    assert!(
        err.to_string().contains("file:///run/secrets/api-token"),
        "error should name the offending value, got: {err}"
    );
    Ok(())
}

#[test]
fn test_auth_parse_env_credentials_empty_ref_errors() -> Result<()> {
    // -- Setup & Fixtures
    let values = vec!["=MY_API_KEY".to_string()];

    // -- Exec
    let err = parse_env_credentials(&values)
        .err()
        .ok_or("empty credential reference should fail")?;

    // -- Check
    assert!(
        err.to_string().contains("=MY_API_KEY"),
        "error should name the offending value, got: {err}"
    );
    Ok(())
}

#[test]
fn test_auth_parse_env_credentials_splits_every_scheme_shape() -> Result<()> {
    // -- Setup & Fixtures
    let values = vec![
        "bare-token=NU_MCP_TEST_BARE".to_string(),
        "keyring://nu-mcp/git=NU_MCP_TEST_KEYRING".to_string(),
        "op://vault/item/field=NU_MCP_TEST_OP".to_string(),
        "bw://item/field=NU_MCP_TEST_BW".to_string(),
        "apple-password://server/account=NU_MCP_TEST_APPLE".to_string(),
        "file:///run/secrets/api-token=NU_MCP_TEST_FILE".to_string(),
        "env://SRC_TOKEN=NU_MCP_TEST_ENV".to_string(),
    ];

    // -- Exec
    let pairs = parse_env_credentials(&values)?;

    // -- Check
    assert_eq!(
        pairs,
        vec![
            ("bare-token".to_string(), "NU_MCP_TEST_BARE".to_string()),
            (
                "keyring://nu-mcp/git".to_string(),
                "NU_MCP_TEST_KEYRING".to_string()
            ),
            (
                "op://vault/item/field".to_string(),
                "NU_MCP_TEST_OP".to_string()
            ),
            ("bw://item/field".to_string(), "NU_MCP_TEST_BW".to_string()),
            (
                "apple-password://server/account".to_string(),
                "NU_MCP_TEST_APPLE".to_string()
            ),
            (
                "file:///run/secrets/api-token".to_string(),
                "NU_MCP_TEST_FILE".to_string()
            ),
            ("env://SRC_TOKEN".to_string(), "NU_MCP_TEST_ENV".to_string()),
        ]
    );
    Ok(())
}

#[test]
fn test_auth_parse_env_credentials_last_equals_splits_op_ref() -> Result<()> {
    // -- Setup & Fixtures
    let values = vec!["op://vault/it=em/field=NU_MCP_TEST_OP".to_string()];

    // -- Exec
    let pairs = parse_env_credentials(&values)?;

    // -- Check
    assert_eq!(
        pairs,
        vec![(
            "op://vault/it=em/field".to_string(),
            "NU_MCP_TEST_OP".to_string()
        )]
    );
    Ok(())
}

#[test]
fn test_auth_parse_env_credentials_empty_half_after_trim_errors() -> Result<()> {
    // -- Setup & Fixtures
    let values = vec!["file:///run/secrets/api-token =   ".to_string()];

    // -- Exec
    let err = parse_env_credentials(&values)
        .err()
        .ok_or("target empty after trim should fail")?;

    // -- Check
    assert!(
        err.to_string().contains("empty target variable"),
        "error should name the empty target, got: {err}"
    );
    Ok(())
}

// endregion: --- Parse

// region:    --- Phase

#[test]
fn test_auth_run_credential_phase_loads_file_secret() -> Result<()> {
    // -- Setup & Fixtures
    let dir = TempDir::new("auth-load-file");
    let secret_path = dir.path().join("api-token");
    std::fs::write(&secret_path, b"token-value\n")?;
    let config = config_with(vec![file_credential(&secret_path, "NU_MCP_TEST_API_TOKEN")]);

    // -- Exec
    let secrets = run_credential_phase(&config, None)?;

    // -- Check
    let secret = secrets.first().ok_or("should load one secret")?;
    assert_eq!(secrets.len(), 1);
    assert_eq!(secret.env_var, "NU_MCP_TEST_API_TOKEN");
    assert_eq!(secret.value.as_str(), "token-value");
    Ok(())
}

#[test]
fn test_auth_run_credential_phase_keeps_one_secret_per_pair() -> Result<()> {
    // -- Setup & Fixtures
    let dir = TempDir::new("auth-load-two");
    let first_path = dir.path().join("first");
    let second_path = dir.path().join("second");
    std::fs::write(&first_path, b"first-value")?;
    std::fs::write(&second_path, b"second-value")?;
    let config = config_with(vec![
        file_credential(&first_path, "NU_MCP_TEST_FIRST"),
        file_credential(&second_path, "NU_MCP_TEST_SECOND"),
    ]);

    // -- Exec
    let mut secrets = run_credential_phase(&config, None)?;

    // -- Check
    secrets.sort_by(|a, b| a.env_var.cmp(&b.env_var));
    let env_vars: Vec<&str> = secrets.iter().map(|s| s.env_var.as_str()).collect();
    let values: Vec<&str> = secrets.iter().map(|s| s.value.as_str()).collect();
    assert_eq!(env_vars, vec!["NU_MCP_TEST_FIRST", "NU_MCP_TEST_SECOND"]);
    assert_eq!(values, vec!["first-value", "second-value"]);
    Ok(())
}

#[test]
fn test_auth_run_credential_phase_passes_outer_caps_through() -> Result<()> {
    // -- Setup & Fixtures
    let dir = TempDir::new("auth-outer-caps");
    let secret_path = dir.path().join("api-token");
    std::fs::write(&secret_path, b"caps-value")?;
    let config = config_with(vec![file_credential(&secret_path, "NU_MCP_TEST_CAPS")]);
    let caps = CapabilitySet::new();

    // -- Exec
    let secrets = run_credential_phase(&config, Some(&caps))?;

    // -- Check
    let secret = secrets.first().ok_or("should load one secret")?;
    assert_eq!(secret.env_var, "NU_MCP_TEST_CAPS");
    assert_eq!(secret.value.as_str(), "caps-value");
    Ok(())
}

#[test]
fn test_auth_run_credential_phase_rejects_invalid_env_var() -> Result<()> {
    // -- Setup & Fixtures
    let target = "BAD(NAME";
    let config = config_with(vec![format!("file:///tmp/nu-mcp-cred={target}")]);

    // -- Exec
    let err = run_credential_phase(&config, None)
        .err()
        .ok_or("invalid target env var should fail")?;

    // -- Check
    assert!(
        err.to_string()
            .contains("destination environment variable name contains invalid character '('"),
        "error should carry the nono ConfigParse message, got: {err}"
    );
    assert!(
        std::env::var(target).is_err(),
        "rejected target must not be set: {target}"
    );
    Ok(())
}

#[test]
fn test_auth_run_credential_phase_rejects_blocklisted_env_var() -> Result<()> {
    // -- Setup & Fixtures
    let before = std::env::var("PATH")?;
    let config = config_with(vec!["file:///tmp/nu-mcp-cred=PATH".to_string()]);

    // -- Exec
    let err = run_credential_phase(&config, None)
        .err()
        .ok_or("blocklisted target env var should fail")?;

    // -- Check
    assert!(
        err.to_string().contains(
            "destination environment variable 'PATH' is on the blocklist of dangerous variables"
        ),
        "error should carry the nono blocklist message, got: {err}"
    );
    assert_eq!(
        std::env::var("PATH")?,
        before,
        "blocklisted target PATH must not change"
    );
    Ok(())
}

#[test]
fn test_auth_run_credential_phase_rejects_bare_ref_with_invalid_target() -> Result<()> {
    // -- Setup & Fixtures
    let target = "NU-MCP-TEST-BAD";
    let config = config_with(vec![format!("bare-keyring-account={target}")]);

    // -- Exec
    let err = run_credential_phase(&config, None)
        .err()
        .ok_or("invalid target on a bare reference should fail")?;

    // -- Check
    assert!(
        err.to_string()
            .contains("destination environment variable name contains invalid character '-'"),
        "error should reject the target before any keystore access, got: {err}"
    );
    assert!(
        std::env::var(target).is_err(),
        "rejected target must not be set: {target}"
    );
    Ok(())
}

#[test]
fn test_auth_run_credential_phase_validation_error_loads_nothing() -> Result<()> {
    // -- Setup & Fixtures
    let dir = TempDir::new("auth-validation-first");
    let secret_path = dir.path().join("api-token");
    std::fs::write(&secret_path, b"never-injected")?;
    let config = config_with(vec![
        file_credential(&secret_path, "NU_MCP_TEST_NEVER_INJECTED"),
        "file:///run/secrets/other=BAD(NAME".to_string(),
    ]);

    // -- Exec
    let err = run_credential_phase(&config, None)
        .err()
        .ok_or("one invalid target must fail the whole phase")?;

    // -- Check
    assert!(
        err.to_string().contains("invalid character '('"),
        "error should name the invalid target, got: {err}"
    );
    assert!(
        std::env::var("NU_MCP_TEST_NEVER_INJECTED").is_err(),
        "a failing phase must load no secrets"
    );
    Ok(())
}

#[test]
fn test_auth_run_credential_phase_load_error_sets_no_env() -> Result<()> {
    // -- Setup & Fixtures
    let target = "NU_MCP_TEST_MISSING_CRED";
    let missing = Path::new("/tmp").join(format!(
        "nu-mcp-missing-cred-{}-{target}",
        std::process::id()
    ));
    assert!(!missing.exists(), "fixture file must not exist");
    let config = config_with(vec![file_credential(&missing, target)]);

    // -- Exec
    let err = run_credential_phase(&config, None)
        .err()
        .ok_or("missing credential file should fail")?;

    // -- Check
    assert!(
        err.to_string().contains("credential file not found"),
        "error should report the missing file, got: {err}"
    );
    assert!(
        err.to_string().contains(&missing.display().to_string()),
        "error should name the missing path, got: {err}"
    );
    assert!(
        std::env::var(target).is_err(),
        "failed load must not set {target}"
    );
    Ok(())
}

// endregion: --- Phase

// region:    --- Support

/// A unique temporary directory, removed when dropped.
struct TempDir(PathBuf);

impl TempDir {
    fn new(label: &str) -> Self {
        let dir = Path::new("/tmp").join(format!("nu-mcp-{label}-{}", std::process::id()));
        std::fs::create_dir_all(&dir).ok();
        Self(dir)
    }

    fn path(&self) -> &Path {
        &self.0
    }
}

impl Drop for TempDir {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).ok();
    }
}

fn config_with(env_credentials: Vec<String>) -> Config {
    Config {
        env_credentials,
        ..Config::default()
    }
}

fn file_credential(path: &Path, env_var: &str) -> String {
    format!("file://{}={env_var}", path.display())
}

// endregion: --- Support
