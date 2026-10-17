# Security Module - Capability Set Builder

## Overview

This module builds a nono [`CapabilitySet`] from the sandbox configuration. The
capability set is applied to the nu-mcp server process at startup (see
`src/main.rs`); child `nu` processes inherit it. Kernel enforcement (Landlock on
Linux, Seatbelt on macOS) is the single security boundary. There is no
string-based command validation and no path cache.

## `build_capability_set`

`build_capability_set(config: &Config) -> nono::Result<CapabilitySet>`
(`src/security/mod.rs`) translates the `Config` struct into a capability set:

| Config field | Access granted |
|--------------|----------------|
| `sandbox_directories` | read-write |
| `read_only_paths` | read |
| `tools_dir` (when set) | read |
| `bypass_protection` | read-write (unblocks a sensitive path) |
| `block_network` (when true) | all network access blocked |

Paths that do not exist are skipped. `CapabilitySet::allow_path` rejects missing
paths, and the system path list differs between hosts, so the builder checks
`Path::is_dir` before granting access.

## System Path Grants

The nono library does not grant system paths automatically. nu-mcp grants read
access to the paths `nu` needs to start and run commands:

- **Linux** — `/usr`, `/lib`, `/bin`, `/etc/ssl`
- **macOS** — `/System/Library`, `/Library`, `/usr/lib`, `/usr/share/zoneinfo`, `/etc/ssl`, `/private/var/db/dyld`, `/var`
- **Other platforms** — no system paths

`/tmp` is granted read-write on every platform.

## Platform-Specific Behavior

System path grants are selected at compile time with `#[cfg(target_os = ...)]`.
The kernel mechanism differs by platform:

- **Linux** — Landlock
- **macOS** — Seatbelt

Both are additive-restrictive: a process can only access what every enclosing
sandbox allows. When nu-mcp runs inside an outer sandbox (container, VM, another
nono instance), the two compose.

## Error Behavior

Access outside the granted paths fails at the kernel boundary. The `nu` process
receives `EACCES` (permission denied), which is surfaced in the tool result.
nu-mcp does not pre-validate commands or rewrite errors.

## References

- Implementation: `src/security/mod.rs`
- Tests: `test/security/mod_test.rs`
- User docs: `docs/security.md`
