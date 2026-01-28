#!/bin/sh
# vim: shiftwidth=4

# Create a bare Git repository under /var/db/git/<group>/<repo>.git,
# set HEAD to refs/heads/main and write a sanitized description file.
#
# parameters:
#   $1 - repository path in form "group/repo" or "repo" (group defaults to "john")
#   $2 - description string (optional; default "(no description)")
#
# return:
#   exits 0 on success, non-zero on failure
#
# example:
#   barevcs-gitinit john/acme "Amazing Program"

set -eu

# --- CONFIG ---
: ${BAREVCS_CONF:='/usr/local/etc/barevcs.conf'}
. ${BAREVCS_CONF}

: ${DEFAULT_GROUP:='john'}
: ${BASE_DIR:='/var/db/git'}
: ${OWNER:='git'}
: ${GROUP_OWNER:='wheel'}
: ${SERVER_HOSTNAME:='git'}   # used in printed clone URL; adjust if needed

err() {
    printf '%s\n' "$1" >&2
}

# aif --
#   Aniphoric if.
#   This function will check an `expr` is not NULL before returned,
#   otherwise an `iffalse` value is returned.
# EX
#       var=$(aif $(some_expr) 7)
aif() {
    if [ "${1-}" ] && [ "$1" != "-" ]; then
        printf '%s' "$1"
    else
        printf '%s' "$2"
    fi
}

# validate_and_split --
#       validate input path and set GROUP and REPO variables
#
# parameters:
#       $1 - repo path (group/repo or repo)
#
# return:
#       sets GROUP and REPO on success; returns 0. On error prints message and returns 1.
validate_and_split() {
    inp=${1:-}
    if [ -z "$inp" ]; then
        err "ERROR: repository path required (format: [group/]repo)"
        return 1
    fi

    case "$inp" in
        */*)
            GROUP=${inp%%/*}
            REPO=${inp#*/}
            ;;
        *)
            GROUP="$DEFAULT_GROUP"
            REPO="$inp"
            ;;
    esac

    # ensure non-empty
    if [ -z "$GROUP" ] || [ -z "$REPO" ]; then
        err "ERROR: invalid repository path; expected [group/]repo with non-empty parts"
        return 1
    fi

    # validate repo name: allow letters, digits, hyphen, underscore
    case "$REPO" in
        *[!A-Za-z0-9_-]*)
            err "ERROR: repository name contains invalid characters; allowed: letters, digits, hyphen, underscore"
            return 1
            ;;
    esac

    return 0
}

# sanitize_description --
#       convert description to single trimmed line; default if empty
#
# parameters:
#       $1 - raw description (may be empty)
#
# return:
#       sets DESC variable and returns 0
sanitize_description() {
    raw=${1:-}
    if [ -z "$raw" ]; then
        DESC='(no description)'
        return 0
    fi

    # replace newline and tab with space, collapse multiple spaces, trim
    # Use awk for collapse/trim (POSIX)
    tmp=$(printf '%s' "$raw" | tr '\n\t' '  ')
    # collapse spaces and trim
    tmp=$(printf '%s' "$tmp" | awk '{$1=$1; print}')
    if [ -z "$tmp" ]; then
        DESC='(no description)'
    else
        DESC=$tmp
    fi
    return 0
}

# create_repo --
#       create directories, initialize bare repo, set ownership/perm,
#       write description, set HEAD
#
# parameters:
#       uses GROUP, REPO, DESC
#
# return:
#       0 on success, 1 on failure
create_repo() {
    GROUP_DIR="${BASE_DIR%/}/$GROUP"
    REPO_DIR="$GROUP_DIR/$REPO.git"

    # fail fast if already exists
    if [ -e "$REPO_DIR" ]; then
        err "ERROR: repository already exists: $REPO_DIR"
        return 1
    fi

    if [ ! -d "$GROUP_DIR" ]; then
        if ! mkdir -p "$GROUP_DIR"; then
            err "ERROR: failed to create group directory: $GROUP_DIR"
            return 1
        fi
        chmod 2775 "$GROUP_DIR" || true
    fi

    if ! git init --bare "$REPO_DIR" >/dev/null 2>&1; then
        err "ERROR: git init --bare failed for $REPO_DIR"
        return 1
    fi

    if ! chown -R "$OWNER:$GROUP_OWNER" "$REPO_DIR"; then
        err "ERROR: chown $OWNER:$GROUP_OWNER failed on $REPO_DIR"
        return 1
    fi

    chmod -R 2770 "$REPO_DIR" || true

    # write sanitized description
    DESC_FILE="$REPO_DIR/info/description"
    if ! printf '%s\n' "$DESC" >"$DESC_FILE"; then
        err "ERROR: failed to write description to $DESC_FILE"
        return 1
    fi
    chown "$OWNER:$GROUP_OWNER" "$DESC_FILE" || true
    chmod 0644 "$DESC_FILE" || true

    # set HEAD to main
    HEAD_FILE="$REPO_DIR/HEAD"
    if ! printf 'ref: refs/heads/main\n' >"$HEAD_FILE"; then
        err "ERROR: failed to write HEAD to $HEAD_FILE"
        return 1
    fi
    chown "$OWNER:$GROUP_OWNER" "$HEAD_FILE" || true
    chmod 0644 "$HEAD_FILE" || true

    return 0
}

# print_helpful_info --
#       print clone/push examples using server hostname setting
#
# parameters:
#       uses GROUP, REPO, DESC
#
# return:
#       0
print_helpful_info() {
    REPO_PATH="$GROUP/$REPO"
    CLONE_URL="$OWNER@$SERVER_HOSTNAME:$REPO_PATH.git"

    printf 'NAME\tCLONE\tDESCRIPTION\n'
    printf '%s\t%s\t%s\n' "$REPO" "$CLONE_URL" "$DESC"
    printf '\nPush / clone examples:\n\n'

    printf 'Clone (if repo already has commits):\n'
    printf '  git clone %s\n\n' "$CLONE_URL"

    printf 'Push an existing local repo (push main):\n'
    printf '  git remote add origin %s\n' "$CLONE_URL"
    printf '  git push -u origin main\n\n'

    printf 'Create a new local repo and push:\n'
    printf '  mkdir ' "$REPO" ' && cd '"$REPO"'\n'
    printf '  git init\n'
    printf '  touch readme.md\n'
    printf '  git add readme.md && git commit -m "initial commit."\n'
    printf '  git remote add origin %s\n' "$CLONE_URL"
    printf '  git push -u origin main\n\n'

    printf 'Push an existing repo to this remote:\n'
    printf '  git remote add origin %s\n' "$CLONE_URL"
    printf '  git push -u origin --all\n'
    printf '  git push -u origin --tags\n'
}

# main --
#       script entrypoint
#
# parameters:
#       $1 - [group/]repo
#       $2 - description (optional)
#
# return:
#       exits 0 on success, non-zero on failure
main() {
    if [ "${1-}" = "" ]; then
        err "ERROR: missing repository path argument (format: [group/]repo)"
        exit 1
    fi

    if ! validate_and_split "$1"; then
        exit 1
    fi

    # use fallback helper to allow "-" to mean use default if caller chooses
    DESC_RAW=$(aif "${2-}" '')
    sanitize_description "$DESC_RAW"

    if ! create_repo; then
        exit 1
    fi

    print_helpful_info

    return 0
}

main "$@"
