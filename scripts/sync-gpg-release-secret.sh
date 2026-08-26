#!/usr/bin/env bash
# sync-gpg-release-secret.sh — push the GPG release-signing secret to N repos in one command.
#
# Why: guilhermelinosp is a PERSONAL account (no org-level secrets available),
# so each repo needs its own Actions secret. This script removes the manual,
# repo-by-repo burden — including future rotations.
#
# Usage:
#   export GPG_PRIVATE_KEY_FILE=/path/to/armored-private-key.asc   # required
#   export GPG_PASSPHRASE='...'                                    # optional (key has none by default)
#
#   ./scripts/sync-gpg-release-secret.sh                    # syncs the default set below
#   ./scripts/sync-gpg-release-secret.sh hellnet-dep-database  # sync specific repo(s)
#   ./scripts/sync-gpg-release-secret.sh --dry-run          # show what would happen
#
# Rotate the release key:
#   1. gpg --quick-generate-key "guilhermelinosp (Hellnet release signing)" ed25519 sign never
#   2. gpg --armor --export-secret-keys <FPR> > /secure/location/release-key.asc
#   3. gpg --armor --export <FPR> > signing-key.asc && open PR updating it here
#   4. run this script for every repo that signs releases
set -euo pipefail

OWNER="guilhermelinosp"
DRY_RUN=0
REPOS=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    *) REPOS+=("$arg") ;;
  esac
done

# Default set = repos enrolled in signed releases.
if [ ${#REPOS[@]} -eq 0 ]; then
  REPOS=(hellnet-lib-cache hellnet-lib-kafka hellnet-lib-telemetry \
         hellnet-lib-environments golang-lib-template)
fi

KEY_FILE="${GPG_PRIVATE_KEY_FILE:-}"
if [ -z "$KEY_FILE" ]; then
  echo "ERROR: GPG_PRIVATE_KEY_FILE is not set." >&2
  echo "Export it first:" >&2
  echo "  gpg --armor --export-secret-keys <FINGERPRINT> > /secure/path/release-key.asc" >&2
  echo "  export GPG_PRIVATE_KEY_FILE=/secure/path/release-key.asc" >&2
  exit 1
fi
if ! grep -q "BEGIN PGP PRIVATE KEY BLOCK" "$KEY_FILE"; then
  echo "ERROR: $KEY_FILE does not look like an armored private key." >&2
  exit 1
fi

echo "Owner:      $OWNER"
echo "Key file:   $KEY_FILE ($(wc -c < "$KEY_FILE") bytes)"
[ -n "${GPG_PASSPHRASE:-}" ] && echo "Passphrase: provided" || echo "Passphrase: none (key is passphrase-less)"
echo "Repos:      ${REPOS[*]}"
[ "$DRY_RUN" -eq 1 ] && echo "(dry run — no changes will be made)"
echo ""

FAILED=0
for r in "${REPOS[@]}"; do
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry] gh secret set GPG_PRIVATE_KEY -R $OWNER/$r"
    continue
  fi
  if gh secret set GPG_PRIVATE_KEY -R "$OWNER/$r" --body-file "$KEY_FILE"; then
    echo "✓ $r: GPG_PRIVATE_KEY updated"
  else
    echo "✗ $r: FAILED to set GPG_PRIVATE_KEY" >&2
    FAILED=$((FAILED + 1))
    continue
  fi
  if [ -n "${GPG_PASSPHRASE:-}" ]; then
    if gh secret set GPG_PASSPHRASE -R "$OWNER/$r" --body "$GPG_PASSPHRASE"; then
      echo "✓ $r: GPG_PASSPHRASE updated"
    else
      echo "✗ $r: FAILED to set GPG_PASSPHRASE" >&2
      FAILED=$((FAILED + 1))
    fi
  fi
done

if [ "$FAILED" -gt 0 ]; then
  echo "" >&2
  echo "$FAILED repo(s) failed — see output above." >&2
  exit 1
fi

echo ""
[ "$DRY_RUN" -eq 1 ] || echo "Done. Next release in each repo will use the updated key."
