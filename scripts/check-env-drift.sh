#!/usr/bin/env bash
# Detects unintended structural drift between two env directories and their workflows.
# Normalizes the env name token and AWS account ID before diffing — everything else
# that differs is real drift.
#
# Usage: ./scripts/check-env-drift.sh <env_a> <env_b>
# Example: ./scripts/check-env-drift.sh devt prod
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <env_a> <env_b>"
  exit 1
fi

ENV_A="$1"
ENV_B="$2"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
drift=0

# Replace the env name (whole word only) and 12-digit AWS account ID — the only things expected to differ.
# \b word boundaries prevent matching env names that appear as substrings (e.g. "depl" inside "deploy").
# Uses perl for consistent \b support across macOS and Linux.
normalize() {
  local env="$1"
  perl -pe "s/\b\Q${env}\E\b/__ENV__/g; s/\d{12}/__AWS_ACCOUNT_ID__/g"
}

# -----------------------------------------------------------------------
# 1. TF directory files
# -----------------------------------------------------------------------
echo "=== ${ENV_A}/ vs ${ENV_B}/ ==="

for file in $(cd "${REPO_ROOT}/${ENV_A}" && find . -type f -not -path './.terraform/*' | sort); do
  rel="${file#./}"
  fa="${REPO_ROOT}/${ENV_A}/${rel}"
  fb="${REPO_ROOT}/${ENV_B}/${rel}"

  if [[ ! -f "${fb}" ]]; then
    echo "  MISSING in ${ENV_B}/: ${rel}"
    drift=1
    continue
  fi

  out=$(diff <(normalize "${ENV_A}" < "${fa}") <(normalize "${ENV_B}" < "${fb}") || true)
  if [[ -n "${out}" ]]; then
    echo "  DRIFT in ${rel}:"
    echo "${out}"
    drift=1
  fi
done

# -----------------------------------------------------------------------
# 2. Workflow files
# -----------------------------------------------------------------------
echo ""
echo "=== deploy-${ENV_A}.yml vs deploy-${ENV_B}.yml ==="

wf_a="${REPO_ROOT}/.github/workflows/deploy-${ENV_A}.yml"
wf_b="${REPO_ROOT}/.github/workflows/deploy-${ENV_B}.yml"

out=$(diff <(normalize "${ENV_A}" < "${wf_a}") <(normalize "${ENV_B}" < "${wf_b}") || true)
if [[ -n "${out}" ]]; then
  echo "  DRIFT:"
  echo "${out}"
  drift=1
fi

# -----------------------------------------------------------------------
# Result
# -----------------------------------------------------------------------
echo ""
if [[ ${drift} -eq 0 ]]; then
  echo "OK — no drift between ${ENV_A} and ${ENV_B}."
else
  echo "WARNING — drift detected. Review above before deploying ${ENV_B}."
  exit 1
fi
