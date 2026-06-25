#!/usr/bin/env sh
#
# Update .odin-version to pin the Odin compiler you currently have locally
# (or an explicit version you pass in). Run this after `odin update` / after
# switching toolchains, then commit the changed .odin-version.
#
#   ./scripts/update-odin-version.sh                  # pin current `odin version`
#   ./scripts/update-odin-version.sh --base           # ...but drop the :commit
#   ./scripts/update-odin-version.sh --exact          # ...always keep the :commit
#   ./scripts/update-odin-version.sh dev-2026-05      # pin an explicit version
#
# Default (auto) behaviour:
#   - nightly  -> keep the commit   (e.g. dev-2026-06-nightly:7ab61e4)
#   - monthly  -> drop the commit   (e.g. dev-2026-06), the durable tag form
#
# The comment header in .odin-version is preserved; only the version line is
# rewritten (or appended if the file has none yet).

set -eu

usage() {
    sed -n '2,/^set -eu$/p' "$0" | sed -e 's/^# \{0,1\}//' -e '/^set -eu$/d'
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LOCK_FILE="$script_dir/../.odin-version"

mode=auto
explicit=""
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --exact) mode=exact ;;
        --base|--no-commit) mode=base ;;
        --) shift; break ;;
        -*) echo "error: unknown option '$1'" >&2; exit 2 ;;
        *) if [ -n "$explicit" ]; then echo "error: too many arguments" >&2; exit 2; fi
           explicit="$1" ;;
    esac
    shift
done
[ $# -gt 0 ] && [ -z "$explicit" ] && explicit="$1"

# Determine the candidate version token.
if [ -n "$explicit" ]; then
    token=$(printf '%s' "$explicit" | sed -e 's/^odin version //' | tr -d '[:space:]')
else
    if ! command -v odin >/dev/null 2>&1; then
        echo "error: 'odin' not found on PATH (or pass an explicit version)" >&2
        exit 1
    fi
    token=$(odin version 2>&1 | sed -e 's/.*odin version //' | tr -d '[:space:]')
fi

if [ -z "$token" ]; then
    echo "error: could not determine an Odin version to pin" >&2
    exit 1
fi

base=${token%%:*}
case "$mode" in
    exact) newver="$token" ;;
    base)  newver="$base" ;;
    auto)  case "$base" in *-nightly) newver="$token" ;; *) newver="$base" ;; esac ;;
esac

# Sanity check: warn but don't block on unexpected-looking versions.
case "$newver" in
    dev-[0-9][0-9][0-9][0-9]-[0-9][0-9]*) : ;;
    *) echo "warning: '$newver' doesn't look like a dev-YYYY-MM version" >&2 ;;
esac

# Read current pinned value (if any) for the before/after summary.
old=""
if [ -f "$LOCK_FILE" ]; then
    old=$(sed -e 's/#.*$//' "$LOCK_FILE" | grep -v '^[[:space:]]*$' | head -n 1 | tr -d '[:space:]' || true)
fi

if [ ! -f "$LOCK_FILE" ]; then
    printf '# Odin version lock. Updated by scripts/update-odin-version.sh\n%s\n' "$newver" > "$LOCK_FILE"
else
    # Replace the first non-comment, non-blank line; keep comments/blank lines.
    tmp="$LOCK_FILE.tmp.$$"
    awk -v newver="$newver" '
        BEGIN { done = 0 }
        {
            s = $0
            sub(/#.*/, "", s)
            gsub(/[ \t]+/, "", s)
            if (!done && s != "") { print newver; done = 1 }
            else { print $0 }
        }
        END { if (!done) print newver }
    ' "$LOCK_FILE" > "$tmp"
    mv "$tmp" "$LOCK_FILE"
fi

if [ "$old" = "$newver" ]; then
    echo "No change: .odin-version already pinned to '$newver'"
else
    echo "Updated .odin-version: '${old:-<none>}' -> '$newver'"
fi