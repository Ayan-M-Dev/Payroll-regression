#!/usr/bin/env bash
# =============================================================================
# run-tests.sh — Orchestrates Postman CLI inside Docker
# =============================================================================
# This script builds the Docker image and runs the Postman regression suite
# entirely inside a container. No host-level Postman CLI installation needed.
#
# Prerequisites:
#   - Docker installed and running on the host
#   - The following environment variables exported in your shell:
#       POSTMAN_API_KEY, COLLECTION_ID, ENVIRONMENT_ID, BASE_URL, AUTH_TOKEN
#
# Usage:
#   chmod +x run-tests.sh
#   export POSTMAN_API_KEY="PMAK-xxxxxxxx"
#   export COLLECTION_ID="12345678-abcd-efgh-ijkl-000000000000"
#   export ENVIRONMENT_ID="12345678-abcd-efgh-ijkl-111111111111"
#   export BASE_URL="https://staging-api.example.com"
#   export AUTH_TOKEN="Bearer eyJhbGciOi..."
#   ./run-tests.sh
# =============================================================================

set -euo pipefail

IMAGE_NAME="postman-regression"
ARTIFACTS_DIR="$(pwd)/artifacts"

# ── Load variables from .env if present ──────────────────────────────────────
if [ -f .env ]; then
  # shellcheck source=/dev/null
  set -o allexport
  source .env
  set +o allexport
fi

# ── Preflight checks ────────────────────────────────────────────────────────
for var in POSTMAN_API_KEY COLLECTION_ID ENVIRONMENT_ID BASE_URL AUTH_TOKEN; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required environment variable $var is not set." >&2
    exit 1
  fi
done

# ── Ensure local artifacts directory exists ──────────────────────────────────
mkdir -p "$ARTIFACTS_DIR"

# ── Step 1: Build the Docker image ──────────────────────────────────────────
echo "▶ Building Docker image: $IMAGE_NAME"
docker build --platform linux/amd64 -t "$IMAGE_NAME" .

# ── Step 2: Run collection ───────────────────────────────────────────────────
# The Postman CLI automatically authenticates using the POSTMAN_API_KEY
# environment variable — no explicit `postman login` command required.
# (The login command in CLI v1.29+ attempts browser-based OAuth which
#  fails in headless containers.)
echo "▶ Running Postman collection..."
docker run --rm \
  --entrypoint /bin/bash \
  -e POSTMAN_API_KEY="$POSTMAN_API_KEY" \
  -e COLLECTION_ID="$COLLECTION_ID" \
  -e ENVIRONMENT_ID="$ENVIRONMENT_ID" \
  -e BASE_URL="$BASE_URL" \
  -e AUTH_TOKEN="$AUTH_TOKEN" \
  -v "$ARTIFACTS_DIR":/app/artifacts \
  "$IMAGE_NAME" \
  -c 'postman collection run "$COLLECTION_ID" \
        --environment "$ENVIRONMENT_ID" \
        --env-var "base_url=$BASE_URL" \
        --env-var "auth_token=$AUTH_TOKEN" \
        --reporters cli,html,junit,json \
        --reporter-html-export /app/artifacts/report.html \
        --reporter-junit-export /app/artifacts/results.xml \
        --reporter-json-export /app/artifacts/results.json \
        --bail \
        --verbose'

echo "✅ Tests complete. Artifacts exported to: $ARTIFACTS_DIR"
