#!/bin/bash
# call-sweep.sh — the around-call engine (prep + capture) in ONE model call per heartbeat.
# Timing (UK business hours) is gated by dispatch.sh. Handles three jobs:
#   1) T-30 meeting prep for calls about to start
#   2) Fellow capture immediately after a call (CRM note + Gmail follow-up draft)
#   3) Gemini/Drive reconcile ~30-45 min later (upgrade the note + draft)
# Per-meeting, per-day state files prevent re-doing work.

set -o pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SELF_DIR/env.sh"

UKDATE=$(TZ="Europe/London" date +%Y%m%d)
UKNOW=$(TZ="Europe/London" date '+%a %d %b %H:%M %Z')
PREPPED="$BUDDY_STATE/prepped-$UKDATE.txt"
FELLOW="$BUDDY_STATE/fellow-captured-$UKDATE.txt"
GEMINI="$BUDDY_STATE/gemini-reconciled-$UKDATE.txt"
RTS_LOG="$BUDDY_STATE/ready-to-send-$UKDATE.log"   # one queued send per line
READY_JSON="$HOME/Desktop/buddy-site/buddy-cockpit/ready-to-send.json"
NEXTCALL_JSON="$HOME/Desktop/buddy-site/buddy-cockpit/next-call.json"
NOTIFY="$SELF_DIR/notify.sh"
COCKPIT_DEPLOY="$HOME/Desktop/buddy-site/buddy-cockpit/deploy.sh"
SEND_CAP=15                                        # max auto-queued sends per UK day
touch "$PREPPED" "$FELLOW" "$GEMINI" "$RTS_LOG"
mkdir -p "$HOME/Desktop/buddy-site/prep"
# prune state >8 days
find "$BUDDY_STATE" -name '*-captured-*.txt' -o -name 'prepped-*.txt' -o -name 'gemini-*.txt' -mtime +8 -delete 2>/dev/null

PROMPT="BUDDY around-call sweep. UK time now: ${UKNOW}. Work through the three tasks below in order, be efficient, and if there is genuinely nothing to do reply exactly NOTHING_TODO and stop. Consider EXTERNAL MERCHANT calls only — skip internal 1:1s, team meetings, forecast checks, all-hands.

STATE FILES (one meeting id per line; READ before acting, APPEND the id after you finish it so it is not redone):
- prepped:  ${PREPPED}
- fellow:   ${FELLOW}
- gemini:   ${GEMINI}

TASK 1 — T-30 PREP (external only). Look at my Google Calendar for meetings STARTING in the next 40 minutes. A meeting is IN SCOPE only if it has at least one EXTERNAL attendee (any non-@shopify.com email — a merchant or a partner). SKIP anything where every attendee is @shopify.com (internal 1:1s, team syncs, forecast, all-hands). For each in-scope meeting whose event id is NOT already in the prepped file, build a prep brief as follows:

  STEP A — classify FIRST vs FOLLOW-UP. Decide whether I have spoken with this company/these attendees before: check my owned CRM book (match the external company to a deal/account, then crm_list_activities for prior meetings+calls with that account) AND check Fellow for past meetings with the same company/attendees. If there is a genuine prior conversation → FOLLOW-UP. If not → FIRST call.

  STEP B — write the brief by branch:
    • FOLLOW-UP → lead with a tight SUMMARY OF THE PREVIOUS CALL (what was discussed, decisions, what each side committed to), pulled from the last Fellow summary / CRM note / meeting transcript. Then a SUGGESTED AGENDA: 3-5 topics to cover on this call, ordered, each one sentence — driven by the open commitments and next steps from last time. Then who is attending.
    • FIRST call → if the external party is a MERCHANT I can identify: a short MERCHANT OVERVIEW (what they sell, rough size/GMV or revenue, current platform, B2B/DTC mix, and the likely why-Shopify angle) + who is attending + 2-3 objectives for a first conversation (discovery-led, not pitch). If it is PARTNER-ONLY (no merchant on the invite, e.g. an agency intro): skip the merchant overview and instead give a short partner/context overview (who the partner is, any shared deals, and what I want out of the intro). Always keep it to what I can source — flag gaps, never invent.

  Save the full brief to ~/Desktop/buddy-site/prep/<id>.md, append <id> to the prepped file, and FIRE THE ALERT so I actually see it: run  bash ${NOTIFY} "⏰ T-30: <Company>" "<First call | Follow-up> at <HH:MM> — prep on the cockpit".

  DELIVERY (every run, so the panel self-clears): rebuild ${NEXTCALL_JSON} from ALL in-scope external meetings starting in the next 40 minutes (drop any that have already started). Write a JSON array where each object is {"company","time" (e.g. \"13:00 BST\"),"kind" (\"first\" or \"followup\"),"attendees":[external names],"brief" (plain-text, the same brief you saved, kept concise)}. If there are NO in-scope upcoming meetings, write an empty array []  to ${NEXTCALL_JSON}. Whenever ${NEXTCALL_JSON} changed this run, run: bash ${COCKPIT_DEPLOY} to publish.

TASK 2 — FELLOW CAPTURE (immediate). For each external merchant meeting that ENDED in the last 75 minutes whose id is NOT in the fellow file: pull the Fellow summary + action items (fellow_get_meeting_summary; use fellow_get_meeting_transcript only if the summary is thin). Then:
  (a) Write a CRM note on the matching owned deal/account via crm_add_note, headed '[BUDDY capture · Fellow]', containing: a 3-5 bullet summary, decisions, commitments (who owes what + by when), and the agreed next step. Match by company name to my owned deals; if you cannot confidently match an account, note that in your reply instead of guessing.
  (b) Create a Gmail DRAFT follow-up (gws_gmail_create_draft) to the external attendees, written in Amir's voice (short, punchy, no filler; restate what was discussed and the next steps; do NOT introduce pricing that wasn't already agreed on the call). DRAFT ONLY — never send (there is no send tool; the send tap is Amir's, by design).
  (c) ONE-TAP SEND QUEUE. If EVERY recipient on the draft is EXTERNAL (no @shopify.com address among them — Shopify colleagues are never queued), then this contact is green-lit (Amir spoke to them on the call): mark the draft as ready by STARRING it (gws_gmail_apply_label with label STARRED — no custom-label setup needed) and add it to the one-tap queue by appending ONE line to ${RTS_LOG} in the exact form:  <company>\t<subject>\t<recipients-comma-sep>\t<draftId>\t<https://mail.google.com/mail/u/0/#drafts?compose=DRAFTID>  — BUT first count the lines already in ${RTS_LOG}: if that count is >= ${SEND_CAP}, do NOT label/queue (daily cap reached) and just note 'capped' in your reply. If ANY recipient is @shopify.com, leave it as a plain draft, do NOT label, do NOT queue.
  Append <id> to the fellow file.

TASK 3 — GEMINI RECONCILE (~30-45 min later). For each id in the fellow file that is NOT in the gemini file AND whose meeting ended 25-180 minutes ago: search Google Drive for that meeting's Gemini/meeting-notes doc. If found and it adds material beyond the Fellow summary, append an addendum to the CRM note ('[BUDDY capture · Gemini reconcile]') and update the Gmail draft accordingly. Append <id> to the gemini file. If the meeting ended MORE than 180 minutes ago and there is still no Gemini doc, append <id> to the gemini file anyway so we stop checking.

AFTER any queue change: rebuild the one-tap queue file so the cockpit shows it. Read ${RTS_LOG}, convert every line to a JSON object {\"company\",\"subject\",\"recipients\":[...],\"draftId\",\"draftUrl\",\"ts\"} and write the JSON array to ${READY_JSON} (overwrite). Then run: bash ${COCKPIT_DEPLOY} to publish. If nothing was queued this run, do NOT touch the JSON or deploy.

RULES: CRM notes may be written (internal). Emails and Slack are DRAFT ONLY — no send tool exists. Green-list = external attendees of a call Amir was on; NEVER queue anything addressed to an @shopify.com colleague. Respect the daily send cap (${SEND_CAP}). Always label whether a point came from Fellow or Gemini. Do not rebuild the whole cockpit (only ready-to-send.json). Keep your final reply to a short receipt of what you prepped / captured / queued / reconciled."

exec "$SELF_DIR/run-buddy.sh" callsweep 480 "$PROMPT"
