# GitHub Actions Workflows

This document explains how the CI/CD workflows work for **indy-plenum** and how to do a release.

## Quick Reference

| Task | How |
|------|-----|
| Run tests on a PR | Open any PR — tests run automatically |
| Build Docker images on push | Push to `main` (Docker images are built and pushed to GHCR) |
| Start a release | Push a tag matching `setRelease-v**` |
| See all workflow runs | Go to the **Actions** tab in GitHub |

---

## Workflows

### ci.yaml — Continuous Integration

**Triggers:** All PRs, pushes to `main`

**What it does:**
1. Builds the base Docker image (rocksdb, ursa, indy-sdk)
2. Builds the production Docker image
3. Runs the full test suite (8 parallel plenum slices + 7 module tests)

**PR behavior:** Builds images locally (not pushed to GHCR). Tests run inside the production container.

**Push-to-main behavior:** Builds and pushes images to `ghcr.io/<owner>/indy-plenum-base:latest` and `ghcr.io/<owner>/indy-plenum:latest`.

---

### release-start.yaml — Start Release

**Triggers:** Tag push matching `setRelease-v*`

**What it does:**
1. Parses version from the tag (e.g., `setRelease-v1.13.2` → `1.13.2`)
2. Runs `bump_version.sh` to update `plenum/__version__.json`
3. Creates a pull request with the version bump

---

### release-publish.yaml — Publish Release

**Triggers:** Push to `main` when `plenum/__version__.json` changes (i.e., when a version bump PR is merged)

**What it does:**
1. Parses version from the commit message
2. Builds and pushes Docker images with version tags (e.g., `ghcr.io/<org>/indy-plenum:v1.13.2`)
3. Creates a GitHub Release with auto-generated release notes

---

### test.yaml — Test Suite (shared)

**Trigger:** Called by other workflows via `workflow_call`. Accepts `image_tag` as input.

**What it does:**
- Runs `plenum` module tests split into 8 parallel slices
- Runs tests for `common`, `crypto`, `ledger`, `state`, `storage`, `stp_core`, `stp_zmq` modules as separate jobs

---

## How to Do a Release

### 1. Push a release tag

```bash
# Stable release:
git tag setRelease-v1.13.2
git push origin setRelease-v1.13.2

# Release candidate:
git tag setRelease-v1.13.2-rc1
git push origin setRelease-v1.13.2-rc1
```

### 2. Review the version bump PR

The `release-start.yaml` workflow creates a PR that bumps `plenum/__version__.json`. Review and merge it.

### 3. Release is published

When the PR merges, `release-publish.yaml` runs and:
- Builds and pushes Docker images tagged `v1.13.2` and `latest`
- Creates a GitHub Release

### 4. Verify

Check the **Actions** tab for the workflow run. Check the **Releases** tab for the new release.

---

## Docker Image Chain

```
Dockerfile.base
  FROM: ubuntu:22.04
  Installs: rocksdb, ursa, indy-sdk (compiled from source)

Dockerfile
  FROM: indy-plenum-base
  Installs: plenum source + test deps
```

Images pushed to `ghcr.io/<owner>/`:
- `indy-plenum-base` — native dependencies (rocksdb, ursa, indy-sdk)
- `indy-plenum` — plenum Python package + test deps

---

## Forking

### What works automatically

- **ci.yaml** — Docker image tags use `${{ github.repository_owner }}`, so they automatically point to your fork's GHCR
- **release-start.yaml** — Creates version bump PRs
- **release-publish.yaml** — Builds and pushes tagged images

### Required secrets

| Secret | Purpose |
|--------|---------|
| `GITHUB_TOKEN` | Login to ghcr.io (automatic) |
| `GITHUB_TOKEN` | Create PRs and releases (automatic) |

### Building locally

```bash
# Build the base image (takes a while — compiles Rust dependencies)
docker build -f Dockerfile.base -t ghcr.io/$(whoami)/indy-plenum-base:latest .

# Build the production image
docker build -f Dockerfile -t ghcr.io/$(whoami)/indy-plenum:latest .

# Run tests inside the container
docker run --rm -v $(pwd):/app -w /app ghcr.io/$(whoami)/indy-plenum:latest \
  python3 -m pytest -l -vv plenum
```

---

## Troubleshooting

### "Tests didn't run"

Check if your PR touches any `.py`, `Dockerfile*`, `.github/**`, or `bump_version.sh` files. If it only changes docs or markdown, tests are skipped.

### "Docker push fails with 403"

The `GITHUB_TOKEN` may not have `write:packages` permission. Go to Settings → Actions → General → Workflow permissions and ensure "Read and write permissions" is selected.

### "Version bump PR wasn't created"

Ensure the tag matches `setRelease-v*` pattern (e.g., `setRelease-v1.13.2`).

### "Release wasn't created"

The `create-release` job uses `GITHUB_TOKEN` to create the GitHub Release. Ensure the token has sufficient permissions.
