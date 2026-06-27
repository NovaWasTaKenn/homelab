#!/usr/bin/env bash
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
# Loaded from environment — set in /etc/opnsense-backup.env
# shellcheck source=/dev/null
source /etc/opnsense-backup.env

BACKUP_DIR="${BACKUP_DIR:-/opt/opnsense-backup/repo}"
BACKUP_FILE="${BACKUP_DIR}/config.xml"
LOG_PREFIX="[opnsense-backup]"

# ── Helpers ───────────────────────────────────────────────────────────────────
log()  { echo "${LOG_PREFIX} $*"; }
fail() { echo "${LOG_PREFIX} ERROR: $*" >&2; exit 1; }

# ── Preflight checks ──────────────────────────────────────────────────────────
[[ -z "${OPNSENSE_HOST:-}" ]]       && fail "OPNSENSE_HOST is not set"
[[ -z "${OPNSENSE_API_KEY:-}" ]]    && fail "OPNSENSE_API_KEY is not set"
[[ -z "${OPNSENSE_API_SECRET:-}" ]] && fail "OPNSENSE_API_SECRET is not set"
[[ -z "${GIT_REMOTE:-}" ]]          && fail "GIT_REMOTE is not set"

command -v git  >/dev/null 2>&1 || fail "git is not installed"
command -v curl >/dev/null 2>&1 || fail "curl is not installed"

# ── Init repo if needed ───────────────────────────────────────────────────────
if [[ ! -d "${BACKUP_DIR}/.git" ]]; then
  log "Initialising git repo at ${BACKUP_DIR}"
  mkdir -p "${BACKUP_DIR}"
  git -C "${BACKUP_DIR}" init
  git -C "${BACKUP_DIR}" remote add origin "${GIT_REMOTE}"
  git -C "${BACKUP_DIR}" fetch origin main 2>/dev/null || true
  git -C "${BACKUP_DIR}" checkout main 2>/dev/null \
    || git -C "${BACKUP_DIR}" checkout -b main
fi

# ── Fetch config from OPNsense API ────────────────────────────────────────────
log "Downloading config from https://${OPNSENSE_HOST}"

HTTP_CODE=$(curl \
  --silent \
  --show-error \
  --insecure \
  --write-out "%{http_code}" \
  --output "${BACKUP_FILE}.tmp" \
  --user "${OPNSENSE_API_KEY}:${OPNSENSE_API_SECRET}" \
  "https://${OPNSENSE_HOST}/api/core/backup/download/this")

if [[ "${HTTP_CODE}" != "200" ]]; then
  rm -f "${BACKUP_FILE}.tmp"
  fail "OPNsense API returned HTTP ${HTTP_CODE} — check credentials and connectivity"
fi

# Validate the response is actually XML
if ! grep -q "<?xml" "${BACKUP_FILE}.tmp"; then
  rm -f "${BACKUP_FILE}.tmp"
  fail "Response does not look like a valid config XML — aborting"
fi

mv "${BACKUP_FILE}.tmp" "${BACKUP_FILE}"
log "Config downloaded successfully"

# ── Commit if changed ─────────────────────────────────────────────────────────
git -C "${BACKUP_DIR}" add config.xml

if git -C "${BACKUP_DIR}" diff --cached --exit-code --quiet; then
  log "Config unchanged since last backup — nothing to commit"
  exit 0
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
git -C "${BACKUP_DIR}" commit \
  --author "opnsense-backup <backup@${OPNSENSE_HOST}>" \
  -m "chore: opnsense config backup ${TIMESTAMP}"

log "Committed config backup at ${TIMESTAMP}"

# ── Push ──────────────────────────────────────────────────────────────────────
git -C "${BACKUP_DIR}" push origin main
log "Pushed to ${GIT_REMOTE}"
