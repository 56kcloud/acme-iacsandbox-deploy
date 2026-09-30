#!/usr/bin/env bash
# Runs the shared config_sync.py for one env directory, at the SHA its deploy stub pins.
# Shared by the config:sync and config:check mise tasks, so both always use the
# script version that matches the pinned workflows.
#
# Usage: ./.mise/config-run.sh <sync|check> <env>
# Example: ./.mise/config-run.sh check engorg
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <sync|check> <env>"
  exit 1
fi

MODE="$1"
ENV_DIR="$2"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHARED_REPO="56kcloud/acme-iacplatform-githubworkflows"
STUB=".github/workflows/deploy-${ENV_DIR}.yml"

cd "${REPO_ROOT}"

# -----------------------------------------------------------------------
# 1. Pinned SHA
# -----------------------------------------------------------------------
if [[ ! -f "${STUB}" ]]; then
  echo "ERROR — no ${STUB}; is '${ENV_DIR}' an env directory?"
  exit 1
fi

# First uses: line that calls the shared repo. config_sync.py re-reads every
# such line and fails if they disagree, so the first one is enough here.
sha="$(grep -E "^[[:space:]]*uses:[[:space:]]*${SHARED_REPO}/" "${STUB}" | grep -oE '@[0-9a-f]{40}' | head -1 | tr -d @ || true)"
if [[ -z "${sha}" ]]; then
  echo "ERROR — ${STUB} does not pin ${SHARED_REPO} by a 40-character SHA."
  exit 1
fi

# -----------------------------------------------------------------------
# 2. config_sync.py at that SHA
# -----------------------------------------------------------------------
script="$(mktemp)"
trap 'rm -f "${script}"' EXIT

gh api -H 'Accept: application/vnd.github.raw' \
  "repos/${SHARED_REPO}/contents/scripts/config_sync.py?ref=${sha}" > "${script}"

# config_sync.py needs Python >= 3.11 (tomllib). mise x supplies it without
# changing the env's own tool versions.
mise x python@3.12 -- python3 "${script}" "${MODE}" --env-dir "${ENV_DIR}"
