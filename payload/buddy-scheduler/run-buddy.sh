#!/bin/bash
# run-buddy.sh <job> <max_seconds> <prompt...>
# Unattended BUDDY runner. Sources env, preflights creds, runs `pi -p`, logs, guards.
#
#   job         short label for logs (morning|eod|weekly|prepsweep|test)
#   max_seconds hard kill guard
#   prompt      the prompt handed to BUDDY (e.g. "gm")

set -o pipefail   # NB: no -u; macOS bash 3.2 mishandles empty arrays under nounset
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SELF_DIR/env.sh"

JOB="${1:?job label required}"; shift
MAXSECS="${1:?max_seconds required}"; shift
PROMPT="$*"
[ -n "$PROMPT" ] || { echo "prompt required"; exit 2; }

TS="$(date '+%Y%m%d-%H%M%S')"
LOG="$BUDDY_LOGS/${JOB}-${TS}.log"
STAMP="$(date '+%Y-%m-%d %H:%M:%S %Z')"

log(){ echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

{
  echo "════════════════════════════════════════════"
  echo "BUDDY unattended run · job=$JOB · $STAMP"
  echo "prompt: $PROMPT"
  echo "════════════════════════════════════════════"
} >> "$LOG"

# --- Preflight ---
if [ ! -f "$BUDDY_CREDS" ]; then
  log "❌ No creds.env — run link-creds.sh from a live pi session. Aborting."
  echo "$STAMP | $JOB | FAIL no-creds" >> "$BUDDY_LOGS/last-run.log"; exit 3
fi
if [ -z "${PI_PROXY_API_KEY:-}" ]; then
  log "❌ creds.env present but PI_PROXY_API_KEY empty — re-link. Aborting."
  echo "$STAMP | $JOB | FAIL empty-creds" >> "$BUDDY_LOGS/last-run.log"; exit 3
fi
if [ ! -f "$TOKEN_CACHE" ]; then
  log "⚠️ tool-gateway token cache missing — CRM/BQ tools will fail. Continuing (model-only ok)."
else
  AGE=$(( ( $(date +%s) - $(stat -f %m "$TOKEN_CACHE") ) / 86400 ))
  log "token cache age: ${AGE}d"
fi

# Extra flags as a plain string (model name has no spaces) to stay bash-3.2 safe
EXTRA_FLAGS=""
case "$JOB" in prepsweep|callsweep) EXTRA_FLAGS="--model $BUDDY_MODEL_SWEEP";; esac

cd "$HOME" || exit 4
log "launching pi -p (max ${MAXSECS}s) ..."

# --- Run with hard kill guard ---
( pi -p --approve $EXTRA_FLAGS -n "buddy-${JOB}-${TS}" "$PROMPT" >> "$LOG" 2>&1 ) &
PID=$!
SECS=0
while kill -0 "$PID" 2>/dev/null; do
  sleep 3; SECS=$((SECS+3))
  if [ "$SECS" -ge "$MAXSECS" ]; then
    log "⏱️ max ${MAXSECS}s hit — killing pid $PID"
    kill "$PID" 2>/dev/null; sleep 2; kill -9 "$PID" 2>/dev/null
    echo "$STAMP | $JOB | TIMEOUT ${MAXSECS}s" >> "$BUDDY_LOGS/last-run.log"
    break
  fi
done
wait "$PID" 2>/dev/null; RC=$?

if [ "$RC" -eq 0 ]; then
  log "✅ done (rc=0)"
  echo "$STAMP | $JOB | OK" >> "$BUDDY_LOGS/last-run.log"
else
  log "⚠️ finished rc=$RC"
  echo "$STAMP | $JOB | rc=$RC" >> "$BUDDY_LOGS/last-run.log"
fi

# --- Log rotation: keep newest 40 per job ---
ls -1t "$BUDDY_LOGS/${JOB}-"*.log 2>/dev/null | tail -n +41 | xargs rm -f 2>/dev/null
exit "$RC"
