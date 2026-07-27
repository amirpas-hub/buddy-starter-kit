#!/bin/bash
# Publish your BUDDY Cockpit to the web.
# The Quick handle is set by install.sh (your own handle — never someone else's).
set -e
cd "$(dirname "$0")"
HANDLE="__COCKPIT_HANDLE__"
quick deploy . "$HANDLE"
echo "✅ Cockpit live: https://${HANDLE}.quick.shopify.io"
