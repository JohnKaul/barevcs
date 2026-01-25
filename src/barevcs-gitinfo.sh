#!/bin/sh
##
## @file gitinfo
## @brief Pretty repository summary script for calling via ssh (e.g. gitinfo server/repo)
##
## Why/logic:
##  - Validate input and support <group>/<repo> or just <repo> (defaults group -> user).
##  - Use aif() to provide fallback values for empty expressions.
##  - cd into the bare repo directory and print: header summary, tree, log, README.
##  - Be defensive with IFS and quoting to handle spaces.
##
## Usage:
##  gitinfo <group>/<repo>
##

# --- CONFIG ---
: ${BAREVCS_CONF:='/usr/local/etc/barevcs.conf'}
. ${BAREVCS_CONF}

: ${DEFAULT_GOUP:="john"}                 # default group owner when group==repo
: ${BASE_DIR:="/var/db/git"}              # base path containing group/<repo>.git
: ${README_SANITIZER:="/usr/local/bin/md2txt"}

# --- HELPERS ---
aif() { 
    # Aniphoric if: echo expr if non-empty and not "-", else echo iffalse
    expr=$1
    iffalse=$2
    if [ -n "$expr" ] && [ "$expr" != "-" ]; then
        printf '%s' "$expr"
    else
        printf '%s' "$iffalse"
    fi
}

usage() {
    printf 'Usage: %s <group>/<repo>\n' "$(basename "$0")" >&2
    exit 2
}

# --- input parsing ---
[ $# -ge 1 ] || usage
input="$1"

# split on first slash
## group=$(printf '%s' "$input" | awk -F'/' '{print $1}')
## repo=$(printf '%s' "$input" | awk -F'/' '{ if (NF>1) { $1=""; sub(/^\//,""); print } else print $1 }')

group=${input%%/*}
if [ "${input#*/}" != "$input" ]; then
    repo=${input#*/}
else
    repo=
fi

# fallback: if repo empty, make repo == group (user case)
repo=$(aif "$repo" "$group")

# if group == repo then use default user as group
if [ "$group" = "$repo" ]; then
    group="$DEFAULT_GROUP"
fi

repo_dir="${BASE_DIR%/}/${group}/${repo}.git"

# --- enter repo ---
if ! cd -- "$repo_dir" 2>/dev/null; then
    printf 'Error: cannot access repository at: %s\n' "$repo_dir" >&2
    exit 1
fi

# --- summary ---
# Read description first line (if exists)
desc_file="description"
if [ -f "$desc_file" ]; then
    # first 80 chars of the first line
    desc=$(awk 'NR==1{print; exit}' "$desc_file" | cut -c1-80)
else
    desc="(no description)"
fi

path="${group}/${repo}"
clone_url="git@git:${path}.git"

printf -- '---[ SUMMARY ]--------------------------------------------------\n'
printf 'path:   %s\n' "$path"
printf 'clone:  %s\n' "$clone_url"
printf 'descr:  %s\n\n' "$desc"

# --- tree ---
printf -- '---[ TREE ]-----------------------------------------------------\n'
# show compact tree: object (short) and path
# for bare repos HEAD may be refs/heads/main or HEAD may not be present; handle gracefully
if git rev-parse --verify --quiet HEAD >/dev/null; then
    git ls-tree -r HEAD --abbrev=7 --format='%(objectname) %(path)' || true
else
    printf '(no commits)\n'
fi
printf '\n'

# --- log ---
printf -- '---[ LOG ]------------------------------------------------------\n'
if git rev-parse --verify --quiet HEAD >/dev/null; then
    git --no-pager log -2 --graph --abbrev-commit --decorate \
        --format=format:'%C(blue)%h%C(reset) - %C(cyan)%aD%C(reset) %C(green)(%ar)%C(reset)%C(auto)%d%C(reset)%n''%C(bold white)%s%C(reset) %C(dim white)- %an%C(reset)%n%n''%C(white)%b%C(reset)'
else
    printf '(no commits)\n'
fi
printf '\n\n'

# --- README ---
printf -- '---[ README ]---------------------------------------------------\n'
# try common README filenames (case-insensitive)
 for r in README README.md readme.md Readme.md README.MD; do
     if git rev-parse --verify --quiet HEAD >/dev/null && git ls-tree -r --name-only HEAD | grep -x -- "$r" >/dev/null 2>&1; then
#        git --no-pager show "HEAD:$r" || true
#        printf '\n'
#        exit 0
         # print README blob, then sanitize simple Markdown to plain text
         git --no-pager show "HEAD:$r" 2>/dev/null | ${README_SANITIZER}
		 printf '\n'
	     exit 0
    fi

done
printf '(no README found)\n'
exit 0
