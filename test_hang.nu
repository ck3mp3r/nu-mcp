#!/usr/bin/env nu

# Test script to reproduce the hang issue with path-like arguments
# This script will test the command that hangs in production

print "Testing command with path-like argument..."
print "Command: echo 'Command with /api/v1/pods path-like argument'"

# Test with MCP server via run_nushell tool
# This should hang if the bug is present
let result = (
  echo '{"command": "echo \"Command with /api/v1/pods path-like argument\""}'
  | save -f /tmp/test_command.json
)

print "\nTest command saved to /tmp/test_command.json"
print "To test manually with MCP server:"
print "1. Start server: RUST_LOG=nu_mcp=trace cargo run -- --enable-run-nushell"
print "2. In another terminal, send MCP request with the command above"
print ""
print "Watch for hang in trace output - should see where validation stops"
