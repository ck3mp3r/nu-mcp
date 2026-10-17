//! Sandbox Security Module
//!
//! Builds a nono [`CapabilitySet`] from sandbox configuration. The capability
//! set is applied to the nu-mcp server process at startup (see `main.rs`); child
//! `nu` processes inherit it. Kernel enforcement (Landlock on Linux, Seatbelt on
//! macOS) is the single security boundary; there is no string-based command
//! validation.

use crate::config::Config;
use nono::{AccessMode, CapabilitySet};
use std::path::Path;

/// System paths granted [`AccessMode::Read`] so `nu` can start and run commands.
///
/// The nono library does not grant system paths automatically. Paths that do not
/// exist on the host are skipped.
#[cfg(target_os = "linux")]
const SYSTEM_READ_PATHS: &[&str] = &["/usr", "/lib", "/bin", "/etc/ssl"];

#[cfg(target_os = "macos")]
const SYSTEM_READ_PATHS: &[&str] = &[
    "/System/Library",
    "/Library",
    "/usr/lib",
    "/usr/share/zoneinfo",
    "/etc/ssl",
    "/private/var/db/dyld",
    "/var",
];

#[cfg(not(any(target_os = "linux", target_os = "macos")))]
const SYSTEM_READ_PATHS: &[&str] = &[];

/// Paths granted [`AccessMode::ReadWrite`] on every platform.
const SYSTEM_READWRITE_PATHS: &[&str] = &["/tmp"];

/// Build a nono capability set from sandbox configuration.
///
/// - `config.sandbox_directories` are granted [`AccessMode::ReadWrite`].
/// - `config.read_only_paths` are granted [`AccessMode::Read`].
/// - `config.tools_dir` is granted [`AccessMode::Read`] when set.
/// - `config.bypass_protection` paths are granted [`AccessMode::ReadWrite`],
///   unblocking paths the user explicitly opts into.
/// - Platform system paths are granted [`AccessMode::Read`] so `nu` can start.
/// - When `config.block_network` is true, all network access is blocked.
///
/// Paths that do not exist are skipped: [`CapabilitySet::allow_path`] rejects
/// missing paths, and the system path list differs between hosts.
pub fn build_capability_set(config: &Config) -> nono::Result<CapabilitySet> {
    let mut caps = CapabilitySet::new();

    for path in SYSTEM_READ_PATHS {
        caps = allow_if_dir(caps, Path::new(path), AccessMode::Read)?;
    }
    for path in SYSTEM_READWRITE_PATHS {
        caps = allow_if_dir(caps, Path::new(path), AccessMode::ReadWrite)?;
    }
    for path in &config.sandbox_directories {
        caps = allow_if_dir(caps, path, AccessMode::ReadWrite)?;
    }
    for path in &config.read_only_paths {
        caps = allow_if_dir(caps, path, AccessMode::Read)?;
    }
    if let Some(tools_dir) = &config.tools_dir {
        caps = allow_if_dir(caps, tools_dir, AccessMode::Read)?;
    }
    for path in &config.bypass_protection {
        caps = allow_if_dir(caps, path, AccessMode::ReadWrite)?;
    }

    if config.block_network {
        caps = caps.block_network();
    }

    Ok(caps)
}

/// Grant `mode` on `path` when it exists as a directory, otherwise return the
/// set unchanged.
fn allow_if_dir(caps: CapabilitySet, path: &Path, mode: AccessMode) -> nono::Result<CapabilitySet> {
    if path.is_dir() {
        caps.allow_path(path, mode)
    } else {
        Ok(caps)
    }
}

#[cfg(test)]
#[path = "../../test/security/mod_test.rs"]
mod mod_test;
