#!/usr/bin/env bash
# Deterministic extractor for LinkedIn "Recommended" jobs via agent-browser.
# Produces two files:
#   <out>            JSON array of {title, salary_range:null, description}  (salary left for judgment)
#   <out>.evidence   JSON array of {id, title, field, snippets}            (compact salary evidence)
# Salary is intentionally NOT decided here: a $-figure in a description can be market size,
# funding, fees, or equity %. Decide salary_range from the evidence sidecar (LLM or human).
#
# Usage: extract_recommended.sh [count] [output_path]
set -uo pipefail

N="${1:-20}"
OUT="${2:-./recommended_jobs.json}"
EVID="${OUT%.json}.evidence.json"
PROFILE="$HOME/.agent-browser/linkedin"
ROUTE="https://www.linkedin.com/jobs/collections/recommended/"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
ab(){ agent-browser "$@"; }

# Open (profile flag only takes effect on a cold daemon; the "ignored" warning is harmless).
ab open "$ROUTE" --profile "$PROFILE" >/dev/null 2>&1
ab wait "li.scaffold-layout__list-item" >/dev/null 2>&1 || true

# Auth guard.
if ab eval --json "/Sign in to view more jobs/.test(document.body.innerText)" 2>/dev/null | grep -q '"result":true'; then
  echo "ERROR: not authenticated (LinkedIn sign-in wall)." >&2
  echo "Re-login: agent-browser close && agent-browser --profile \"$PROFILE\" --headed open \"$ROUTE\"" >&2
  exit 1
fi

# Dismiss cookie/consent banner if present (it blocks job selection otherwise).
ab eval '(() => { const b=[...document.querySelectorAll("button,a")].find(x=>/^(accept|accept all|reject|reject all|agree)\b/i.test((x.innerText||"").trim())); if(b){b.click(); return "dismissed"} return "none" })()' >/dev/null 2>&1

# Harvest job ids by paginating (?start=N, 24/page) until we reach N, or until the
# collection is exhausted when N is "all" (or 0).
get_page_ids(){ ab eval --json '(() => [...document.querySelectorAll("li.scaffold-layout__list-item[data-occludable-job-id]")].map(l=>l.getAttribute("data-occludable-job-id")))()' 2>/dev/null | jq -r '.data.result[]?'; }
PER=24
ALL=0; case "$N" in all|All|ALL|0) ALL=1 ;; esac
collected=""; start=0; prev=0
while :; do
  ab open "$ROUTE?start=$start" >/dev/null 2>&1
  ab wait "li.scaffold-layout__list-item" >/dev/null 2>&1
  ab wait 800 >/dev/null 2>&1
  collected="$collected"$'\n'"$(get_page_ids)"
  IDS="$(printf '%s\n' "$collected" | awk 'NF && !seen[$0]++')"
  after="$(printf '%s\n' "$IDS" | grep -c .)"
  echo "  harvest start=$start -> $after unique ids" >&2
  if [ "$ALL" -eq 0 ] && [ "$after" -ge "$N" ]; then IDS="$(printf '%s\n' "$IDS" | head -n "$N")"; break; fi
  [ "$after" -le "$prev" ] && break          # no new ids -> end of collection
  prev="$after"; start=$((start + PER))
  [ "$start" -gt 2400 ] && break             # hard safety cap (~100 pages)
done
COUNT="$(printf '%s\n' "$IDS" | grep -c .)"
echo "harvested $COUNT job ids" >&2

# Per-job extraction JS (panel-scoped so the cookie banner's <h1> can't pollute the title).
read -r -d '' JS <<'JS_EOF'
(() => {
  const panel = document.querySelector('.jobs-search__job-details, .job-view-layout') || document.body;
  const titleEl = panel.querySelector('.job-details-jobs-unified-top-card__job-title') || panel.querySelector('h1');
  const jd = document.querySelector('#job-details');
  const pref = panel.querySelector('.job-details-fit-level-preferences');
  const snippets = [];
  if (jd) { const t = jd.innerText, re = /[$€£]/g; let m;
    while ((m = re.exec(t)) && snippets.length < 8) snippets.push(t.slice(Math.max(0, m.index-35), m.index+45).replace(/\s+/g,' ').trim()); }
  return { title: titleEl ? titleEl.innerText.trim() : null, salary_range: null,
           description: jd ? jd.innerText.trim() : null,
           salary_evidence: { field: pref ? pref.innerText.replace(/\n/g,' | ').trim() : null, snippets } };
})()
JS_EOF

# Loop: select each job by URL, wait for the panel to reflect THAT id, extract to a per-job file.
# Fingerprint of the job currently shown in the panel: title + description length.
# Changes when the panel swaps to a new job. Used instead of `networkidle` (LinkedIn
# never idles, so networkidle hit its ~25s timeout every iteration) and instead of the
# panel data-job-id (absent on some jobs). Title+length also distinguishes two postings
# that share a title but differ in body.
FP_JS='(() => { const p=document.querySelector(".jobs-search__job-details, .job-view-layout"); const e=p&&(p.querySelector(".job-details-jobs-unified-top-card__job-title")||p.querySelector("h1")); const jd=document.querySelector("#job-details"); const t=e?e.innerText.replace(/\s+/g," ").trim():""; const n=jd?jd.innerText.trim().length:0; return (t && n>200) ? (t+"|"+n) : ""; })()'
read_fp(){ printf '%s' "$FP_JS" | ab eval --stdin --json 2>/dev/null | jq -r '.data.result // ""'; }

i=0
PREV=""
for id in $IDS; do
  i=$((i+1))
  ab open "$ROUTE?currentJobId=$id" >/dev/null 2>&1
  # Poll (bounded ~12s) until the panel reflects a new, fully-loaded job.
  tries=0; cur=""
  while [ "$tries" -lt 25 ]; do
    cur="$(read_fp)"
    [ -n "$cur" ] && [ "$cur" != "$PREV" ] && break
    ab wait 300 >/dev/null 2>&1
    tries=$((tries + 1))
  done
  PREV="$cur"
  printf '%s' "$JS" | ab eval --stdin > "$WORK/$id.json" 2>/dev/null
  echo "[$i/$COUNT] $id (${tries} polls)" >&2
done

# Assemble: main output (salary null) + evidence sidecar, preserving list order.
export IDS_ORDER="$IDS"
python3 - "$WORK" "$OUT" "$EVID" <<'PY'
import json, sys, glob, os
work, out, evid = sys.argv[1], sys.argv[2], sys.argv[3]
files = {os.path.basename(f)[:-5]: f for f in glob.glob(work + "/*.json")}
order = [i for i in os.environ.get("IDS_ORDER", "").split() if i in files] or sorted(files)
jobs, evidence = [], []
for jid in order:
    d = json.load(open(files[jid]))
    jobs.append({"title": d.get("title"), "salary_range": d.get("salary_range"), "description": d.get("description")})
    ev = d.get("salary_evidence", {})
    evidence.append({"id": jid, "title": d.get("title"), "field": ev.get("field"), "snippets": ev.get("snippets", [])})
json.dump(jobs, open(out, "w"), ensure_ascii=False, indent=2)
json.dump(evidence, open(evid, "w"), ensure_ascii=False, indent=2)
print(f"wrote {len(jobs)} jobs -> {out}")
print(f"wrote evidence -> {evid}")
PY