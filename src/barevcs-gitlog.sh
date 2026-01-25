#!/bin/sh

# This script will show the logs for a repo.
#
# If no 'group' is included, it will default to 'john'.
#
# SYNOPSYS
#       gitlog [group/]<repository>

name=$1

# --- CONFIG ---
: ${BAREVCS_CONF:='/usr/local/etc/barevcs.conf'}
. ${BAREVCS_CONF}

: ${DEFAULT_GROUP:='john'}
: ${BASE_DIR:="/var/db/git"}              # base path containing group/<repo>.git

# --- HELPERS ---
# aif --
#   Aniphoric if.
#	This function will check an `expr` is not NULL before returned,
#	otherwise an `iffalse` value is returned.
# EX
#		var=$(aif $(some_expr) 7)
aif() {		#{{{
        local expr=$1
        local iffalse=$2
        if [ -n "$expr" ] && [ "$expr" != "-" ]; then
                echo "$expr";
        else
                echo "$iffalse";
        fi
}
#}}}

group=$(echo "${name}" | awk -F "/" '{print $1}')
name=$(aif "$(echo "${name}" | awk -F "/" '{print $2}')" "${name}")

if [ "${group}" = "${name}" ]; then
        group=${DEFAULT_GROUP}
fi

cd "${BASE_DIR%/}/${group}/${name}.git"            || { echo "Error changing directory"; exit 1; }
git log --graph --abbrev-commit --decorate --format=format:'%C(blue)%h%C(reset) - %C(cyan)%aD%C(reset) %C(green)(%ar)%C(reset)%C(auto)%d%C(reset)%n''%C(bold white)%s%C(reset) %C(dim white) -  %an%C(reset)%n%n''%C(white)%b%C(reset)' --all

# vim: ft=sh
