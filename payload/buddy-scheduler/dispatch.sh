#!/bin/bash
# dispatch.sh — UK-time-pinned dispatcher. Fires every ~15 min (launchd heartbeat),
# evaluates the clock in Europe/London, and launches each BUDDY job when the UK time
# crosses its target — regardless of what timezone the laptop is physically in.
# Once-per-day dedup via state files. This is what makes the schedule "always UK time".

set -o pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SELF_DIR/env.sh"

UKDOW=$(TZ="Europe/London" date +%u)     # 1=Mon .. 7=Sun
UKDATE=$(TZ="Europe/London" date +%Y%m%d)
UKHM=$((10#$(TZ="Europe/London" date +%H%M)))   # e.g. 0730 -> 730

ran() { [ -f "$BUDDY_STATE/ran-$1-$UKDATE" ]; }
mark(){ : > "$BUDDY_STATE/ran-$1-$UKDATE"; }
# prune state files older than ~8 days
find "$BUDDY_STATE" -name 'ran-*' -mtime +8 -delete 2>/dev/null

# --- Weekly deep-dive: Monday, UK 07:45 (catch-up window to 11:30) ---
if [ "$UKDOW" -eq 1 ] && [ "$UKHM" -ge 745 ] && [ "$UKHM" -le 1130 ] && ! ran weekly; then
  mark weekly
  "$SELF_DIR/run-buddy.sh" weekly 1200 "check in — run a full pipeline deep-dive and forecast reality-check across my whole owned book, flag what is slipping, and give me the week's priorities" &
fi

# --- Morning cockpit: Mon-Fri, UK 07:30 (catch-up window to 11:30) ---
if [ "$UKDOW" -le 5 ] && [ "$UKHM" -ge 730 ] && [ "$UKHM" -le 1130 ] && ! ran morning; then
  mark morning
  "$SELF_DIR/run-buddy.sh" morning 900 "gm" &
fi

# --- EOD wrap: Mon-Fri, UK 17:30 (catch-up window to 21:00) ---
if [ "$UKDOW" -le 5 ] && [ "$UKHM" -ge 1730 ] && [ "$UKHM" -le 2100 ] && ! ran eod; then
  mark eod
  "$SELF_DIR/run-buddy.sh" eod 720 "wrap up" &
fi

# --- Around-call sweep (prep + Fellow capture + Gemini reconcile): Mon-Fri, UK 08:00-18:59 ---
if [ "$UKDOW" -le 5 ] && [ "$UKHM" -ge 800 ] && [ "$UKHM" -le 1859 ]; then
  "$SELF_DIR/call-sweep.sh" &
fi

wait
