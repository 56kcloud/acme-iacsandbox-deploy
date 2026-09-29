#!/usr/bin/env bash
set -euo pipefail
mode=$1 env=$2
repo=56kcloud/acme-iacplatform-githubworkflows
stub=".github/workflows/terraform-$env.yml"
[[ -f "$stub" ]] || { echo "error: no $stub; is '$env' an env directory?" >&2; exit 1; }
sha=$(grep -E "^[[:space:]]*uses:[[:space:]]*$repo/" "$stub" | grep -oE '@[0-9a-f]{40}' | head -1 | tr -d @ || true)
[[ -n "$sha" ]] || { echo "error: $stub does not pin $repo by 40-character SHA" >&2; exit 1; }
script=$(mktemp)
trap 'rm -f "$script"' EXIT
gh api -H 'Accept: application/vnd.github.raw' "repos/$repo/contents/scripts/config_sync.py?ref=$sha" > "$script"
mise x python@3.12 -- python3 "$script" "$mode" --env-dir "$env"
