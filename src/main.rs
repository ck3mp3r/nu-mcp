use serde::Deserialize;
use std::env;
use std::fs::read_to_string;
use std::io::Result;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{TcpListener, TcpStream};
use tokio::process::Command;

#[derive(Deserialize, Clone, Default)]
struct MCPConfig {
    allow_sudo: bool,
    allowed_commands: Option<Vec<String>>,
    denied_commands: Option<Vec<String>>,
}

fn load_config(path: &str) -> MCPConfig {
    match read_to_string(path) {
        Ok(config_str) => match serde_json::from_str(&config_str) {
            Ok(cfg) => cfg,
            Err(_) => {
                eprintln!("Warning: Invalid config file. Using defaults.");
                MCPConfig::default()
            }
        },
        Err(_) => {
            eprintln!("Warning: Config file not found. Using defaults.");
            MCPConfig::default()
        }
    }
}

fn is_command_allowed(cmd: &str, config: &MCPConfig) -> bool {
    if !config.allow_sudo && cmd.contains("sudo") {
        return false;
    }
    if let Some(allowed) = &config.allowed_commands {
        if !allowed.is_empty() && !allowed.iter().any(|a| cmd.starts_with(a)) {
            return false;
        }
    }
    if let Some(denied) = &config.denied_commands {
        if denied.iter().any(|d| cmd.starts_with(d)) {
            return false;
        }
    }
    true
}

async fn handle_client(mut socket: TcpStream, config: MCPConfig) {
    let (reader, mut writer) = socket.split();
    let mut reader = BufReader::new(reader);
    let mut line = String::new();

    loop {
        line.clear();
        let bytes_read = reader.read_line(&mut line).await.unwrap();
        if bytes_read == 0 {
            break; // Connection closed
        }

        let command = line.trim();
        if command.is_empty() {
            continue;
        }

        if !is_command_allowed(command, &config) {
            let msg = "Error: Command not allowed by server configuration.\n";
            writer.write_all(msg.as_bytes()).await.unwrap();
            continue;
        }

        // Run Nushell command
        let output = Command::new("nu").arg("-c").arg(command).output().await;

        match output {
            Ok(output) => {
                if !output.stdout.is_empty() {
                    writer.write_all(&output.stdout).await.unwrap();
                }
                if !output.stderr.is_empty() {
                    writer.write_all(&output.stderr).await.unwrap();
                }
            }
            Err(e) => {
                let err_msg = format!("Failed to run Nushell: ${e}\n");
                writer.write_all(err_msg.as_bytes()).await.unwrap();
            }
        }
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let args: Vec<String> = env::args().collect();
    let config = if args.len() > 1 {
        let config_path = &args[1];
        println!("Loaded config from: ${config_path}");
        load_config(config_path)
    } else {
        println!("No config file provided. Using sane defaults.");
        MCPConfig::default()
    };
    let listener = TcpListener::bind("127.0.0.1:7878").await?;

    loop {
        let (socket, _) = listener.accept().await?;
        let config = config.clone();
        tokio::spawn(async move {
            handle_client(socket, config).await;
        });
    }
}
