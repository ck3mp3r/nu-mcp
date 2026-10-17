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
const SYSTEM_READ_PATHS: &[&str] = &[
    "/bin",
    "/sbin",
    "/usr/bin",
    "/usr/sbin",
    "/usr/local/bin",
    "/lib",
    "/lib64",
    "/lib/x86_64-linux-gnu",
    "/lib/aarch64-linux-gnu",
    "/usr/lib",
    "/usr/lib64",
    "/usr/lib/x86_64-linux-gnu",
    "/usr/lib/aarch64-linux-gnu",
    "/usr/local/lib",
    "/usr/local/lib64",
    "/etc/resolv.conf",
    "/run/systemd/resolve",
    "/etc/hosts",
    "/etc/nsswitch.conf",
    "/etc/gai.conf",
    "/etc/group",
    "/etc/ssl",
    "/etc/pki",
    "/etc/ca-certificates",
    "/etc/crypto-policies",
    "/etc/fonts",
    "/etc/ld.so.cache",
    "/etc/ld.so.conf",
    "/etc/ld.so.conf.d",
    "/etc/localtime",
    "/etc/timezone",
    "/etc/locale.conf",
    "/etc/locale.gen",
    "/etc/alternatives",
    "/etc/os-release",
    "/etc/passwd",
    "/etc/services",
    "/etc/mime.types",
    "/etc/manpath.config",
    "/etc/man_db.conf",
    "/var/cache/man",
    "/run/systemd/userdb",
    "/usr/share",
    "/usr/share/locale",
    "/usr/share/locale-langpack",
    "/usr/share/zoneinfo",
    "/usr/share/terminfo",
    "/usr/share/ca-certificates",
    "/lib/terminfo",
    "/etc/terminfo",
    "/dev/null",
    "/dev/zero",
    "/dev/random",
    "/dev/urandom",
    "/dev/full",
    "/dev/tty",
    "/dev/console",
    "/dev/stdin",
    "/dev/stdout",
    "/dev/stderr",
    "/dev/fd",
    "/dev/pts",
    "/proc/self",
    "/proc/cpuinfo",
    "/proc/meminfo",
    "/proc/stat",
    "/proc/loadavg",
    "/proc/version",
    "/proc/filesystems",
    "/home/linuxbrew/.linuxbrew",
];

#[cfg(target_os = "macos")]
const SYSTEM_READ_PATHS: &[&str] = &[
    "/bin",
    "/sbin",
    "/usr/bin",
    "/usr/sbin",
    "/usr/local/bin",
    "/usr/lib",
    "/usr/local/lib",
    "/usr/share",
    "/System/Library",
    "/Library",
    "/Library/Frameworks",
    "/dev",
    "/private/var/db/dyld",
    "/var/db/dyld",
    "/var/db",
    "/private/etc/ssl",
    "/etc/ssl",
    "/etc",
    "/private/etc",
    "/usr/share/zoneinfo",
    "/usr/share/locale",
    "/var/db/timezone",
    "/usr/share/terminfo",
    "/var",
    "/private/var",
    "/private",
    "/tmp",
    "/System/Volumes",
    "/System/Cryptexes",
    "/Applications",
    "/cores",
    "/opt",
    "/run",
    "/nix",
    "/opt/homebrew",
    "/usr/local/Cellar",
    "/usr/local/opt",
];

#[cfg(not(any(target_os = "linux", target_os = "macos")))]
const SYSTEM_READ_PATHS: &[&str] = &[];

/// Paths granted [`AccessMode::ReadWrite`] on macOS, from nono's
/// `system_write_macos` group.
#[cfg(target_os = "macos")]
const SYSTEM_WRITE_PATHS_MACOS: &[&str] = &[
    "/private/tmp",
    "/tmp",
    "/private/var/folders",
    "/var/folders",
    "/dev",
];

/// Paths granted [`AccessMode::ReadWrite`] on Linux, from nono's
/// `system_write_linux` group.
#[cfg(target_os = "linux")]
const SYSTEM_WRITE_PATHS_LINUX: &[&str] = &[
    "/tmp",
    "/dev/null",
    "/dev/zero",
    "/dev/full",
    "/dev/tty",
    "/dev/stdout",
    "/dev/stderr",
    "/dev/fd",
    "/dev/pts",
    "/proc/self/fd",
];

/// User tool directories granted [`AccessMode::Read`], from nono's `user_tools`
/// group. The `~` prefix is expanded to `$HOME` at runtime.
const USER_TOOLS_PATHS: &[&str] = &[
    "~/.local/bin",
    "~/.local/share/applications",
    "~/.local/share/man",
    "~/.local/share/bash-completion",
    "~/.local/share/zsh",
];

/// Platform-specific paths granted [`AccessMode::ReadWrite`].
#[cfg(target_os = "macos")]
fn system_write_paths() -> &'static [&'static str] {
    SYSTEM_WRITE_PATHS_MACOS
}

/// Platform-specific paths granted [`AccessMode::ReadWrite`].
#[cfg(target_os = "linux")]
fn system_write_paths() -> &'static [&'static str] {
    SYSTEM_WRITE_PATHS_LINUX
}

/// No write paths on unsupported platforms.
#[cfg(not(any(target_os = "linux", target_os = "macos")))]
fn system_write_paths() -> &'static [&'static str] {
    &[]
}

/// Build a nono capability set from sandbox configuration.
///
/// - `config.sandbox_directories` are granted [`AccessMode::ReadWrite`].
/// - `config.read_only_paths` are granted [`AccessMode::Read`].
/// - `config.tools_dir` is granted [`AccessMode::Read`] when set.
/// - `config.bypass_protection` paths are granted [`AccessMode::ReadWrite`],
///   unblocking paths the user explicitly opts into.
/// - Platform system paths are granted [`AccessMode::Read`] so `nu` can start.
/// - Platform system write paths are granted [`AccessMode::ReadWrite`].
/// - `$TMPDIR` is granted [`AccessMode::ReadWrite`] when the variable is set.
/// - `user_tools` directories under `$HOME` are granted [`AccessMode::Read`]
///   when the variable is set.
/// - The `nu` binary resolved from `$PATH` and its dynamic library dependencies
///   are granted [`AccessMode::Read`] (see [`grant_nu_access`]).
/// - Every binary in `config.allow_binaries` that resolves in `$PATH` is
///   granted [`AccessMode::Read`] (see [`grant_allow_binaries`]).
/// - Every non-empty `$PATH` directory is registered for metadata-only read on
///   macOS (see [`grant_path_metadata_dirs`]).
/// - When `config.block_network` is true, all network access is blocked.
///
/// Config paths that start with `~/` are expanded against `$HOME` before the
/// grant is attempted (see [`allow_config_dir`]).
///
/// Paths that do not exist are skipped: [`CapabilitySet::allow_path`] rejects
/// missing paths, and the system path list differs between hosts.
pub fn build_capability_set(config: &Config) -> nono::Result<CapabilitySet> {
    let mut caps = CapabilitySet::new();

    for path in SYSTEM_READ_PATHS {
        caps = allow_if_dir(caps, Path::new(path), AccessMode::Read)?;
    }
    for path in USER_TOOLS_PATHS {
        if let Some(path) = expand_home(path) {
            caps = allow_if_dir(caps, &path, AccessMode::Read)?;
        }
    }
    caps = grant_nu_access(caps)?;
    if let Some(path) = std::env::var_os("PATH") {
        caps = grant_allow_binaries(
            caps,
            config.allow_binaries.iter().map(String::as_str),
            &path,
        )?;
    }
    caps = grant_path_metadata_dirs(caps)?;
    for path in system_write_paths() {
        caps = allow_if_dir(caps, Path::new(path), AccessMode::ReadWrite)?;
    }
    if let Some(tmpdir) = std::env::var_os("TMPDIR") {
        caps = allow_if_dir(caps, Path::new(&tmpdir), AccessMode::ReadWrite)?;
    }
    for path in &config.sandbox_directories {
        caps = allow_config_dir(caps, path, AccessMode::ReadWrite)?;
    }
    for path in &config.read_only_paths {
        caps = allow_config_dir(caps, path, AccessMode::Read)?;
    }
    if let Some(tools_dir) = &config.tools_dir {
        caps = allow_config_dir(caps, tools_dir, AccessMode::Read)?;
    }
    for path in &config.bypass_protection {
        caps = allow_config_dir(caps, path, AccessMode::ReadWrite)?;
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

/// Expand `~` in a config-specified path, then grant `mode` when the expanded
/// path exists as a directory.
///
/// Logs a warning and skips the path when `HOME` is unset for a `~/` path, or
/// when the path does not exist as a directory, so silently-dropped grants are
/// visible in logs.
fn allow_config_dir(
    caps: CapabilitySet,
    path: &Path,
    mode: AccessMode,
) -> nono::Result<CapabilitySet> {
    let expanded = if path.starts_with("~/") {
        match expand_home(path) {
            Some(expanded) => expanded,
            None => {
                tracing::warn!(
                    "config path {} starts with ~/ but HOME is not set; skipping",
                    path.display()
                );
                return Ok(caps);
            }
        }
    } else {
        path.to_path_buf()
    };
    if !expanded.is_dir() {
        tracing::warn!(
            "config path {} does not exist or is not a directory; skipping",
            expanded.display()
        );
    }
    allow_if_dir(caps, &expanded, mode)
}

/// Expand a `~`-prefixed path to an absolute path using `$HOME`.
///
/// Returns `None` when `HOME` is not set or `path` does not start with `~/`.
fn expand_home(path: impl AsRef<Path>) -> Option<PathBuf> {
    let home = std::env::var_os("HOME")?;
    let rest = path.as_ref().strip_prefix("~/").ok()?;
    Some(PathBuf::from(home).join(rest))
}

/// Resolve the `nu` binary in `$PATH` and grant [`AccessMode::Read`] to the
/// directories it needs to start.
///
/// A missing `nu` binary logs a warning and leaves the set unchanged.
fn grant_nu_access(caps: CapabilitySet) -> nono::Result<CapabilitySet> {
    grant_binary_access(caps, find_in_path("nu").as_deref())
}

/// Grant [`AccessMode::Read`] to the parent directories of every binary in
/// `names` that resolves in `path`.
///
/// Names that do not resolve are skipped without error.
fn grant_allow_binaries<'a>(
    caps: CapabilitySet,
    names: impl IntoIterator<Item = &'a str>,
    path: &OsStr,
) -> nono::Result<CapabilitySet> {
    let mut caps = caps;
    for name in names {
        let binary = find_in_path_in(name, path);
        caps = grant_binary_access(caps, binary.as_deref())?;
    }
    Ok(caps)
}

/// Grant [`AccessMode::Read`] to the parent directory of `binary` and to the
/// parent directories of its dynamic library dependencies.
///
/// `binary` is canonicalized first: when the `$PATH` entry is a symlink (Homebrew,
/// nix profile, NixOS), the kernel resolves it at exec and checks access on the
/// target path, so the target's parent directory must be granted.
///
/// When `binary` is `None`, logs a warning and returns the set unchanged. When
/// canonicalization fails, logs a warning and returns the set unchanged.
fn grant_binary_access(caps: CapabilitySet, binary: Option<&Path>) -> nono::Result<CapabilitySet> {
    let Some(binary) = binary else {
        tracing::warn!("nu binary not found in PATH; skipping nu path grants");
        return Ok(caps);
    };
    let binary = match std::fs::canonicalize(binary) {
        Ok(path) => path,
        Err(err) => {
            tracing::warn!(
                "failed to canonicalize {}: {err}; skipping nu path grants",
                binary.display()
            );
            return Ok(caps);
        }
    };
    tracing::debug!("resolved nu binary at {}", binary.display());

    let mut caps = caps;
    if let Some(parent) = binary.parent() {
        caps = allow_if_dir(caps, parent, AccessMode::Read)?;
    }
    for dir in nu_library_dirs(&binary) {
        tracing::debug!("granting Read to nu dependency directory {}", dir.display());
        caps = allow_if_dir(caps, &dir, AccessMode::Read)?;
    }
    Ok(caps)
}

/// Register every non-empty `$PATH` directory for metadata-only read access.
///
/// On macOS, Seatbelt returns `EPERM` for denied `stat()` calls, which makes
/// `execvp` abort the `$PATH` walk instead of continuing to the next entry.
/// Metadata-only read lets `execvp` stat `<dir>/<command>` and receive `ENOENT`,
/// so the walk continues. On other platforms this is a no-op.
#[cfg(target_os = "macos")]
fn grant_path_metadata_dirs(caps: CapabilitySet) -> nono::Result<CapabilitySet> {
    let Some(path) = std::env::var_os("PATH") else {
        return Ok(caps);
    };
    Ok(grant_path_metadata_dirs_in(caps, &path))
}

/// Register every non-empty directory in `path` for metadata-only read.
#[cfg(target_os = "macos")]
fn grant_path_metadata_dirs_in(caps: CapabilitySet, path: &OsStr) -> CapabilitySet {
    let mut caps = caps;
    for dir in std::env::split_paths(path) {
        if dir.as_os_str().is_empty() {
            continue;
        }
        caps.add_path_metadata_dir(dir.clone());
        let canonical = nono::try_canonicalize(&dir);
        if canonical != dir {
            caps.add_path_metadata_dir(canonical);
        }
    }
    caps
}

/// No-op on platforms where a denied `stat()` is non-fatal to `execvp`.
#[cfg(not(target_os = "macos"))]
fn grant_path_metadata_dirs(caps: CapabilitySet) -> nono::Result<CapabilitySet> {
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
