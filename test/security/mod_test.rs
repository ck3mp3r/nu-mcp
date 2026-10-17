#[cfg(target_os = "macos")]
use super::grant_path_metadata_dirs_in;
#[cfg(any(target_os = "linux", target_os = "macos"))]
use super::library_dirs;
use super::{
    SYSTEM_READ_PATHS, SYSTEM_READWRITE_PATHS, build_capability_set, find_in_path, find_in_path_in,
    grant_allow_binaries, grant_binary_access,
};
use crate::config::Config;
use nono::{AccessMode, CapabilitySet};
use std::path::{Path, PathBuf};

/// A directory that exists and is not a system path or `/tmp`, so tests can
/// distinguish `Read` from `ReadWrite` grants.
fn neutral_dir() -> PathBuf {
    std::env::current_dir()
        .expect("current dir")
        .canonicalize()
        .expect("canonicalize current dir")
}

/// A unique temporary directory, removed when dropped.
struct TempDir(PathBuf);

impl TempDir {
    fn new(label: &str) -> Self {
        let dir = std::env::temp_dir().join(format!("nu-mcp-{label}-{}", std::process::id()));
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

#[test]
fn test_sandbox_directories_granted_readwrite() {
    let dir = neutral_dir();
    let config = Config {
        sandbox_directories: vec![dir.clone()],
        ..Config::default()
    };
    let caps = build_capability_set(&config).unwrap();
    assert!(
        caps.path_covered_with_access(&dir, AccessMode::ReadWrite),
        "sandbox directory should be covered ReadWrite"
    );
}

#[test]
fn test_read_only_paths_granted_read_only() {
    let dir = neutral_dir();
    let config = Config {
        read_only_paths: vec![dir.clone()],
        ..Config::default()
    };
    let caps = build_capability_set(&config).unwrap();
    assert!(
        caps.path_covered_with_access(&dir, AccessMode::Read),
        "read-only path should be covered Read"
    );
    assert!(
        !caps.path_covered_with_access(&dir, AccessMode::ReadWrite),
        "read-only path should not be covered ReadWrite"
    );
}

#[test]
fn test_tools_dir_granted_read_only() {
    let dir = neutral_dir();
    let config = Config {
        tools_dir: Some(dir.clone()),
        ..Config::default()
    };
    let caps = build_capability_set(&config).unwrap();
    assert!(
        caps.path_covered_with_access(&dir, AccessMode::Read),
        "tools_dir should be covered Read"
    );
    assert!(
        !caps.path_covered_with_access(&dir, AccessMode::ReadWrite),
        "tools_dir should not be covered ReadWrite"
    );
}

#[test]
fn test_bypass_protection_paths_granted_readwrite() {
    let dir = neutral_dir();
    let config = Config {
        bypass_protection: vec![dir.clone()],
        ..Config::default()
    };
    let caps = build_capability_set(&config).unwrap();
    assert!(
        caps.path_covered_with_access(&dir, AccessMode::ReadWrite),
        "bypass-protection path should be covered ReadWrite"
    );
}

#[test]
fn test_system_read_paths_granted_read() {
    let caps = build_capability_set(&Config::default()).unwrap();
    let mut checked = 0;
    for path in SYSTEM_READ_PATHS {
        let p = Path::new(path);
        if p.is_dir() {
            assert!(
                caps.fs_capabilities()
                    .iter()
                    .any(|c| c.original.as_path() == p && c.access == AccessMode::Read),
                "system path {path} should be granted Read"
            );
            checked += 1;
        }
    }
    assert!(checked > 0, "expected at least one system path to exist");
}

#[test]
fn test_system_readwrite_paths_granted_readwrite() {
    let caps = build_capability_set(&Config::default()).unwrap();
    for path in SYSTEM_READWRITE_PATHS {
        let p = Path::new(path);
        if p.is_dir() {
            assert!(
                caps.fs_capabilities()
                    .iter()
                    .any(|c| c.original.as_path() == p && c.access == AccessMode::ReadWrite),
                "path {path} should be granted ReadWrite"
            );
        }
    }
}

#[test]
fn test_missing_paths_are_skipped() {
    let missing = neutral_dir().join("nu-mcp-does-not-exist-xyz");
    assert!(!missing.exists());
    let config = Config {
        sandbox_directories: vec![missing.clone()],
        ..Config::default()
    };
    let caps = build_capability_set(&config).unwrap();
    assert!(
        !caps.path_covered(&missing),
        "missing path should not be covered"
    );
}

#[test]
fn test_network_allowed_by_default() {
    let caps = build_capability_set(&Config::default()).unwrap();
    assert!(
        !caps.is_network_blocked(),
        "network should be allowed by default"
    );
}

#[test]
fn test_block_network_flag_blocks_network() {
    let config = Config {
        block_network: true,
        ..Config::default()
    };
    let caps = build_capability_set(&config).unwrap();
    assert!(caps.is_network_blocked(), "network should be blocked");
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
    let otool = "/nix/store/abc-nushell/bin/nu:\n\t/usr/lib/libSystem.B.dylib (compatibility version 1.0.0)\n\t/nix/store/xyz-libiconv/lib/libiconv.2.dylib (compatibility version 7.0.0)\n";
    assert_eq!(
        library_dirs(otool),
        vec![PathBuf::from("/nix/store/xyz-libiconv/lib")]
    );

    let ldd = "\tlinux-vdso.so.1 (0x00007fff)\n\tlibgcc_s.so.1 => /nix/store/aaa-gcc/lib/libgcc_s.so.1 (0x00007f)\n\tlibc.so.6 => /nix/store/bbb-glibc/lib/libc.so.6 (0x00007f)\n";
    assert_eq!(
        library_dirs(ldd),
        vec![
            PathBuf::from("/nix/store/aaa-gcc/lib"),
            PathBuf::from("/nix/store/bbb-glibc/lib"),
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
            let parent = binary.parent()?.canonicalize().ok()?;
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
