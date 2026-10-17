use super::{SYSTEM_READ_PATHS, SYSTEM_READWRITE_PATHS, build_capability_set};
use crate::config::Config;
use nono::AccessMode;
use std::path::{Path, PathBuf};

/// A directory that exists and is not a system path or `/tmp`, so tests can
/// distinguish `Read` from `ReadWrite` grants.
fn neutral_dir() -> PathBuf {
    std::env::current_dir()
        .expect("current dir")
        .canonicalize()
        .expect("canonicalize current dir")
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
