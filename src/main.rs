use anyhow::{Context, Result};
use clap::Parser;
use nu_mcp::{
    auth::run_credential_phase, cli::Cli, config::Config, mcp::run_server,
    security::build_capability_set,
};
use std::env;

fn main() -> Result<()> {
    // Initialize tracing subscriber for debug logging
    // Control log level with RUST_LOG env var (e.g., RUST_LOG=nu_mcp=debug)
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("nu_mcp=info")),
        )
        .init();

    let cli = Cli::parse();

    // Always include current directory, plus any additional paths
    let mut sandbox_directories = vec![env::current_dir()?];
    sandbox_directories.extend(cli.add_paths);

    let config = Config {
        tools_dir: cli.tools_dir,
        enable_nu: cli.enable_nu,
        sandbox_directories,
        block_network: cli.block_network,
        bypass_protection: cli.bypass_protection,
        read_only_paths: cli.read_only_paths,
        allow_binaries: cli.allow_binaries,
        env_credentials: cli.env_credentials,
        keyring_service: cli.keyring_service,
        disable_sandbox: cli.disable_sandbox,
    };

    // Build the capability set unless self-sandboxing is disabled. The default
    // path is fail-closed: the server must not run when the set cannot be built.
    let caps = if config.disable_sandbox {
        tracing::warn!(
            "self-sandboxing disabled by --disable-sandbox; server and child processes run unrestricted"
        );
        None
    } else {
        Some(build_capability_set(&config).context("failed to build sandbox capability set")?)
    };

    // Resolve the configured credentials while host access is still available:
    // the keystore backends spawn host-privileged CLIs (`op`, `bw`, `security`).
    // A failure is logged with its context chain and aborts: the server must not
    // start without the credentials it was configured to deliver.
    let secrets = run_credential_phase(&config, caps.as_ref())
        .inspect_err(|err| tracing::error!("credential phase failed: {err:#}"))?;

    // Child `nu` processes inherit this environment at spawn time, so the
    // secrets must be set on this process before any runtime starts workers.
    // SAFETY: single-threaded setup before spawning workers.
    unsafe {
        for secret in &secrets {
            std::env::set_var(secret.env_var.as_str(), secret.value.as_str());
        }
    }

    // Apply the sandbox to this process before the server starts. Child `nu`
    // processes inherit it. Application is irreversible and fail-closed: if the
    // sandbox cannot be applied, the server must not run.
    if let Some(caps) = caps.as_ref() {
        nono::Sandbox::apply_auto(caps).context("failed to apply sandbox")?;
    }

    let runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .context("failed to start tokio runtime")?;
    runtime.block_on(run_server(config))
}
