#!/bin/bash
# End-to-end exercise of the production runtime.
#
# Everything it creates is prefixed E2E- so it can be told apart from real
# data and removed. It asserts rather than prints where it can, because a
# script that only prints is one somebody skims.
set -uo pipefail

URL="https://citadel-exigence-runtime-3dnspttzga-uc.a.run.app"
P="/v1/projects/citadel-platform/exigence"
STAMP=$(date -u +%m%d%H%M%S)
PASS=0
FAIL=0

tok() { gcloud auth print-identity-token 2>/dev/null; }

check() { # name, expected, actual
  if [ "$2" = "$3" ]; then
    printf "  ✓ %s\n" "$1"; PASS=$((PASS+1))
  else
    printf "  ✗ %s (expected %s, got %s)\n" "$1" "$2" "$3"; FAIL=$((FAIL+1))
  fi
}

api() { # method, path, [body]
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    curl -s -X "$method" -H "Authorization: Bearer $(tok)" \
      -H "content-type: application/json" -H "x-citadel-actor-id: operator" \
      -H "idempotency-key: e2e-$STAMP-$RANDOM" -d "$body" "$URL$P/$path"
  else
    curl -s -X "$method" -H "Authorization: Bearer $(tok)" \
      -H "x-citadel-actor-id: operator" -H "idempotency-key: e2e-$STAMP-$RANDOM" \
      "$URL$P/$path"
  fi
}

# Reads a dotted path out of a JSON body. Passed as an argument rather than
# interpolated into the program, because the keys contain quotes and the
# previous version silently produced an empty string for every call.
jq_get() {
  python3 -c '
import sys, json
value = json.load(sys.stdin)
for key in sys.argv[1].split("."):
    if value is None: break
    value = value.get(key) if isinstance(value, dict) else None
print("" if value is None else value)
' "$1" 2>/dev/null
}

echo "== 1. Run lifecycle =="
RUN=$(api POST "automations/exigence.reference.summary/runs" \
  '{"payload":{"reason":"e2e"}}' | jq_get "run.runId")
[ -n "$RUN" ] && { printf "  ✓ run created: %s\n" "${RUN:0:24}…"; PASS=$((PASS+1)); } \
              || { printf "  ✗ run not created\n"; FAIL=$((FAIL+1)); }

for _ in $(seq 1 30); do
  STATUS=$(curl -s -H "Authorization: Bearer $(tok)" "$URL$P/runs/$RUN" | jq_get "run.status")
  [ "$STATUS" = "awaiting_approval" ] && break
  sleep 4
done
check "holds for approval at the write step" "awaiting_approval" "$STATUS"

APPROVAL=$(curl -s -H "Authorization: Bearer $(tok)" "$URL$P/approvals" \
  | python3 -c "
import sys,json
d=json.load(sys.stdin)
for a in d.get('approvals',[]):
    if a.get('runId')=='$RUN': print(a['approvalId']); break
" 2>/dev/null)
[ -n "$APPROVAL" ] && { printf "  ✓ approval is in the inbox\n"; PASS=$((PASS+1)); } \
                   || { printf "  ✗ approval missing from inbox\n"; FAIL=$((FAIL+1)); }

if [ -n "$APPROVAL" ]; then
  api POST "runs/$RUN/approvals/$APPROVAL/resolution" \
    '{"status":"approved","note":"e2e verification"}' >/dev/null
  for _ in $(seq 1 30); do
    STATUS=$(curl -s -H "Authorization: Bearer $(tok)" "$URL$P/runs/$RUN" | jq_get "run.status")
    [ "$STATUS" = "succeeded" ] && break
    sleep 4
  done
  check "completes after approval" "succeeded" "$STATUS"
fi

echo "== 2. Cost of that run =="
COST=$(curl -s -H "Authorization: Bearer $(tok)" "$URL$P/billing/executions/$RUN")
SUMS=$(echo "$COST" | python3 -c "
import sys,json
e=json.load(sys.stdin)['execution']
print('yes' if sum(int(l['amountNanos']) for l in e['lines'])==int(e['totalNanos']) else 'no')
" 2>/dev/null)
check "itemised lines sum to the total" "yes" "$SUMS"
PARTIAL=$(echo "$COST" | jq_get "execution.partial")
check "nothing it meters is missing" "False" "$PARTIAL"
HAS_FS=$(echo "$COST" | python3 -c "
import sys,json
items={l['item'] for l in json.load(sys.stdin)['execution']['lines']}
print('yes' if 'firestore_read' in items and 'firestore_write' in items else 'no')
" 2>/dev/null)
check "Firestore documents are metered" "yes" "$HAS_FS"

echo "== 3. Knowledge Base =="
SRC="e2e-$STAMP"
CODE=$(api POST "knowledge-base/sources" \
  "{\"sourceId\":\"$SRC\",\"kind\":\"url\",\"displayName\":\"E2E page\",\"locator\":\"https://citadel.obsivision.com/\",\"allowedHosts\":[\"citadel.obsivision.com\"]}" \
  | jq_get "source.sourceId")
check "source registered" "$SRC" "$CODE"

SUMMARY=$(api POST "knowledge-base/sources/$SRC/sync" | jq_get "sync.summary")
[ "${SUMMARY:0:9}" = "1 indexed" ] && { printf "  ✓ sync indexed the page\n"; PASS=$((PASS+1)); } \
                                   || { printf "  ✗ sync: %s\n" "$SUMMARY"; FAIL=$((FAIL+1)); }

AGAIN=$(api POST "knowledge-base/sources/$SRC/sync" | jq_get "sync.summary")
[ "${AGAIN:0:11}" = "1 unchanged" ] && { printf "  ✓ re-sync re-embedded nothing\n"; PASS=$((PASS+1)); } \
                                    || { printf "  ✗ re-sync: %s\n" "$AGAIN"; FAIL=$((FAIL+1)); }

ANSWER=$(api POST "knowledge-base/conversations/e2e$STAMP/messages" \
  '{"message":"what is Citadel?","messageNumber":1}')
CITED=$(echo "$ANSWER" | python3 -c "
import sys,json
a=json.load(sys.stdin)['answer']
print('yes' if a['citations'] and not a['unanswered'] else 'no')
" 2>/dev/null)
check "chat answered with a citation" "yes" "$CITED"
COSTED=$(echo "$ANSWER" | python3 -c "
import sys,json
print('yes' if json.load(sys.stdin)['answer'].get('cost') else 'no')" 2>/dev/null)
check "chat was metered" "yes" "$COSTED"

MISS=$(api POST "knowledge-base/conversations/e2e${STAMP}b/messages" \
  '{"message":"what is the capital of Peru?","messageNumber":1}')
UNANS=$(echo "$MISS" | jq_get "answer.unanswered")
check "an unanswerable question says so" "True" "$UNANS"
NOCITE=$(echo "$MISS" | python3 -c "
import sys,json
a=json.load(sys.stdin)['answer']
print('yes' if not a['citations'] else 'no')" 2>/dev/null)
check "and cites nothing" "yes" "$NOCITE"
NOCOST=$(echo "$MISS" | python3 -c "
import sys,json
print('yes' if json.load(sys.stdin)['answer'].get('cost') else 'no')" 2>/dev/null)
check "but still reports what the attempt cost" "yes" "$NOCOST"

echo "== 4. Billing lifecycle =="
# Reserved months, not the live one. Reconciling the current month to make a
# test pass writes a fabricated figure into the record that decides whether a
# real client can be invoiced.
OPEN_MONTH="2000-01"    # never reconciled by this script
CLOSED_MONTH="2000-02"  # reconciled every run; the PUT is idempotent
INV_OPEN="E2E-$STAMP-O"
INV="E2E-$STAMP-C"

UNRECONCILED=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Authorization: Bearer $(tok)" -H "content-type: application/json" \
  -H "x-citadel-actor-id: operator" -H "idempotency-key: e2e-$STAMP-x" \
  -d '{"dueAt":"2026-12-31T00:00:00.000Z"}' \
  "$URL$P/billing/invoices/$INV_OPEN/issue")
check "issuing a nonexistent invoice is refused" "404" "$UNRECONCILED"

api POST "billing/invoices" \
  "{\"invoiceId\":\"$INV_OPEN\",\"month\":\"$OPEN_MONTH\",\"currency\":\"USD\",\"lines\":[{\"lineId\":\"l-1\",\"kind\":\"metered_cost\",\"description\":\"E2E verification\",\"amountNanos\":\"1000000\"}]}" >/dev/null
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Authorization: Bearer $(tok)" -H "content-type: application/json" \
  -H "x-citadel-actor-id: operator" -H "idempotency-key: e2e-$STAMP-y" \
  -d '{"dueAt":"2026-12-31T00:00:00.000Z"}' "$URL$P/billing/invoices/$INV_OPEN/issue")
check "an unreconciled month cannot be invoiced" "409" "$CODE"

api PUT "billing/reconciliations/$CLOSED_MONTH" \
  '{"currency":"USD","meteredTotalNanos":"100000000000","invoicedTotalNanos":"87000000000","source":"billing_console_csv","note":"E2E verification"}' >/dev/null
api POST "billing/invoices" \
  "{\"invoiceId\":\"$INV\",\"month\":\"$CLOSED_MONTH\",\"currency\":\"USD\",\"lines\":[{\"lineId\":\"l-1\",\"kind\":\"metered_cost\",\"description\":\"E2E verification\",\"amountNanos\":\"1000000\"}]}" >/dev/null
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Authorization: Bearer $(tok)" -H "content-type: application/json" \
  -H "x-citadel-actor-id: operator" -H "idempotency-key: e2e-$STAMP-z" \
  -d '{"dueAt":"2026-12-31T00:00:00.000Z"}' "$URL$P/billing/invoices/$INV/issue")
check "a reconciled month can be" "200" "$CODE"

CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Authorization: Bearer $(tok)" -H "content-type: application/json" \
  -H "x-citadel-actor-id: operator" -H "idempotency-key: e2e-$STAMP-w" \
  -d "{\"invoiceId\":\"$INV\",\"month\":\"$CLOSED_MONTH\",\"currency\":\"USD\",\"lines\":[{\"lineId\":\"l-1\",\"kind\":\"metered_cost\",\"description\":\"changed\",\"amountNanos\":\"1\"}]}" \
  "$URL$P/billing/invoices")
check "an issued invoice cannot be rewritten" "409" "$CODE"

CN=$(api POST "billing/invoices/$INV/credit-notes" \
  "{\"creditNoteId\":\"CN-$STAMP\",\"reason\":\"E2E verification\",\"lines\":[{\"lineId\":\"c-1\",\"kind\":\"metered_cost\",\"description\":\"partial credit\",\"amountNanos\":\"400000\"}]}" \
  | jq_get "creditNote.totalNanos")
check "a correction is a credit note" "400000" "$CN"

OUT=$(curl -s -H "Authorization: Bearer $(tok)" "$URL$P/billing/invoices/$INV" \
  | jq_get "invoice.outstandingNanos")
check "outstanding reflects the credit" "600000" "$OUT"

echo "== 5. Reconciliation and summary =="
MONTH=$(date -u +%Y-%m)
SUM=$(curl -s -H "Authorization: Bearer $(tok)" "$URL$P/billing/summary?month=$MONTH")
HAS=$(echo "$SUM" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print('yes' if d['executionCount']>0 and d['byArtifact'] else 'no')" 2>/dev/null)
check "the month summarises its executions" "yes" "$HAS"

# An unreconciled month must present its figure as an estimate. The earlier
# version of this check asserted "reconciled" and only passed because a prior
# run had written a fabricated reconciliation into the live month — the test
# was manufacturing the state it then verified.
LABEL=$(curl -s -H "Authorization: Bearer $(tok)" "$URL$P/billing/executions/$RUN" | python3 -c "
import sys,json
e=json.load(sys.stdin)['execution']
ok = e['metered']['confidence']=='metered' and 'reconciled' not in e
print('estimate' if ok else 'mislabelled')" 2>/dev/null)
check "an unreconciled figure is labelled an estimate, not a bill" "estimate" "$LABEL"

# Removes what this run created. A suite that leaves its fixtures behind
# turns the live Knowledge Base into a pile of "E2E page" entries, and every
# one of them is a document a real question can retrieve and cite.
echo "== cleanup =="
curl -s -o /dev/null -X DELETE -H "Authorization: Bearer $(tok)" \
  -H "x-citadel-actor-id: operator" -H "idempotency-key: del-$SRC" \
  "$URL$P/knowledge-base/sources/$SRC"
LEFT=$(curl -s -H "Authorization: Bearer $(tok)" "$URL$P/knowledge-base/sources" | python3 -c "
import sys,json
print(sum(1 for s in json.load(sys.stdin).get('sources',[]) if s['sourceId'].startswith('e2e-')))" 2>/dev/null)
check "the suite left no sources behind" "0" "$LEFT"

echo
printf "passed %d, failed %d\n" "$PASS" "$FAIL"
echo "left in place: invoices $INV_OPEN,$INV in reserved months $OPEN_MONTH,$CLOSED_MONTH"
[ "$FAIL" -eq 0 ]
