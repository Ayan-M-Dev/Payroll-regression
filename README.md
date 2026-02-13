# Payroll API — Postman Regression 

> **Production-grade, fully containerized** Postman CLI regression tests for the Payroll API.  

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Project Structure](#project-structure)
- [Part A — Docker Setup](#part-a--docker-setup)
- [Part B — GitHub Actions CI](#part-b--github-actions-ci)
- [Part C — Security & Best Practices](#part-c--security--best-practices)
- [Part D — Production Notes](#part-d--production-notes)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Actions (CI)                       │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              ubuntu:22.04 container                   │  │
│  │                                                       │  │
│  │  1. Install curl + ca-certificates                    │  │
│  │  2. Install Postman CLI (official installer)          │  │
│  │  3. postman collection run $COLLECTION_ID             │  │
│  │     ├── --environment $ENVIRONMENT_ID                 │  │
│  │     ├── --env-var base_url=$BASE_URL                  │  │
│  │     ├── --env-var auth_token=$AUTH_TOKEN               │  │
│  │     ├── --reporters cli,html,junit,json               │  │
│  │     ├── --bail --verbose                              │  │
│  │     └── exports → artifacts/                          │  │
│  │                                                       │  │
│  │  5. Upload artifacts (report.html, results.xml/json)  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  Secrets: POSTMAN_API_KEY, COLLECTION_ID, ENVIRONMENT_ID,   │
│           BASE_URL, AUTH_TOKEN                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
Payroll-regression/
├── .github/
│   └── workflows/
│       └── postman-tests.yml    # GitHub Actions CI pipeline
├── artifacts/                   # Generated at runtime (gitignored)
│   ├── report.html              # HTML test report
│   ├── results.xml              # JUnit XML (CI parsers)
│   └── results.json             # Raw JSON results
├── .dockerignore                # Keeps Docker build context lean
├── .env.example                 # Template for environment variables
├── .gitignore                   # Excludes secrets + artifacts
├── Dockerfile                   # Postman CLI container image
├── README.md                    # This file
└── run-tests.sh                 # Local Docker orchestration script
```

---

## Part A — Docker Setup

### 1. Build the Docker Image

```bash
docker build -t postman-regression .
```

### 2. Run Tests via Docker

```bash
docker run --rm \
  --entrypoint /bin/bash \
  --env-file .env \
  -v "$(pwd)/artifacts":/app/artifacts \
  postman-regression \
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
```

### 3. One-Command Execution (Recommended)

```bash
# Export your variables first
export POSTMAN_API_KEY="PMAK-..."
export COLLECTION_ID="12345678-..."
export ENVIRONMENT_ID="12345678-..."
export BASE_URL="https://staging-api.example.com"
export AUTH_TOKEN="Bearer eyJhbGciOi..."

# Run everything
./run-tests.sh
```

### Flags Explained

| Flag | Purpose |
|------|---------|
| `--rm` | Auto-remove container after exit (no stale containers) |
| `-e` | Inject environment variable into the container |
| `-v` | Mount local `artifacts/` directory for report export |
| `--bail` | Fail fast on first assertion error |
| `--verbose` | Detailed request/response logging |
| `--reporters` | Output formats: `cli` (stdout), `html`, `junit`, `json` |

---

## Part B — GitHub Actions CI

The workflow is defined at **`.github/workflows/postman-tests.yml`**.

### Triggers

| Trigger | When |
|---------|------|
| `pull_request` → `main` | Every PR targeting `main` |
| `push` → `main` | Every merge into `main` |
| `schedule` (cron) | Nightly at 02:00 UTC |
| `workflow_dispatch` | Manual trigger from Actions UI |

### What the Workflow Does

1. **Checks out** the repository
2. **Installs** `curl` + `ca-certificates` inside the `ubuntu:22.04` container
3. **Installs Postman CLI** via the official linux64 installer
4. **Authenticates** implicitly using the `POSTMAN_API_KEY` environment variable
5. **Runs the collection** with environment overrides and all reporters
6. **Uploads artifacts** (`report.html`, `results.xml`, `results.json`) — even if tests fail

### Uploaded Artifacts

After each workflow run, download artifacts from the **Actions → Run → Artifacts** section:

- `report.html` — Human-readable HTML report
- `results.xml` — JUnit XML for CI test-summary integrations
- `results.json` — Raw JSON for programmatic analysis

---

## Part C — Security & Best Practices

### Required GitHub Secrets

Navigate to **Settings → Secrets and variables → Actions → New repository secret** and add:

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `POSTMAN_API_KEY` | Postman API key for CLI authentication | `PMAK-xxxxxxxx-xxxxxxxx` |
| `COLLECTION_ID` | Postman Collection UID | `12345678-abcd-efgh-ijkl-000000000000` |
| `ENVIRONMENT_ID` | Postman Environment UID | `12345678-abcd-efgh-ijkl-111111111111` |
| `BASE_URL` | Staging API base URL | `https://staging-api.example.com` |
| `AUTH_TOKEN` | Bearer token for API auth | `Bearer eyJhbGciOi...` |

### Security Checklist

- [x] **No hardcoded URLs** — `BASE_URL` injected via secret/env var
- [x] **No hardcoded tokens** — `AUTH_TOKEN` and `POSTMAN_API_KEY` injected via secret/env var
- [x] **No exported JSON files** — Collection fetched from Postman cloud via `COLLECTION_ID`
- [x] **PR-gated** — Workflow triggers on `pull_request` (ready for branch protection rules)
- [x] **Secrets masked** — GitHub automatically masks secret values in logs
- [x] **`.env` gitignored** — Local secrets never committed to version control
- [x] **Container isolation** — Tests run inside `ubuntu:22.04`, not on the host

---

## Part D — Production Notes

### Why Authenticating Before Running Collection ID is Required

Postman CLI uses **Collection UIDs** to fetch the latest version of a collection directly from the Postman cloud workspace. This is fundamentally different from running an exported JSON file locally. Authentication via the `POSTMAN_API_KEY` environment variable establishes a secure session with the Postman API, granting the CLI permission to:

- Resolve the Collection UID to its latest version
- Resolve the Environment UID and its variable set
- Access private/team workspace resources

Without authentication, the CLI has no credentials to call the Postman API and cannot fetch cloud-hosted collections. This is by design — it ensures that only authorized users and CI systems can execute your test suites.

### Why Built-in Reporters Should Be Used

Postman CLI ships with four built-in reporters, each serving a distinct purpose in production CI/CD:

| Reporter | Purpose |
|----------|---------|
| **cli** | Real-time stdout output for live monitoring during CI runs |
| **html** | Human-readable visual report for QA review and stakeholder sharing |
| **junit** | Industry-standard XML format consumed by CI platforms (GitHub Actions, Jenkins, Azure DevOps) for test summaries and trend analysis |
| **json** | Machine-readable format for custom dashboards, Slack bots, and programmatic post-processing |

Using built-in reporters eliminates the need for third-party dependencies, reduces supply-chain risk, and ensures compatibility with Postman CLI updates.

### Why Containerization Eliminates Environmental Drift

Environmental drift occurs when the execution environment differs between a developer's machine, CI server, and staging/production infrastructure. Common drift sources include:

- Different OS versions or patch levels
- Missing or mismatched system libraries
- Different CLI versions installed over time
- Conflicting global tool installations

By running Postman CLI inside `ubuntu:22.04`, every execution — local or CI — uses **the exact same base image, system libraries, and CLI version**. This guarantees:

- **Reproducibility**: Test results are consistent across all environments
- **Isolation**: No host-level contamination from other tools
- **Portability**: Any machine with Docker can run the suite identically
- **Auditability**: The Dockerfile serves as a declarative, version-controlled specification of the test environment

### Why Injecting Environment Variables via Secrets is Critical

For a **financial payroll system**, data security is non-negotiable:

1. **Regulatory compliance**: Payroll systems handle PII and financial data governed by regulations (SOC 2, GDPR, PCI-DSS). Hardcoded credentials in source code create audit failures.
2. **Principle of least privilege**: Secrets are scoped to the CI environment and never persist in code, logs, or Docker layers.
3. **Rotation without code changes**: When API keys or tokens are rotated (a security best practice), only the GitHub Secret value needs updating — no code commit required.
4. **Blast radius containment**: If the repository is compromised, secrets stored in GitHub's encrypted vault are not exposed in the codebase.

### Why This Setup is Production-Grade for Financial Payroll Validation

This setup satisfies the requirements of a production-grade regression suite for financial systems:

| Requirement | How It's Met |
|-------------|-------------|
| **Reproducibility** | Dockerfile + container ensures identical environments |
| **Security** | All credentials via GitHub Secrets; nothing hardcoded |
| **Auditability** | HTML/JUnit/JSON reports archived as CI artifacts |
| **Automation** | PR-gated + nightly scheduled runs |
| **Fail-fast** | `--bail` stops on first failure; CI status reflects pass/fail |
| **Compliance** | No secrets in code; environment isolation; audit trail via artifacts |
| **Scalability** | Containerized approach works across GitHub Actions, Jenkins, GitLab CI, or any Docker-capable CI platform |
| **Latest tests** | Collection fetched from Postman cloud — always the latest version |

This is the standard expected for financial software where payroll calculation accuracy, tax compliance, and data integrity are mission-critical.
