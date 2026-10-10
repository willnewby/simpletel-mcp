# simpletel-mcp

> Model Context Protocol server for [simpletel](https://simpletel.dev) — ask your
> coding agent *"what just happened?"* and let it read the OpenTelemetry traces,
> logs, metrics, and account usage of your running services.

`simpletel mcp` is a **stdio** MCP server built into the `simpletel` CLI. It
speaks newline-delimited JSON-RPC 2.0 on stdin/stdout (MCP protocol revision
`2025-06-18`) and exposes simpletel's read commands as native agent tools. It is
a single static binary: no runtime, no dependencies, no background service.

- One-line install of the CLI: `curl -fsSL https://simpletel.dev/install | sh`
- Run it as `simpletel mcp`
- Or use the container: `ghcr.io/willnewby/simpletel-mcp`
- Registry name: `io.github.willnewby/simpletel`

---

## Tools

The server advertises four tools. Every tool returns text (the JSON document the
matching CLI command produces), and tool-side failures come back as a normal
result with `isError: true` — a tool call never breaks the session.

| Tool | Arguments | What it does |
|---|---|---|
| `get_traces` | `since` (default `1h`), `service`, `errors_only`, `min_duration`, `limit` | Lists this team's traces newest-first. The JSON document `simpletel get traces --format json` produces. Use it to find a failing or slow request. |
| `get_trace` | `trace_id` (required) | Fetches one trace in full — spans, span events, and correlated log records. The JSON document `simpletel get trace <id> --format json` produces. |
| `verify` | `service` (required), `timeout` (default `60s`) | Runs the `simpletel verify` onboarding check: polls until `service` has a fresh trace carrying spans from a library instrumentation. Returns the rung report and the exit status (`0` verified, `1` deadline miss). A deadline miss is a completed check, not a tool error. |
| `usage` | *(none)* | Shows the account's plan, month-to-date records, allowance, and spend cap. The JSON document `simpletel usage --format json` produces. Account-scoped (needs a logged-in user token). |

`get_traces`, `get_trace`, and `verify` are **team-scoped**; `usage` is
**account-scoped**.

---

## Authentication and team resolution

The server resolves one connection at startup, using the same precedence as
every other simpletel read command: **flag > environment variable > config file
> default**.

| Setting | Flag | Environment | Config file | Default |
|---|---|---|---|---|
| Endpoint | `--endpoint` | `SIMPLETEL_ENDPOINT` | `endpoint` | `http://localhost:4318` |
| Team | `--team` | `SIMPLETEL_TEAM` | `current_team` | *(none)* |
| Admin token | `--admin-token` | `SIMPLETEL_ADMIN_TOKEN` | — | *(none)* |
| User token (for `usage`) | — | `SIMPLETEL_TOKEN` | `auth` token | *(none)* |
| Config path | `--config` | `SIMPLETEL_CONFIG` | — | `~/.simpletel/config.toml` |

- The config file is `~/.simpletel/config.toml`, written by `simpletel login`
  and `simpletel team` (mode `0600`). `simpletel login` signs you in with
  GitHub; `simpletel team create` / `simpletel team use` set the current team.
- `--team` accepts either a **20-hex team id** — used verbatim, no token needed
  — or a **friendly name**. A name is *resolved only, never created*, and needs
  an admin token to look it up.
- `usage` additionally needs a user token: run `simpletel login`, or set
  `SIMPLETEL_TOKEN` (a `stk_…` token).

If the team is missing or wrong the server still answers `initialize` and
`tools/list`, so the client sees the tool catalog; each team-scoped call then
reports the problem as its own `isError` result.

> Nothing is ever sent to simpletel by this server beyond the read requests the
> tools make to the endpoint you configure. Diagnostics go to **stderr**; stdout
> carries protocol messages only.

---

## Install

### 1. Install the CLI

```sh
curl -fsSL https://simpletel.dev/install | sh
```

Installs `simpletel` into `~/.simpletel/bin/` (verify the sha256; no sudo,
never prompts). Then sign in and create/select a team:

```sh
simpletel login            # GitHub device flow
simpletel team create --name my-team
```

### 2. Register the server with your client

The MCP subcommand is `simpletel mcp`. It takes the connection flags
`--endpoint`, `--team`, `--admin-token`, and `--config`.

**Claude Code**

```sh
# by 20-hex team id (no extra credentials needed)
claude mcp add simpletel -- ~/.simpletel/bin/simpletel mcp --team <20-hex-team-id>

# or rely on the logged-in config file (~/.simpletel/config.toml)
claude mcp add simpletel -- ~/.simpletel/bin/simpletel mcp
```

Pass connection values as environment instead with `--env`:

```sh
claude mcp add simpletel \
  --env SIMPLETEL_ENDPOINT=https://simpletel.dev \
  --env SIMPLETEL_TEAM=<20-hex-team-id> \
  -- ~/.simpletel/bin/simpletel mcp
```

**Claude Desktop / any JSON-configured client** (`claude_desktop_config.json`,
Cursor, Cline, Windsurf, …):

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

If you are logged in locally you can drop `env` and the `command` will read
`~/.simpletel/config.toml`. In a sandboxed client that cannot read your home
directory, pass the values through `env` (or `--env` / `--router` equivalents)
instead.

---

## Docker

The image bundles the CLI and runs `simpletel mcp`. It is built for
`linux/amd64` and `linux/arm64`:

```sh
docker run -i --rm ghcr.io/willnewby/simpletel-mcp:latest
```

The container starts with **no credentials**. Provide them either by mounting
the config file or through environment variables (recommended — nothing is
written to the image).

Mount an existing config file (read-only). The image runs as the distroless
`nonroot` user, whose home is `/home/nonroot`:

```sh
docker run -i --rm \
  -v "$HOME/.simpletel/config.toml:/home/nonroot/.simpletel/config.toml:ro" \
  ghcr.io/willnewby/simpletel-mcp:latest
```

Or pass everything through the environment:

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

The MCP transport is **stdio**, so `-i` (keep stdin open) is required and you
must not add `-t`.

---

## Configuration reference

```
simpletel mcp [--endpoint URL] [--team <id-or-name>] [--admin-token TOKEN] [--config PATH]
```

| Variable | Purpose |
|---|---|
| `SIMPLETEL_ENDPOINT` | Server base URL — no `/v1/traces` suffix (default `http://localhost:4318`). |
| `SIMPLETEL_TEAM` | 20-hex team id, or a friendly name (name needs an admin token). |
| `SIMPLETEL_ADMIN_TOKEN` | Token used to resolve a team *name*; not needed for a 20-hex id. |
| `SIMPLETEL_TOKEN` | User token (`stk_…`) used by the `usage` tool. |
| `SIMPLETEL_CONFIG` | Config file path (default `~/.simpletel/config.toml`). |

---

## Limitations

- **stdio only.** `simpletel mcp` is launched as a subprocess by the client; it
  is not an HTTP/SSE endpoint.
- **Read-only.** The tools query traces, usage, and onboarding state. They do
  not ingest data or change account settings.
- **The host CLI is required** unless you use the container. The `simpletel`
  binary is fetched at build time by the `Dockerfile`; the repo ships no binary
  of its own — see `Dockerfile` for the build.
- **Windows** is not a first-class target of the one-line installer; use the
  Docker image or WSL.

---

## Repository contents

| File | Purpose |
|---|---|
| `Dockerfile` | Builds the stdio image from the published CLI. |
| `server.json` | [Official MCP Registry](https://registry.modelcontextprotocol.io) manifest (OCI package). CI rewrites the version/tag at publish time. |
| `glama.json` | Maintainer metadata for [Glama](https://glama.ai/mcp/servers) auto-indexing. |
| `llms-install.md` | Install instructions for LLM agents / directory crawlers. |
| `.github/workflows/publish.yml` | Builds and pushes `ghcr.io/willnewby/simpletel-mcp` and publishes to the registry. |

## License

MIT — see [LICENSE](LICENSE).
