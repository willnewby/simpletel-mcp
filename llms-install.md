# Installing simpletel-mcp

`simpletel-mcp` is a **stdio** Model Context Protocol server for
[simpletel](https://simpletel.dev), an OpenTelemetry backend for traces, logs,
and metrics. It ships inside the `simpletel` CLI — the command is
`simpletel mcp` — and is also published as an OCI image.

- MCP registry name: `io.github.willnewby/simpletel`
- Source repository: https://github.com/willnewby/simpletel-mcp
- Container image: `ghcr.io/willnewby/simpletel-mcp:latest`
- Transport: stdio (newline-delimited JSON-RPC 2.0), MCP protocol revision
  `2025-06-18`

It exposes four read-only tools: `get_traces`, `get_trace`, `verify`, and
`usage`.

## Prerequisites

Either:

- the `simpletel` CLI on the machine running the MCP client, or
- Docker (to run the container image).

And a simpletel endpoint plus a team reference:

- a **20-hex team id** (used verbatim, needs no extra credential), or
- a **friendly team name** (resolved read-only; also needs an admin token), or
- a logged-in config file (`~/.simpletel/config.toml`) produced by
  `simpletel login`.

## Option A — local CLI (recommended)

1. Install the CLI:

   ```sh
   curl -fsSL https://simpletel.dev/install | sh
   ```

   This installs `simpletel` to `~/.simpletel/bin/simpletel` after verifying the
   sha256 checksum. It never uses sudo and never prompts.

2. Sign in and select a team (skip if you already have a team id):

   ```sh
   simpletel login
   simpletel team create --name my-team
   ```

3. Register the server with the MCP client. The command is `simpletel mcp`; it
   accepts `--endpoint`, `--team`, `--admin-token`, and `--config`.

   Claude Code:

   ```sh
   claude mcp add simpletel -- ~/.simpletel/bin/simpletel mcp --team <20-hex-team-id>
   ```

   Any JSON-configured client (Claude Desktop, Cursor, Cline, Windsurf, …):

   ```json
   {
     "mcpServers": {
       "simpletel": {
         "command": "/Users/you/.simpletel/bin/simpletel",
         "args": ["mcp"],
         "env": {
           "SIMPLETEL_ENDPOINT": "https://simpletel.dev",
           "SIMPLETEL_TEAM": "<20-hex-team-id>"
         }
       }
     }
   }
   ```

## Option B — Docker

```sh
docker run -i --rm \
  -e SIMPLETEL_ENDPOINT=https://simpletel.dev \
  -e SIMPLETEL_TEAM=<20-hex-team-id> \
  ghcr.io/willnewby/simpletel-mcp:latest
```

As a JSON client entry:

```json
{
  "mcpServers": {
    "simpletel": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-e", "SIMPLETEL_ENDPOINT=https://simpletel.dev",
        "-e", "SIMPLETEL_TEAM=<20-hex-team-id>",
        "ghcr.io/willnewby/simpletel-mcp:latest"
      ]
    }
  }
}
```

Keep stdin open (`-i`) and do **not** allocate a TTY (`-t`): the transport is
stdio.

## Configuration

Connection precedence is flag > environment variable > config file > default.

| Setting | Flag | Environment | Config file | Default |
|---|---|---|---|---|
| Endpoint | `--endpoint` | `SIMPLETEL_ENDPOINT` | `endpoint` | `http://localhost:4318` |
| Team | `--team` | `SIMPLETEL_TEAM` | `current_team` | *(none)* |
| Admin token | `--admin-token` | `SIMPLETEL_ADMIN_TOKEN` | — | *(none)* |
| User token (`usage`) | — | `SIMPLETEL_TOKEN` | `auth` token | *(none)* |
| Config path | `--config` | `SIMPLETEL_CONFIG` | — | `~/.simpletel/config.toml` |

## Verify the install

After registering the server, ask the agent to list tools — it should see
`get_traces`, `get_trace`, `verify`, and `usage`. Calling `get_traces` with no
arguments lists the team's traces from the last hour; a team or credential
problem is reported as the tool's `isError` text.
