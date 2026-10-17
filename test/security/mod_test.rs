#[cfg(target_os = "macos")]
use super::grant_path_metadata_dirs_in;
#[cfg(any(target_os = "linux", target_os = "macos"))]
use super::library_dirs;
use super::{
    SYSTEM_READ_PATHS, build_capability_set, find_in_path, find_in_path_in, grant_allow_binaries,
    grant_binary_access,
};
use crate::config::Config;
use nono::{AccessMode, CapabilitySet};
use serial_test::serial;
use std::path::{Path, PathBuf};

/// A unique temporary directory, removed when dropped.
struct TempDir(PathBuf);

impl TempDir {
    fn new(label: &str) -> Self {
        let dir = Path::new("/tmp").join(format!("nu-mcp-{label}-{}", std::process::id()));
        std::fs::create_dir_all(&dir).expect("create temp dir");
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

#[cfg(target_os = "linux")]
#[test]
fn test_system_read_paths_contains_expanded_list() {
    let expected = [
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
    for path in expected {
        assert!(
            SYSTEM_READ_PATHS.contains(&path),
            "SYSTEM_READ_PATHS should contain {path}"
        );
    }
    assert_eq!(SYSTEM_READ_PATHS.len(), expected.len());
}

#[cfg(target_os = "macos")]
#[test]
fn test_system_read_paths_contains_expanded_list() {
    let expected = [
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
    for path in expected {
        assert!(
            SYSTEM_READ_PATHS.contains(&path),
            "SYSTEM_READ_PATHS should contain {path}"
        );
    }
    assert_eq!(SYSTEM_READ_PATHS.len(), expected.len());
}

#[test]
fn test_missing_config_path_errors() {
    let missing = PathBuf::from("/nonexistent-nu-mcp-test-xyz/subdir");
    assert!(!missing.exists());
    let config = Config {
        sandbox_directories: vec![missing.clone()],
        ..Config::default()
    };
    let err = build_capability_set(&config).expect_err("missing config path should fail");
    assert!(
        err.to_string().contains(&missing.display().to_string()),
        "error should name the missing path, got: {err}"
    );
}

#[test]
fn test_find_in_path_in_finds_file() {
    let dir = TempDir::new("find-in-path");
    let bin = dir.path().join("nu-mcp-test-bin");
    std::fs::write(&bin, b"").expect("write test binary");
    let path = std::env::join_paths([dir.path().as_os_str()]).expect("join paths");
    assert_eq!(find_in_path_in("nu-mcp-test-bin", &path), Some(bin));
}

#[test]
fn test_find_in_path_in_returns_none_for_missing() {
    let dir = TempDir::new("find-in-path-missing");
    let path = std::env::join_paths([dir.path().as_os_str()]).expect("join paths");
    assert_eq!(find_in_path_in("nu-mcp-does-not-exist-xyz", &path), None);
}

#[test]
fn test_find_in_path_resolves_nu() {
    let found = find_in_path("nu").expect("nu should be resolvable in PATH");
    assert!(found.is_file(), "resolved nu path should be a file");
}

#[test]
fn test_grant_binary_access_grants_parent_directory() {
    let dir = TempDir::new("grant-binary");
    let binary = dir.path().join("nu");
    std::fs::write(&binary, b"").expect("write nu");
    let caps = grant_binary_access(CapabilitySet::new(), Some(&binary)).expect("grant");
    let parent = dir.path().canonicalize().expect("canonicalize");
    assert!(
        caps.path_covered_with_access(&parent, AccessMode::Read),
        "nu parent directory should be covered Read"
    );
}

#[test]
fn test_grant_binary_access_without_binary_is_noop() {
    let caps = grant_binary_access(CapabilitySet::new(), None).expect("grant");
    assert!(
        caps.fs_capabilities().is_empty(),
        "no capabilities should be granted when nu is absent"
    );
}

#[cfg(unix)]
#[test]
fn test_grant_binary_access_canonicalizes_symlink() {
    let target_dir = TempDir::new("grant-binary-target");
    let link_dir = TempDir::new("grant-binary-link");
    let target = target_dir.path().join("nu");
    std::fs::write(&target, b"").expect("write nu target");
    let link = link_dir.path().join("nu");
    std::os::unix::fs::symlink(&target, &link).expect("create symlink");

    let caps = grant_binary_access(CapabilitySet::new(), Some(&link)).expect("grant");
    let real_parent = target_dir
        .path()
        .canonicalize()
        .expect("canonicalize target dir");
    assert!(
        caps.path_covered_with_access(&real_parent, AccessMode::Read),
        "symlink target parent directory {} should be covered Read",
        real_parent.display()
    );
}

#[test]
#[serial]
fn test_find_in_path_returns_none_without_path() {
    let saved = std::env::var_os("PATH");
    // SAFETY: `#[serial]` prevents concurrent env mutation in this process.
    unsafe { std::env::remove_var("PATH") };
    let result = find_in_path("nu");
    if let Some(path) = saved {
        // SAFETY: restoring the value captured above.
        unsafe { std::env::set_var("PATH", path) };
    }
    assert_eq!(result, None, "find_in_path should return None without PATH");
}

#[test]
fn test_build_capability_set_grants_nu_binary_directory() {
    let Some(binary) = find_in_path("nu") else {
        return;
    };
    let caps = build_capability_set(&Config::default()).expect("build");
    let parent = binary
        .parent()
        .expect("parent")
        .canonicalize()
        .expect("canonicalize");
    assert!(
        caps.path_covered_with_access(&parent, AccessMode::Read),
        "nu binary directory {} should be covered Read",
        parent.display()
    );
}

#[cfg(any(target_os = "linux", target_os = "macos"))]
#[test]
fn test_library_dirs_filters_system_paths() {
    let otool = "/custom/store/abc-nushell/bin/nu:\n\t/usr/lib/libSystem.B.dylib (compatibility version 1.0.0)\n\t/custom/store/xyz-libiconv/lib/libiconv.2.dylib (compatibility version 7.0.0)\n";
    assert_eq!(
        library_dirs(otool),
        vec![PathBuf::from("/custom/store/xyz-libiconv/lib")]
    );

    let ldd = "\tlinux-vdso.so.1 (0x00007fff)\n\tlibgcc_s.so.1 => /custom/store/aaa-gcc/lib/libgcc_s.so.1 (0x00007f)\n\tlibc.so.6 => /custom/store/bbb-glibc/lib/libc.so.6 (0x00007f)\n";
    assert_eq!(
        library_dirs(ldd),
        vec![
            PathBuf::from("/custom/store/aaa-gcc/lib"),
            PathBuf::from("/custom/store/bbb-glibc/lib"),
        ]
    );
}

#[cfg(target_os = "macos")]
#[test]
fn test_grant_path_metadata_dirs_registers_entries() {
    let path = std::env::join_paths(["/usr/bin", "/bin"]).expect("join paths");
    let caps = grant_path_metadata_dirs_in(CapabilitySet::new(), &path);
    let dirs = caps.path_metadata_dirs();
    assert!(
        dirs.contains(&PathBuf::from("/usr/bin")),
        "first PATH entry should be registered"
    );
    assert!(
        dirs.contains(&PathBuf::from("/bin")),
        "second PATH entry should be registered"
    );
}

#[cfg(target_os = "macos")]
#[test]
fn test_grant_path_metadata_dirs_skips_empty_entries() {
    let path = std::env::join_paths(["", "/usr/bin", ""]).expect("join paths");
    let caps = grant_path_metadata_dirs_in(CapabilitySet::new(), &path);
    let dirs = caps.path_metadata_dirs();
    assert!(
        !dirs.iter().any(|d| d.as_os_str().is_empty()),
        "empty PATH entries should be skipped"
    );
    assert!(
        dirs.contains(&PathBuf::from("/usr/bin")),
        "non-empty PATH entry should be registered"
    );
}

#[cfg(target_os = "macos")]
#[test]
fn test_grant_path_metadata_dirs_registers_canonical_target() {
    let target = TempDir::new("metadata-canonical-target");
    let link_parent = TempDir::new("metadata-canonical-link");
    let link = link_parent.path().join("bin");
    std::os::unix::fs::symlink(target.path(), &link).expect("create symlink");
    let path = std::env::join_paths([link.as_os_str()]).expect("join paths");
    let caps = grant_path_metadata_dirs_in(CapabilitySet::new(), &path);
    let dirs = caps.path_metadata_dirs();
    assert!(dirs.contains(&link), "raw PATH entry should be registered");
    let canonical = target.path().canonicalize().expect("canonicalize target");
    assert!(
        dirs.contains(&canonical),
        "canonicalized PATH entry should be registered"
    );
}

#[cfg(target_os = "macos")]
#[test]
fn test_grant_path_metadata_dirs_registers_canonical_nonexistent() {
    let target = TempDir::new("metadata-canonical-nonexistent-target");
    let link_parent = TempDir::new("metadata-canonical-nonexistent-link");
    let link = link_parent.path().join("bin");
    std::os::unix::fs::symlink(target.path(), &link).expect("create symlink");
    let entry = link.join("nonexistent_subdir");
    let path = std::env::join_paths([entry.as_os_str()]).expect("join paths");
    let caps = grant_path_metadata_dirs_in(CapabilitySet::new(), &path);
    let dirs = caps.path_metadata_dirs();
    assert!(dirs.contains(&entry), "raw PATH entry should be registered");
    let canonical = target
        .path()
        .canonicalize()
        .expect("canonicalize target")
        .join("nonexistent_subdir");
    assert!(
        dirs.contains(&canonical),
        "canonicalized non-existent PATH entry should be registered"
    );
}

#[cfg(target_os = "macos")]
#[test]
fn test_build_capability_set_registers_path_metadata_dirs() {
    let caps = build_capability_set(&Config::default()).expect("build");
    let dirs = caps.path_metadata_dirs();
    assert!(
        !dirs.is_empty(),
        "expected PATH metadata dirs to be registered"
    );
    let path = std::env::var_os("PATH").expect("PATH should be set");
    for dir in std::env::split_paths(&path).filter(|d| !d.as_os_str().is_empty()) {
        assert!(
            dirs.contains(&dir),
            "PATH dir {} should be registered as a metadata dir",
            dir.display()
        );
    }
}

#[test]
fn test_grant_allow_binaries_grants_resolved_binary() {
    let dir = TempDir::new("allow-binaries");
    let binary = dir.path().join("nu-mcp-allow-bin");
    std::fs::write(&binary, b"").expect("write test binary");
    let path = std::env::join_paths([dir.path().as_os_str()]).expect("join paths");
    let caps =
        grant_allow_binaries(CapabilitySet::new(), ["nu-mcp-allow-bin"], &path).expect("grant");
    let parent = dir.path().canonicalize().expect("canonicalize");
    assert!(
        caps.path_covered_with_access(&parent, AccessMode::Read),
        "allowlisted binary parent directory should be covered Read"
    );
}

#[test]
fn test_grant_allow_binaries_skips_missing_binary() {
    let dir = TempDir::new("allow-binaries-missing");
    let path = std::env::join_paths([dir.path().as_os_str()]).expect("join paths");
    let caps = grant_allow_binaries(CapabilitySet::new(), ["nu-mcp-does-not-exist-xyz"], &path)
        .expect("grant");
    assert!(
        caps.fs_capabilities().is_empty(),
        "missing allowlisted binary should grant nothing"
    );
}

#[test]
fn test_build_capability_set_grants_config_allow_binary() {
    let default_caps = build_capability_set(&Config::default()).expect("build");
    let Some((name, parent)) = ["git", "cargo", "rustc", "nix", "bash", "sh"]
        .into_iter()
        .filter_map(|name| {
            let binary = find_in_path(name)?;
            let parent = binary.canonicalize().ok()?.parent()?.to_path_buf();
            Some((name, parent))
        })
        .find(|(_, parent)| !default_caps.path_covered_with_access(parent, AccessMode::Read))
    else {
        return;
    };

    let caps = build_capability_set(&Config {
        allow_binaries: vec![name.to_string()],
        ..Config::default()
    })
    .expect("build");
    assert!(
        caps.path_covered_with_access(&parent, AccessMode::Read),
        "config allow_binaries {name} directory {} should be covered Read",
        parent.display()
    );
}
