# Security

## Sandbox Model

nu-mcp enforces filesystem and network access with nono, a kernel-enforced sandbox. There is no string-based command validation: the kernel is the single security boundary.

The sandbox is applied to the nu-mcp server process at startup (`nono::Sandbox::apply_auto`). Child `nu` processes inherit it. Application is irreversible and fail-closed — if the sandbox cannot be applied, the server does not start.

## Kernel Enforcement

nono uses the platform's native sandboxing mechanism:

- **Linux** — Landlock
- **macOS** — Seatbelt

Both are additive-restrictive: a process can only access what every enclosing sandbox allows. When nu-mcp runs inside an outer sandbox (container, VM, another nono instance), the two compose — access requires permission from both.

## Sandbox Configuration

The current working directory is always granted read-write access. Additional access is granted with CLI flags:

| Flag | Effect |
|------|--------|
| `--add-path=PATH` | Grant read-write access to an additional directory (repeatable) |
| `--add-read-path=PATH` | Grant read-only access to an additional directory (repeatable) |
| `--block-network` | Block all network access |
| `--bypass-protection=PATH` | Unblock a sensitive path (repeatable) |
| `--disable-sandbox` | Do not build or apply a capability set at all |

Example:

```bash
# From /home/user/project
nu-mcp --add-path=/tmp --add-read-path=/var/log --block-network
```

**Accessible:**
- `/home/user/project/**` (current directory, read-write)
- `/tmp/**` (read-write)
- `/var/log/**` (read-only)

**Blocked:**
- `/etc/passwd`
- `/home/user/other-project/**`

## System Path Grants

The nono library does not grant system paths automatically. nu-mcp grants read access to the paths `nu` needs to start and run commands:

- **Linux** — `/usr`, `/lib`, `/bin`, `/etc/ssl`
- **macOS** — `/System/Library`, `/Library`, `/usr/lib`, `/usr/share/zoneinfo`, `/etc/ssl`, `/private/var/db/dyld`, `/var`

`/tmp` is granted read-write on every platform. Paths that do not exist on the host are skipped.

### Auto-detected `nu` paths

The fixed system path list does not cover `nu` installed outside it — for example Nix (`/nix/store/<hash>-nushell-<version>/bin/nu`) or Homebrew (`/opt/homebrew/bin/nu`). At startup, nu-mcp resolves `nu` by walking `$PATH` and grants read access to the binary's parent directory. It then enumerates the binary's dynamic library dependencies (`otool -L` on macOS, `ldd` on Linux) and grants read access to the parent directory of each dependency outside the system path list. Nix store paths change on every package update, so detection runs at startup rather than using a fixed list.

If `nu` is not found, or `otool`/`ldd` fails, nu-mcp logs a warning and continues without the corresponding grants.

## Sensitive Paths

nono blocks sensitive paths by default. Use `--bypass-protection=PATH` to unblock a path the user explicitly opts into. The bypassed path is granted read-write access.

## Environment Credentials

`--env-credential` values are resolved at startup and written into the server process environment. Child processes inherit that environment:

- Every `run` tool call spawns `nu` without environment filtering (`src/execution/nushell.rs`)
- Every extension tool call spawns `nu` without environment filtering (`src/tools/execution.rs`)

The injected variables are therefore readable by every command the server executes. They are not scoped to one tool or one call. Configure credentials only for commands you trust.

`--keyring-service` selects the keyring service used for bare credential names (default `nono`). Scheme references carry their own addressing: `keyring://service/account`, `op://vault/item/field`, `bw://item[/field]`, `apple-password://server/account`, `file:///absolute/path`, `env://VAR`.

The credential phase runs before the sandbox is applied. The secret brokers (`op`, `bw`, `security`), keyring access, and credential file reads need host access that the sandbox would deny, so they are host-privileged startup helpers by design. The capability set is built after the phase and applied to the server process, and the already-set environment is what children inherit.

Credentials are injected as environment variables only. Proxy injection — handing a secret to a child through a socket or a proxy process — is explicitly out of scope.

A reference that cannot be resolved logs an error and aborts startup: the server does not start with a missing credential.

## Disabling the Sandbox

`--disable-sandbox` starts the server without building or applying a capability set. It exists for the case where nu-mcp already runs inside a sandbox (container, VM, another sandbox launcher) and a second sandbox is undesirable. The server logs a warning at startup.

Consequences:

- The server process and every child `nu` process run unrestricted
- The capability set is never built, so `--block-network`, `--add-path`, `--add-read-path`, `--bypass-protection`, and `--allow-binary` have no effect. The flag disables the whole capability layer, not just filesystem restrictions
- Injected credential environment variables (see [Environment Credentials](#environment-credentials)) are readable by every child process

The default remains fail-closed: without the flag, a capability set that cannot be built or applied aborts startup.

## Error Behavior

Access outside the granted paths fails at the kernel boundary. The `nu` process receives `EACCES` (permission denied), which is surfaced in the tool result. nu-mcp does not pre-validate commands or rewrite errors.

## Tool Security

- Extension tools run in the same sandbox as the `run` tool — one capability set is built from one configuration
- Tools can access environment variables
- Tools can spawn processes within the sandbox
- Review tool implementations before deployment

## Disclaimer

**USE AT YOUR OWN RISK.** This software is provided "as is" without warranty. Users are responsible for:
- Understanding security implications
- Proper sandbox configuration
- Testing in non-production environments
- Monitoring and securing systems
- All consequences from command execution