#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_basename="$(basename "$repo_root")"

sanitize_slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//'
}

bounded_db_suffix_slug() {
  local slug
  local hash

  slug="$(sanitize_slug "$1")"

  if (( ${#slug} <= 20 )); then
    printf '%s' "$slug"
    return 0
  fi

  hash="$(printf '%s' "$slug" | sha1sum | cut -c1-8)"
  printf '%.11s_%s' "$slug" "$hash"
}

if [[ "$repo_basename" == "newfoundlandlabradoronline" ]]; then
  worktree_db_suffix=""
else
  worktree_db_suffix="_$(bounded_db_suffix_slug "$repo_basename")"
fi

active_project_name="$(
  docker inspect newfoundland-labrador-online-db \
    --format '{{ index .Config.Labels "com.docker.compose.project" }}' \
    2>/dev/null || true
)"

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-${active_project_name:-newfoundlandlabradoronline}}"
export NLO_WORKTREE_DB_SUFFIX="${NLO_WORKTREE_DB_SUFFIX:-$worktree_db_suffix}"
