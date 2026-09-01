#!/bin/bash
# Mints a Firebase ID token for the operator, so a real Platform API call can
# be made from a terminal.
#
# Every other check of the deployed API stops at the token boundary: it can
# prove a route exists (401 rather than 404) and nothing about what the route
# does. This closes that, without downloading a service account key — the
# operator holds `serviceAccountTokenCreator` on the Firebase admin identity,
# which is declared in the production runtime root and is the reason it exists.
#
# Two steps, because Firebase has two kinds of token: the admin identity signs
# a *custom* token, and Identity Toolkit exchanges that for the *ID* token the
# API actually verifies.
#
#   source citadel_core/.env
#   bash _dev/scripts/mint_operator_id_token.sh
set -euo pipefail

SA="${CITADEL_FIREBASE_ADMIN_SA:-firebase-adminsdk-fbsvc@citadel-platform.iam.gserviceaccount.com}"
UID_CLAIM="${CITADEL_OPERATOR_UID:-operator-e2e}"
EMAIL="${CITADEL_OPERATOR_EMAIL:-obsidian.infinitum@gmail.com}"

if [ -z "${FB_API_KEY:-}" ]; then
  echo "FB_API_KEY is not set. Source citadel_core/.env first." >&2
  exit 2
fi

NOW=$(date +%s)
# The audience Firebase requires for a custom token, verbatim.
CLAIMS=$(python3 - "$SA" "$UID_CLAIM" "$EMAIL" "$NOW" <<'PY'
import json, sys
sa, uid, email, now = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
print(json.dumps({
    "iss": sa,
    "sub": sa,
    "aud": "https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit",
    "iat": now,
    "exp": now + 3600,
    "uid": uid,
    # Carried into the ID token, because the Platform API identifies a caller
    # by address: a token with no email resolves to no workspace at all.
    "claims": {"email": email, "email_verified": True},
}))
PY
)

CUSTOM=$(gcloud iam service-accounts sign-jwt --iam-account "$SA" \
  <(printf '%s' "$CLAIMS") /dev/stdout 2>/dev/null)

ID_TOKEN=$(curl -s -X POST \
  "https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${FB_API_KEY}" \
  -H 'content-type: application/json' \
  -d "$(python3 -c 'import json,sys; print(json.dumps({"token": sys.argv[1], "returnSecureToken": True}))' "$CUSTOM")" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin).get("idToken",""))')

if [ -z "$ID_TOKEN" ]; then
  echo "No ID token came back. The custom token was signed but not exchanged." >&2
  exit 1
fi
printf '%s\n' "$ID_TOKEN"
