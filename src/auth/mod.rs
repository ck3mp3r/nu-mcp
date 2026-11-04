//! Credential phase: turns `--env-credential` values into loaded keystore secrets.

use crate::config::Config;
use anyhow::{Result, anyhow};
use nono::keystore::{DEFAULT_SERVICE, build_secret_mappings};
use nono::{CapabilitySet, LoadedSecret};
use std::collections::HashMap;

// region:    --- Functions

/// Parse `REF=ENV_VAR` values into `(credential_ref, env_var)` pairs.
///
/// A value is trimmed first, then split at its last `'='` so a reference may
/// itself contain `'='` (mirrors nono list-mode parsing).
pub fn parse_env_credentials(values: &[String]) -> Result<Vec<(String, String)>> {
    values
        .iter()
        .map(|value| parse_env_credential(value))
        .collect()
}

/// Resolve the configured credentials into loaded keystore secrets.
///
/// Sets no environment variables; the caller owns injection.
pub fn run_credential_phase(
    config: &Config,
    outer_caps: Option<&CapabilitySet>,
) -> Result<Vec<LoadedSecret>> {
    let pairs = parse_env_credentials(&config.env_credentials)?;
    let mappings = build_secret_mappings(None, &pairs, &HashMap::new())
        .map_err(|err| anyhow!("failed to build credential mappings: {err}"))?;
    let service = config.keyring_service.as_deref().unwrap_or(DEFAULT_SERVICE);
    nono::load_secrets(service, &mappings, outer_caps)
        .map_err(|err| anyhow!("failed to load credentials: {err}"))
}

// endregion: --- Functions

// region:    --- Support

fn parse_env_credential(value: &str) -> Result<(String, String)> {
    let value = value.trim();
    let Some((credential_ref, env_var)) = value.rsplit_once('=') else {
        return Err(anyhow!(
            "env credential '{value}' must use the format REF=ENV_VAR"
        ));
    };
    let credential_ref = credential_ref.trim();
    let env_var = env_var.trim();
    if credential_ref.is_empty() {
        return Err(anyhow!(
            "env credential '{value}' has an empty credential reference"
        ));
    }
    if env_var.is_empty() {
        return Err(anyhow!(
            "env credential '{value}' has an empty target variable"
        ));
    }
    Ok((credential_ref.to_string(), env_var.to_string()))
}

// endregion: --- Support

// region:    --- Tests

#[cfg(test)]
#[path = "../../test/auth/mod_test.rs"]
mod mod_test;

// endregion: --- Tests
