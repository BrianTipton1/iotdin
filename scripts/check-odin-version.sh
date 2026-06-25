#!/usr/bin/env sh
#
# Verify the Odin compiler on PATH matches the version pinned in .odin-version.
# Run locally before committing; CI runs this exact script.
#
#   ./scripts/check-odin-version.sh            # uses ./.odin-version
#   ./scripts/check-odin-version.sh path/to/.odin-version
#
# Matching rules (handles nightly vs monthly correctly):
#   lock "dev-2026-06"                 -> installed base must equal dev-2026-06
#                                         (a nightly of that month does NOT match)
#   lock "dev-2026-06-nightly"         -> any nightly from that month matches
#   lock "dev-2026-06-nightly:7ab61e4" -> commit must match exactly
#
# Exits 0 on match, non-zero on mismatch or error.

set -eu

# The lock file lives at the repo root (the parent of this scripts/ dir).
# Resolve it relative to the script's own location so this works no matter
# what directory you run it from. An explicit path argument overrides it.
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LOCK_FILE="${1:-$script_dir/../.odin-version}"

if [ ! -f "$LOCK_FILE" ]; then
    echo "error: lock file '$LOCK_FILE' not found" >&2
    exit 1
fi

# First non-blank, non-comment line, whitespace stripped.
expected=$(sed -e 's/#.*$//' "$LOCK_FILE" | grep -v '^[[:space:]]*$' | head -n 1 | tr -d '[:space:]')
if [ -z "$expected" ]; then
    echo "error: no version found in '$LOCK_FILE'" >&2
    exit 1
fi

if ! command -v odin >/dev/null 2>&1; then
    echo "error: 'odin' not found on PATH" >&2
    exit 1
fi

# e.g. "odin version dev-2026-06-nightly:7ab61e4" -> "dev-2026-06-nightly:7ab61e4"
actual_raw=$(odin version 2>&1)
actual=$(printf '%s' "$actual_raw" | sed -e 's/.*odin version //' | tr -d '[:space:]')

# Split "base:commit" into base + commit (commit empty if no colon).
split_base() { printf '%s' "$1" | cut -d: -f1; }
split_commit() {
    case "$1" in
        *:*) printf '%s' "$1" | cut -d: -f2- ;;
        *)   printf '' ;;
    esac
}

want_base=$(split_base "$expected")
want_commit=$(split_commit "$expected")
got_base=$(split_base "$actual")
got_commit=$(split_commit "$actual")

ok=1
[ "$want_base" = "$got_base" ] || ok=0
if [ -n "$want_commit" ] && [ "$want_commit" != "$got_commit" ]; then ok=0; fi

if [ "$ok" = 1 ]; then
    echo "Odin version OK: locked '$expected' matches installed '$actual'"
    exit 0
fi

echo "Odin version MISMATCH" >&2
echo "  locked   (.odin-version): $expected" >&2
echo "  installed (odin version): $actual" >&2
echo >&2
case "$want_base" in
    *-nightly)
        echo "This is a nightly pin. setup-odin only installs the latest nightly," >&2
        echo "so if upstream moved on, install your locked nightly locally, or bump" >&2
        echo ".odin-version to the new nightly (or drop the ':commit' for a looser pin)." >&2
        ;;
    *)
        echo "Install the locked Odin release, or update .odin-version if you" >&2
        echo "deliberately want to bump the pinned version (then commit that change)." >&2
        ;;
esac
exit 1