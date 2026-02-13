# =============================================================================
# Postman CLI — Production Docker Image
# =============================================================================
# Purpose : Run Postman CLI regression tests in an isolated, reproducible
#           container. No host-level installation of Postman CLI required.
#
# Base    : ubuntu:22.04 (LTS — stable, widely-used in CI/CD pipelines)
# Entrypoint : postman (all CLI sub-commands passed as CMD / docker run args)
# =============================================================================

FROM --platform=linux/amd64 ubuntu:22.04

# ── 1. System dependencies ──────────────────────────────────────────────────
# curl          — required by the Postman CLI installer script
# ca-certificates — required for HTTPS connections to Postman API + cloud
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# ── 2. Install Postman CLI (official installer) ─────────────────────────────
RUN curl -o- "https://dl-cli.pstmn.io/install/linux64.sh" | sh

# ── 3. Working directory ────────────────────────────────────────────────────
WORKDIR /app

# ── 4. Create artifacts directory (report output target) ────────────────────
RUN mkdir -p /app/artifacts

# ── 5. Runtime environment variables ────────────────────────────────────────
# The following variables are injected at runtime via `docker run -e`:
#   POSTMAN_API_KEY  — Postman API key (sensitive — never bake into image)
#   COLLECTION_ID    — Postman Collection UID
#   ENVIRONMENT_ID   — Postman Environment UID
#   BASE_URL         — Target API base URL
#   AUTH_TOKEN       — Bearer token (sensitive — never bake into image)
# No ENV declarations here — secrets must NOT be stored in image layers.

# ── 6. Entrypoint ───────────────────────────────────────────────────────────
# The container behaves like the `postman` binary itself.
# Usage:  docker run <image> login --with-api-key $KEY
#         docker run <image> collection run <id> ...
ENTRYPOINT ["postman"]
