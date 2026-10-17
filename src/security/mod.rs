//! Sandbox Security Module
//!
//! Builds a nono [`CapabilitySet`] from sandbox configuration. The capability
//! set is applied to the nu-mcp server process at startup (see `main.rs`); child
//! `nu` processes inherit it. Kernel enforcement (Landlock on Linux, Seatbelt on
//! macOS) is the single security boundary; there is no string-based command
//! validation.

use crate::config::Config;
use nono::{AccessMode, CapabilitySet};
use std::ffi::OsStr;
use std::path::{Path, PathBuf};

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
/// - The `nu` binary resolved from `$PATH` and its dynamic library dependencies
///   are granted [`AccessMode::Read`] (see [`grant_nu_access`]).
/// - When `config.block_network` is true, all network access is blocked.
///
/// Paths that do not exist are skipped: [`CapabilitySet::allow_path`] rejects
/// missing paths, and the system path list differs between hosts.
pub fn build_capability_set(config: &Config) -> nono::Result<CapabilitySet> {
    let mut caps = CapabilitySet::new();

    for path in SYSTEM_READ_PATHS {
        caps = allow_if_dir(caps, Path::new(path), AccessMode::Read)?;
    }
    caps = grant_nu_access(caps)?;
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

/// Resolve the `nu` binary in `$PATH` and grant [`AccessMode::Read`] to the
/// directories it needs to start.
///
/// A missing `nu` binary logs a warning and leaves the set unchanged.
fn grant_nu_access(caps: CapabilitySet) -> nono::Result<CapabilitySet> {
    grant_binary_access(caps, find_in_path("nu").as_deref())
}

/// Grant [`AccessMode::Read`] to the parent directory of `binary` and to the
/// parent directories of its dynamic library dependencies.
///
/// When `binary` is `None`, logs a warning and returns the set unchanged.
fn grant_binary_access(caps: CapabilitySet, binary: Option<&Path>) -> nono::Result<CapabilitySet> {
    let Some(binary) = binary else {
        tracing::warn!("nu binary not found in PATH; skipping nu path grants");
        return Ok(caps);
    };
    tracing::debug!("resolved nu binary at {}", binary.display());

    let mut caps = caps;
    if let Some(parent) = binary.parent() {
        caps = allow_if_dir(caps, parent, AccessMode::Read)?;
    }
    for dir in nu_library_dirs(binary) {
        tracing::debug!("granting Read to nu dependency directory {}", dir.display());
        caps = allow_if_dir(caps, &dir, AccessMode::Read)?;
    }
    Ok(caps)
}

/// Find a file named `name` by walking the `PATH` environment variable.
///
/// Returns the first `dir.join(name)` that exists as a file.
fn find_in_path(name: &str) -> Option<PathBuf> {
    let path = std::env::var_os("PATH")?;
    find_in_path_in(name, &path)
}

/// Find a file named `name` by walking the directories in `path`.
fn find_in_path_in(name: &str, path: &OsStr) -> Option<PathBuf> {
    std::env::split_paths(path)
        .map(|dir| dir.join(name))
        .find(|candidate| candidate.is_file())
}

/// Parent directories of the dynamic libraries `binary` links against, for
/// libraries outside [`SYSTEM_READ_PATHS`].
#[cfg(target_os = "macos")]
fn nu_library_dirs(binary: &Path) -> Vec<PathBuf> {
    let output = match std::process::Command::new("otool")
        .arg("-L")
        .arg(binary)
        .output()
    {
        Ok(output) if output.status.success() => output,
        Ok(output) => {
            tracing::warn!(
                "otool -L failed for {}: {}",
                binary.display(),
                output.status
            );
            return Vec::new();
        }
        Err(err) => {
            tracing::warn!("failed to run otool for {}: {err}", binary.display());
            return Vec::new();
        }
    };
    library_dirs(&String::from_utf8_lossy(&output.stdout))
}

/// Parent directories of the dynamic libraries `binary` links against, for
/// libraries outside [`SYSTEM_READ_PATHS`].
#[cfg(target_os = "linux")]
fn nu_library_dirs(binary: &Path) -> Vec<PathBuf> {
    let output = match std::process::Command::new("ldd").arg(binary).output() {
        Ok(output) if output.status.success() => output,
        Ok(output) => {
            tracing::warn!("ldd failed for {}: {}", binary.display(), output.status);
            return Vec::new();
        }
        Err(err) => {
            tracing::warn!("failed to run ldd for {}: {err}", binary.display());
            return Vec::new();
        }
    };
    library_dirs(&String::from_utf8_lossy(&output.stdout))
}

/// No dynamic library enumeration on unsupported platforms.
#[cfg(not(any(target_os = "linux", target_os = "macos")))]
fn nu_library_dirs(_binary: &Path) -> Vec<PathBuf> {
    Vec::new()
}

/// Extract the parent directories of absolute library paths from `otool -L` or
/// `ldd` output, skipping paths under [`SYSTEM_READ_PATHS`].
#[cfg(any(target_os = "linux", target_os = "macos"))]
fn library_dirs(output: &str) -> Vec<PathBuf> {
    let mut dirs: Vec<PathBuf> = output
        .lines()
        .filter_map(parse_library_path)
        .filter(|path| !is_under_system_path(path))
        .filter_map(|path| path.parent().map(Path::to_path_buf))
        .collect();
    dirs.sort();
    dirs.dedup();
    dirs
}

/// Parse one `otool -L` or `ldd` output line into an absolute library path.
#[cfg(any(target_os = "linux", target_os = "macos"))]
fn parse_library_path(line: &str) -> Option<PathBuf> {
    let line = line.trim();
    if line.is_empty() || line.ends_with(':') {
        return None;
    }
    let candidate = line.rsplit("=>").next().unwrap_or(line).trim();
    let token = candidate.split_whitespace().next()?;
    if token.starts_with('/') {
        Some(PathBuf::from(token))
    } else {
        None
    }
}

/// True when `path` is inside one of the [`SYSTEM_READ_PATHS`] directories.
#[cfg(any(target_os = "linux", target_os = "macos"))]
fn is_under_system_path(path: &Path) -> bool {
    SYSTEM_READ_PATHS
        .iter()
        .any(|sys| path.starts_with(Path::new(sys)))
}

#[cfg(test)]
#[path = "../../test/security/mod_test.rs"]
mod mod_test;
