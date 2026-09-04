# The Console's Google OAuth client — what to create, and the gotcha

Everything in the code is done and tested. The only missing thing is an
artefact that can only be made in the Cloud Console: Google exposes IAP-type
OAuth clients through an API, but a browser JavaScript flow needs a **Web
application** client, and those are Console-only.

## What it is for

Onboarding a client has exactly one step Citadel cannot perform itself.
Provisioning runs as Citadel, but on a client's brand-new GCP project Citadel's
identity has no rights at all — someone who already administers that project
has to enable the APIs and grant Citadel its roles. That someone is the
operator, and this client id is what lets the Console open a Google window and
get a token for the operator's **own** account, scoped to
`https://www.googleapis.com/auth/cloud-platform`.

Without it `platform_client_bootstrap_step` throws `notConfigured`, which the
Console already reports correctly as "Authorisation is not set up · Rebuild the
console with CITADEL_PLATFORM_GOOGLE_OAUTH_CLIENT_ID set". Nothing else is
affected — every other screen works.

## The gotcha, first, because it changes what you choose

`citadel-platform` has **no organization**: `gcloud projects describe` reports no
parent and `gcloud organizations list` returns nothing. It is a standalone
project under a personal account.

That means the OAuth consent screen **must be External** — "Internal" is only
offered to projects inside a Google Workspace organization. And
`cloud-platform` is a **restricted** scope. For an External app that leaves two
options:

* **Testing** — works immediately, no verification. Limited to test users you
  add by hand (up to 100). Operators will see an "unverified app" interstitial
  and have to click through it. **This is the right choice**: the audience is a
  handful of operators, all of whom you can name.
* **Production** — requires Google verification, and for a restricted scope like
  `cloud-platform` that means a security assessment. Weeks, and unnecessary for
  an internal operator tool.

So: leave the consent screen in **Testing**, and add each operator's Google
account as a test user. The "unverified app" screen is expected, not a fault —
worth saying out loud to whoever sees it first.

## What to create

In the Cloud Console for project **citadel-platform**:

1. **APIs & Services → OAuth consent screen**
   - User type: **External**
   - Publishing status: leave in **Testing**
   - Test users: add every operator who will onboard a client, starting with
     `siddharth.chitikela@gmail.com`
   - Scopes: nothing to add here — the scope is requested at runtime by the
     Console, and listing it on the consent screen is not required for it to
     be granted.

2. **APIs & Services → Credentials → Create credentials → OAuth client ID**
   - Application type: **Web application**
   - Name: anything; `Citadel Console` is clear
   - **Authorised JavaScript origins** — both, because both serve the Console:
     - `https://citadel-platform.web.app`
     - `https://citadel-platform.firebaseapp.com`
     - and `http://127.0.0.1:8792` if you want the local seed build to authorise
   - **Authorised redirect URIs: none.** The Console uses Google Identity
     Services' token flow, which is a popup and never redirects. Adding one is
     harmless but it is not what makes this work — the origin is.

3. Copy the client id (it ends `.apps.googleusercontent.com`) into the repo's
   `.env` as:

   ```
   GOOGLE_OAUTH_CLIENT_ID=<the id>
   ```

4. Rebuild and deploy the Console through
   `scripts/flutter_with_platform_env.sh`, which is what turns the variable into
   the compile-time define. A build made any other way silently omits it — that
   is why the script exists, and why it warns on a release build without it.

## Why the id is not a secret

Google matches the **page's origin**, not a credential. The id ships inside the
built page and is meant to. What stops it being used elsewhere is the origins
list in step 2, which is why that list is the part worth getting right.

## How to know it worked

Open a client's setup plan and reach the step that admits Citadel to their
project. Pressing **Authorise with Google** should open a Google window rather
than reporting "Authorisation is not set up". Closing that window on purpose is
reported as "Not authorised yet" and is not a fault — the Console classifies a
dismissed window separately from a refused one for exactly that reason.
