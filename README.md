# 🎁 BUDDY Starter Kit

**BUDDY** is a deal *digital twin* for Shopify sellers — an always-on assistant that does your
deal admin so you can sell. It reads your live CRM, Gmail (incl. Sent) and calendar, writes CRM
notes, drafts follow-ups, preps you before every external call, and keeps a live **Cockpit**
web dashboard current every morning.

This kit lets **anyone on the team stand up their own instance in ~2 minutes.**

---

## ⚠️ The one rule: BUDDY runs as *you*

BUDDY has no data of its own. It reads *your* CRM, *your* inbox, *your* calendar through *your*
Shopify login. So:

- **Never share credentials, tokens, or your cockpit URL.** Those are your identity.
- Each person installs the machinery and authenticates as themselves. Your BUDDY shows *your*
  book; your teammate's shows theirs.
- **Nothing sensitive is in this repo** — no creds, no tokens, no pipeline data. Just the machinery.

Everything external stays **draft-only**. BUDDY never sends an email or message on its own — you tap send.

---

## ✅ Prerequisites

- **macOS** (for the always-on scheduler; the skill itself works anywhere, you'd just run `gm` manually)
- **pi** (the Pi coding agent) installed and opened at least once
- Shopify **MCPs configured**: CRM/Vault, GWorkspace (Gmail/Calendar/Drive), Data Portal (BigQuery)
- **quick** CLI (to deploy your cockpit)
- `jq`, `base64` (standard)

Run the checker anytime:
```bash
./preflight.sh
```

---

## 🚀 Install

```bash
git clone https://github.com/amirpas-hub/buddy-starter-kit.git
cd buddy-starter-kit
./install.sh
```

The installer asks 5 quick questions (name, role, region, manager, target + a short handle for your
cockpit URL), then:

1. Installs the **Buddy skill** → `~/.pi/agent/skills/buddy/`
2. Writes your personalised **`AGENTS.md`** → `~/.pi/agent/AGENTS.md` (backs up any existing one)
3. Installs the **scheduler** → `~/buddy-scheduler/` and generates a machine-specific `env.local.sh`
4. Installs your **cockpit** → `~/Desktop/buddy-site/buddy-cockpit/` and deploys it to
   `https://<your-handle>-buddy-cockpit.quick.shopify.io`
5. Loads the **launchd** always-on heartbeat (every 15 min, UK-time-aware)
6. Links your model-proxy creds for unattended runs (if run inside a live pi session)

Then just open pi and say **`gm`**. BUDDY builds your roster from your CRM and fills your cockpit.

---

## 🔁 Keeping creds fresh

Scheduled (unattended) runs need a snapshot of your model-proxy creds. If morning runs start failing
model auth, open pi and say:

> "re-link my scheduler creds"

(That runs `~/buddy-scheduler/link-creds.sh`.) Your MCP tool token refreshes automatically whenever
you open pi normally.

---

## 🧠 What BUDDY does (the rules live in `AGENTS.md`)

- **§0** Any greeting fires the morning routine automatically — no prompt needed.
- **§1** Full owned-deal roster from BigQuery `sales_opportunities_v2` (not just book-scoped CRM).
- **§2** Morning note-fill: writes CRM notes only where something genuinely moved; refreshes the cockpit.
- **§2c** CRM is a starting point, not the truth — **always** cross-reference Gmail (incl. Sent) + calendar.
- **§3** Auto-queue drafts only to external contacts you've spoken to — **never** to `@shopify.com`.
- **§4** T-30 pre-call prep for **external** calls only, branched first-call vs follow-up.

Personalise `AGENTS.md` freely — it's your brain now.

---

## 🗑️ Uninstall

```bash
./uninstall.sh
```

Removes the launchd agent, scheduler, skill and cockpit folder (backs them up first). Does **not**
touch your pi install or MCP config.

---

## Not on macOS?

The skill and cockpit still work — you just won't get the always-on launchd scheduler. Open pi and
say `gm` each morning; everything else is identical.

---

*Built by Amir Pas. Shared with love. 🎁*
