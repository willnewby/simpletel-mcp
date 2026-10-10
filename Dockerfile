# syntax=docker/dockerfile:1

# simpletel-mcp — stdio MCP server for simpletel.
#
# The `simpletel` CLI is a static binary published at https://simpletel.dev.
# Stage 1 fetches it with the official installer (sha256-verified); stage 2 is
# a minimal distroless runtime that only carries the binary. The result speaks
# MCP over stdin/stdout as `simpletel mcp`.
#
# The CLI version is not pinned here on purpose: a rebuild always picks up the
# currently-served release (read from /static/bin/VERSION by the installer), and
# the publish workflow tags the image with that same version. To build a
# specific release, point SIMPLETEL_BASE at a mirror that serves it.

FROM debian:stable-slim AS builder
ARG SIMPLETEL_BASE=https://simpletel.dev
ENV HOME=/root
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl; \
    rm -rf /var/lib/apt/lists/*
# Install into /out (the installer verifies the archive's sha256 and never
# touches anything outside the target dir).
RUN curl -fsSL "$SIMPLETEL_BASE/install" | sh -s -- --dir /out
# Fail the build if the binary isn't runnable on the target architecture.
RUN /out/simpletel --version

FROM gcr.io/distroless/static-debian12
LABEL io.modelcontextprotocol.server.name="io.github.willnewby/simpletel"
COPY --from=builder /out/simpletel /simpletel
ENTRYPOINT ["/simpletel","mcp"]
