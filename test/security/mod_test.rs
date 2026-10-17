#[cfg(target_os = "macos")]
use super::grant_path_metadata_dirs_in;
#[cfg(any(target_os = "linux", target_os = "macos"))]
use super::library_dirs;
use super::{
    SYSTEM_READ_PATHS, USER_TOOLS_PATHS, build_capability_set, expand_home, find_in_path,
    find_in_path_in, grant_allow_binaries, grant_binary_access, system_write_paths,
};
use crate::config::Config;
use nono::{AccessMode, CapabilitySet};
use serial_test::serial;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

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
    let dir = std::env::temp_dir();
    let config = Config {
        sandbox_directories: vec![dir.clone()],
        ..Config::default()
    };
    let caps = build_capability_set(&config).unwrap();
    assert!(
        caps.fs_capabilities()
            .iter()
            .any(|c| c.original.as_path() == dir.as_path() && c.access == AccessMode::ReadWrite),
        "sandbox directory should be granted ReadWrite"
    );
}

#[test]
fn test_read_only_paths_granted_read_only() {
    let dir = std::env::temp_dir();
    let config = Config {
        read_only_paths: vec![dir.clone()],
        ..Config::default()
    };
    let caps = build_capability_set(&config).unwrap();
    assert!(
        caps.fs_capabilities()
            .iter()
            .any(|c| c.original.as_path() == dir.as_path() && c.access == AccessMode::Read),
        "read-only path should be granted Read"
    );
}

#[test]
fn test_tools_dir_granted_read_only() {
    let dir = std::env::temp_dir();
    let config = Config {
        tools_dir: Some(dir.clone()),
        ..Config::default()
    };
    let caps = build_capability_set(&config).unwrap();
    assert!(
        caps.fs_capabilities()
            .iter()
            .any(|c| c.original.as_path() == dir.as_path() && c.access == AccessMode::Read),
        "tools_dir should be granted Read"
    );
}

#[test]
fn test_bypass_protection_paths_granted_readwrite() {
    let dir = std::env::temp_dir();
    let config = Config {
        bypass_protection: vec![dir.clone()],
        ..Config::default()
    };
    let caps = build_capability_set(&config).unwrap();
    assert!(
        caps.fs_capabilities()
            .iter()
            .any(|c| c.original.as_path() == dir.as_path() && c.access == AccessMode::ReadWrite),
        "bypass-protection path should be granted ReadWrite"
    );
}

/// A [`MakeWriter`](tracing_subscriber::fmt::MakeWriter) that appends formatted
/// tracing output to a shared buffer so tests can assert on emitted warnings.
#[derive(Clone)]
struct CaptureWriter(Arc<Mutex<Vec<u8>>>);

impl std::io::Write for CaptureWriter {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        self.0.lock().expect("lock").extend_from_slice(buf);
        Ok(buf.len())
    }

    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}

impl<'a> tracing_subscriber::fmt::MakeWriter<'a> for CaptureWriter {
    type Writer = CaptureWriter;

    fn make_writer(&'a self) -> Self::Writer {
        self.clone()
    }
}

/// Run `f` with a capturing `WARN`-level subscriber and return the formatted
/// output.
fn capture_warnings<F: FnOnce()>(f: F) -> String {
    let buffer = Arc::new(Mutex::new(Vec::new()));
    let subscriber = tracing_subscriber::fmt()
        .with_writer(CaptureWriter(Arc::clone(&buffer)))
        .with_ansi(false)
        .with_max_level(tracing::Level::WARN)
        .finish();
    tracing::subscriber::with_default(subscriber, f);
    let bytes = buffer.lock().expect("lock").clone();
    String::from_utf8(bytes).expect("utf8")
}

#[test]
#[serial]
fn test_expand_home_config_paths() {
    let home = TempDir::new("expand-home-config");
    let sandbox = home.path().join("sandbox");
    let read_only = home.path().join("read-only");
    let tools = home.path().join("tools");
    let bypass = home.path().join("bypass");
    for dir in [&sandbox, &read_only, &tools, &bypass] {
        std::fs::create_dir_all(dir).expect("create config dir");
    }

    let saved = std::env::var_os("HOME");
    // SAFETY: `#[serial]` prevents concurrent env mutation in this process.
    unsafe { std::env::set_var("HOME", home.path()) };
    let config = Config {
        sandbox_directories: vec![PathBuf::from("~/sandbox")],
        read_only_paths: vec![PathBuf::from("~/read-only")],
        tools_dir: Some(PathBuf::from("~/tools")),
        bypass_protection: vec![PathBuf::from("~/bypass")],
        ..Config::default()
    };
    let caps = build_capability_set(&config).expect("build");
    if let Some(prev) = saved {
        // SAFETY: restoring the value captured above.
        unsafe { std::env::set_var("HOME", prev) };
    } else {
        // SAFETY: restoring the absence captured above.
        unsafe { std::env::remove_var("HOME") };
    }

    assert!(
        caps.fs_capabilities()
            .iter()
            .any(|c| c.original.as_path() == sandbox.as_path()
                && c.access == AccessMode::ReadWrite),
        "~/sandbox should be expanded and granted ReadWrite"
    );
    assert!(
        caps.fs_capabilities()
            .iter()
            .any(|c| c.original.as_path() == read_only.as_path() && c.access == AccessMode::Read),
        "~/read-only should be expanded and granted Read"
    );
    assert!(
        caps.fs_capabilities()
            .iter()
            .any(|c| c.original.as_path() == tools.as_path() && c.access == AccessMode::Read),
        "~/tools should be expanded and granted Read"
    );
    assert!(
        caps.fs_capabilities()
            .iter()
            .any(|c| c.original.as_path() == bypass.as_path() && c.access == AccessMode::ReadWrite),
        "~/bypass should be expanded and granted ReadWrite"
    );
}

#[test]
#[serial]
fn test_expand_home_config_path_missing_warns() {
    let home = TempDir::new("expand-home-missing");
    let missing = home.path().join("does-not-exist");

    let saved = std::env::var_os("HOME");
    // SAFETY: `#[serial]` prevents concurrent env mutation in this process.
    unsafe { std::env::set_var("HOME", home.path()) };
    let config = Config {
        sandbox_directories: vec![PathBuf::from("~/does-not-exist")],
        ..Config::default()
    };
    let output = capture_warnings(|| {
        let caps = build_capability_set(&config).expect("build");
        assert!(
            !caps
                .fs_capabilities()
                .iter()
                .any(|c| c.original.as_path() == missing.as_path()),
            "missing expanded path should not be granted"
        );
    });
    if let Some(prev) = saved {
        // SAFETY: restoring the value captured above.
        unsafe { std::env::set_var("HOME", prev) };
    } else {
        // SAFETY: restoring the absence captured above.
        unsafe { std::env::remove_var("HOME") };
    }

    assert!(
        output.contains("does not exist or is not a directory"),
        "expected a warning for the missing config path, got: {output}"
    );
}

#[test]
#[serial]
fn test_expand_home_config_path_without_home_warns() {
    let saved = std::env::var_os("HOME");
    // SAFETY: `#[serial]` prevents concurrent env mutation in this process.
    unsafe { std::env::remove_var("HOME") };
    let config = Config {
        sandbox_directories: vec![PathBuf::from("~/sandbox")],
        ..Config::default()
    };
    let output = capture_warnings(|| {
        let caps = build_capability_set(&config).expect("build");
        assert!(
            !caps
                .fs_capabilities()
                .iter()
                .any(|c| c.original.as_path() == Path::new("~/sandbox")),
            "unexpanded ~/ path should not be granted"
        );
    });
    if let Some(prev) = saved {
        // SAFETY: restoring the value captured above.
        unsafe { std::env::set_var("HOME", prev) };
    }

    assert!(
        output.contains("HOME is not set"),
        "expected a warning when HOME is unset, got: {output}"
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

#[cfg(target_os = "macos")]
#[test]
fn test_system_read_paths_grant_etc() {
    let caps = build_capability_set(&Config::default()).unwrap();
    for path in ["/etc", "/private/etc"] {
        let p = Path::new(path);
        assert!(p.is_dir(), "{path} should exist on macOS");
        assert!(
            caps.fs_capabilities()
                .iter()
                .any(|c| c.original.as_path() == p && c.access == AccessMode::Read),
            "system path {path} should be granted Read"
        );
    }
}

#[test]
fn test_system_readwrite_paths_granted_readwrite() {
    let caps = build_capability_set(&Config::default()).unwrap();
    for path in system_write_paths() {
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
#[serial]
fn test_tmpdir_path_granted_readwrite() {
    let dir = TempDir::new("tmpdir-write");
    let saved = std::env::var_os("TMPDIR");
    // SAFETY: `#[serial]` prevents concurrent env mutation in this process.
    unsafe { std::env::set_var("TMPDIR", dir.path()) };
    let caps = build_capability_set(&Config::default()).unwrap();
    if let Some(prev) = saved {
        // SAFETY: restoring the value captured above.
        unsafe { std::env::set_var("TMPDIR", prev) };
    } else {
        // SAFETY: restoring the absence captured above.
        unsafe { std::env::remove_var("TMPDIR") };
    }
    assert!(
        caps.fs_capabilities()
            .iter()
            .any(|c| c.original.as_path() == dir.path() && c.access == AccessMode::ReadWrite),
        "TMPDIR path {} should be granted ReadWrite",
        dir.path().display()
    );
}

#[test]
#[serial]
fn test_user_tools_paths_granted_read() {
    let home = TempDir::new("user-tools-home");
    for path in USER_TOOLS_PATHS {
        let sub = path
            .strip_prefix("~/")
            .expect("user_tools path should start with ~/");
        std::fs::create_dir_all(home.path().join(sub)).expect("create user_tools dir");
    }

    let saved = std::env::var_os("HOME");
    // SAFETY: `#[serial]` prevents concurrent env mutation in this process.
    unsafe { std::env::set_var("HOME", home.path()) };
    let mut expanded = Vec::new();
    for path in USER_TOOLS_PATHS {
        if let Some(path) = expand_home(path) {
            expanded.push(path);
        }
    }
    let caps = build_capability_set(&Config::default()).unwrap();
    if let Some(prev) = saved {
        // SAFETY: restoring the value captured above.
        unsafe { std::env::set_var("HOME", prev) };
    } else {
        // SAFETY: restoring the absence captured above.
        unsafe { std::env::remove_var("HOME") };
    }

    assert_eq!(
        expanded.len(),
        USER_TOOLS_PATHS.len(),
        "every user_tools path should expand when HOME is set"
    );
    for path in &expanded {
        let canonical = path.canonicalize().expect("canonicalize user_tools path");
        assert!(
            caps.path_covered_with_access(&canonical, AccessMode::Read),
            "user_tools path {} should be covered Read",
            canonical.display()
        );
    }
}

#[test]
fn test_missing_paths_are_skipped() {
    let missing = PathBuf::from("/nonexistent-nu-mcp-test-xyz/subdir");
    assert!(!missing.exists());
    let config = Config {
        sandbox_directories: vec![missing.clone()],
        ..Config::default()
    };
    let caps = build_capability_set(&config).unwrap();
    assert!(
        !caps
            .fs_capabilities()
            .iter()
            .any(|c| c.original == missing || c.resolved == missing),
        "missing path should not be granted"
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
