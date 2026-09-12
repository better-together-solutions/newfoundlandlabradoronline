#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_basename="$(basename "$repo_root")"
git_common_dir="$(git -C "$repo_root" rev-parse --git-common-dir)"
primary_repo_root="$(cd "$(dirname "$git_common_dir")" && pwd)"
primary_repo_basename="$(basename "$primary_repo_root")"

sanitize_slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//'
}

if [[ "$repo_basename" == "$primary_repo_basename" ]]; then
  worktree_db_suffix=""
else
  worktree_db_suffix="_$(sanitize_slug "$repo_basename")"
fi

canonical_ce_repo=""
for candidate in \
  "$primary_repo_root/../community-engine-rails" \
  "$(dirname "$primary_repo_root")/community-engine-rails" \
  "$(dirname "$(dirname "$primary_repo_root")")/better-together/community-engine-rails" \
  "/home/rob/projects/better-together/community-engine-rails"
do
  if [[ -d "$candidate" ]]; then
    canonical_ce_repo="$(cd "$candidate" && pwd)"
    break
  fi
done

# docker-compose.yml's app service hardcodes its OWN fallback defaults
# in an explicit `environment:` block (DB_HOST/DB_PORT/REDIS_URL all
# default to host.docker.internal:<mapped-port>) -- these are NOT
# read from database.yml or .env.dev at container-start time, they're
# substituted by `docker compose` itself from THIS shell's environment
# before the container ever starts. Leaving them unset does not fall
# through to any other default; it just lets compose's own hardcoded
# host.docker.internal default win.
#
# That host.docker.internal path is a hairpin route (container -> host
# -> back into another container via the host's mapped port) which
# times out on this shared host. Export the compose-native values
# instead -- app and db/redis already share the same compose network
# (confirmed via docker inspect + COMPOSE_PROJECT_NAME detection below),
# so the internal service name + internal port work directly.
export BTR_WORKTREE_DB_SUFFIX="${BTR_WORKTREE_DB_SUFFIX:-$worktree_db_suffix}"
export COMMUNITY_ENGINE_PATH="${COMMUNITY_ENGINE_PATH:-$canonical_ce_repo}"
export DB_HOST="${DB_HOST:-newfoundland-labrador-online-db}"
export DB_PORT="${DB_PORT:-5432}"
export DB_USERNAME="${DB_USERNAME:-postgres}"
export DB_PASSWORD="${DB_PASSWORD:-postgres}"
export REDIS_URL="${REDIS_URL:-redis://newfoundland-labrador-online-redis:6379}"
export SEARCH_BACKEND="${SEARCH_BACKEND:-pg_search}"
export ELASTICSEARCH_DISABLED="${ELASTICSEARCH_DISABLED:-true}"

detect_compose_project() {
  local container_name="$1"
  docker inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}' "$container_name" 2>/dev/null || true
}

existing_project="$(detect_compose_project newfoundland-labrador-online-db)"
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-${existing_project:-newfoundlandlabradoronline}}"
