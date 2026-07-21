#!/usr/bin/env bash
# apply-nosplash-autologin.sh
#
# Dev-only stratos-v3 customization: replicate the legacy Stratos 4.x
# "no splash" behaviour where, when SSO is configured with the `nosplash`
# option, the /login page immediately redirects to the UAA login screen
# instead of pausing on a page with a "Sign In" button.
#
# In 5.x the nosplash auto-redirect only runs inside the "already logged in"
# branch of LoginPageComponent.ngOnInit (guarded by auth.loggedIn &&
# sessionData.valid), so a fresh visit with no session never auto-redirects.
# This script injects an additional subscription that triggers the SSO login
# flow on first load when there is NO valid session but SSO nosplash is set.
#
# Idempotent: exits 0 without changes if the marker is already present.
# Fails (non-zero) if the anchor cannot be found, so the build surfaces drift
# rather than silently shipping the click-through page.

set -euo pipefail

ROOT="${1:-.}"
FILE="${ROOT}/src/frontend/packages/core/src/features/login/login-page/login-page.component.ts"

MARKER="STRATOS_V3_NOSPLASH_AUTOLOGIN"

if [ ! -f "$FILE" ]; then
  echo "ERROR: login-page.component.ts not found at $FILE" >&2
  exit 1
fi

if grep -q "$MARKER" "$FILE"; then
  echo "[nosplash] marker already present — skipping (idempotent)"
  exit 0
fi

# Anchor: the "Subscribe to message$ to keep it updated" line near the end of
# ngOnInit(). We insert our auto-login subscription immediately before it.
ANCHOR="    // Subscribe to message\$ to keep it updated"

if ! grep -qF "$ANCHOR" "$FILE"; then
  echo "ERROR: anchor line not found in $FILE — upstream login-page.component.ts changed." >&2
  echo "       Review and update apply-nosplash-autologin.sh before building." >&2
  exit 1
fi

# Use a Node script for a safe, well-scoped text insertion (no sed escaping pain).
node - "$FILE" "$MARKER" <<'NODE'
const fs = require('fs');
const [file, marker] = process.argv.slice(2);
let src = fs.readFileSync(file, 'utf8');

const anchor = "    // Subscribe to message$ to keep it updated";
const idx = src.indexOf(anchor);
if (idx === -1) {
  console.error('ERROR: anchor not found at insertion time');
  process.exit(1);
}

const injection = `    // ${marker}: Legacy 4.x "nosplash" behaviour — when SSO is configured
    // with the nosplash option and there is no valid session yet, redirect
    // straight to the UAA login screen instead of showing the Sign In button.
    this.auth$.pipe(
      filter(auth =>
        !auth.loggingIn &&
        !auth.verifying &&
        !auth.loggedIn &&
        !!auth.sessionData &&
        !auth.sessionData.valid &&
        !!auth.sessionData.ssoOptions &&
        auth.sessionData.ssoOptions.indexOf('nosplash') >= 0 &&
        !queryParamMap().SSO_Message
      ),
      take(1),
      switchMap(() => this.appReady$)
    ).subscribe(() => {
      this.doSSOLoginReactive().subscribe();
    });

`;

src = src.slice(0, idx) + injection + src.slice(idx);
fs.writeFileSync(file, src);
console.log('[nosplash] injected auto-login subscription into ' + file);
NODE

echo "[nosplash] done"
