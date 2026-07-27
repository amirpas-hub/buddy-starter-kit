# BUDDY Scheduler — always-on (a)

Makes BUDDY fire on its own instead of only when you summon it. macOS **launchd**.

## What runs, when (system local time)
| Job | Schedule | Prompt | Max |
|-----|----------|--------|-----|
| **Morning cockpit** | Mon–Fri **07:30** | `gm` (note-fill + cockpit refresh + brief) | 15 min |
| **Around-call sweep** | every **15 min**, Mon–Fri 08:00–18:59 | (1) T-30 prep for calls starting soon; (2) Fellow capture after a call → CRM note + Gmail draft; (3) Gemini/Drive reconcile ~30-45 min later | 8 min |
| **EOD wrap** | Mon–Fri **17:30** | `wrap up` | 12 min |
| **Weekly deep-dive** | **Mon 07:45** | pipeline + forecast reality-check | 20 min |

## Capture layer (b) — both sources, Fellow-first
- **Stage 1 (immediate):** call ends → pull **Fellow** summary/actions → write a CRM note (`[BUDDY capture · Fellow]`) + create a **Gmail follow-up draft** in your voice.
- **Stage 2 (~30-45 min later):** the **Gemini** note lands in Drive → reconcile; if it adds material, append `[BUDDY capture · Gemini reconcile]` to the note + upgrade the draft.
- **Guardrail:** if no CRM account matches (e.g. cold intro not yet in Vault), it SKIPS the note and flags an open action — never guesses. Emails/Slack always DRAFT-ONLY.

## Files
- `env.sh` — PATH + decodes creds for the bare launchd environment
- `run-buddy.sh <job> <max_secs> <prompt>` — the runner (preflight, kill-guard, logging, rotation)
- `call-sweep.sh` — the around-call engine (prep + Fellow capture + Gemini reconcile), per-day state files
- `link-creds.sh` — snapshots model-proxy creds (base64) → `creds.env` (chmod 600)
- `creds.env` — **secret**, chmod 600, git-ignored. Model creds only (tools use `~/.cache/tool-gateway-token`).
- `logs/` — per-run logs + `last-run.log` summary
- LaunchAgents: `~/Library/LaunchAgents/io.buddy.{morning,eod,prepsweep,weekly}.plist`
- Auto-relink: `~/.pi/agent/extensions/buddy-relink-creds.ts` (refreshes creds on every pi launch when >4h old)

## Credential model (important)
- **Model auth** (`PI_PROXY_*`) is injected by Pi Desktop and **rotates ~daily**. The
  auto-relink extension re-snapshots it every time you open pi (when stale), so as long
  as you open pi ~once a day the scheduler stays authenticated.
- **Tool auth** (CRM/BQ/quick) uses `~/.cache/tool-gateway-token` (long-lived, file-based).
- If scheduled runs start failing model auth: just open pi once, or run
  `bash ~/buddy-scheduler/link-creds.sh` from a live session.

## Manage
```bash
launchctl list | grep buddy                 # status
# fire one now (real side effects — writes notes / redeploys cockpit):
launchctl kickstart -k gui/$(id -u)/io.buddy.morning
tail -f ~/buddy-scheduler/logs/last-run.log  # watch results
# disable one / all:
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/io.buddy.morning.plist
for p in morning eod prepsweep weekly; do launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/io.buddy.$p.plist; done
```

## Notes / caveats
- Times follow **wherever the laptop is** (Toronto/EDT this week, Manchester/BST normally). Adjust the `Hour` in the plists if you want them pinned to UK time.
- launchd only fires when the Mac is **awake** (missed runs while asleep fire on wake, once).
- All external actions stay **draft-only** (BUDDY's trust boundary) — nothing is sent.
