#!/bin/sh
# vim: shiftwidth=4

# Print table of repositories: NAME, CLONE URL, DESCRIPTION (first 40 chars).
#
# usage:
#   gitls

set -eu

# --- CONFIG ---
: ${BAREVCS_CONF:='/usr/local/etc/barevcs.conf'}
. ${BAREVCS_CONF}

: ${BASE_DIR:='/var/db/git'}       # base path containing group/<repo>.git
: ${SERVER_HOSTNAME:='git'}        # hostname used in clone URL (git@git:group/repo.git)

# print header
printf "%-36s %-52s %-30s\n" "NAME" "CLONE" "DESCRIPTION"

# find repositories: directories named *.git (non-recursive under BASE_DIR)
# Use find starting at BASE_DIR, prune other dirs
find "$BASE_DIR" -type d -name '*.git' -not -name '*.wiki.git' -print -prune | sort | while IFS= read -r repo_dir; do
    # repo_dir is e.g. /var/db/git/group/repo.git
    # extract group/repo (remove "$BASE_DIR/" prefix and trailing .git)
    rel=${repo_dir#"$BASE_DIR"/}        # group/repo.git
    rel=${rel%/.git}                    # if trailing slash present (defensive)
    # remove trailing .git suffix (handle both with and without preceding slash)
    case "$rel" in
        *.git) rel=${rel%.git} ;;
    esac
    # If rel still has a leading slash, remove it
    rel=${rel#/}

    # NAME is just the repo (last component)
    repo_name=${rel##*/}                # repo

    # description: first 40 bytes/characters of info/description (if exists)
    desc_file="$repo_dir/description"
    if [ -f "$desc_file" ]; then
        # read up to 40 chars, preserving spaces — use dd if available, else head -c
        if command -v dd >/dev/null 2>&1; then
            desc=$(dd if="$desc_file" bs=1 count=40 2>/dev/null || true)
        else
            desc=$(head -c 40 "$desc_file" 2>/dev/null || true)
        fi
        # collapse newlines to space and trim
        desc=$(printf '%s' "$desc" | tr '\n' ' ' | awk '{$1=$1; print}')
    fi

    clone_url="git@$SERVER_HOSTNAME:${rel}.git"

    printf "%-36s %-52s %-30s\n" "$repo_name" "$desc" "$clone_url"
done
