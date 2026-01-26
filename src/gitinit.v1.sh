#!/bin/sh

# This script will accept a option for a repository and a description to create.
#
# If no 'group' is included, it will default to 'john'.
# If no 'description' is included, then this script defaults to: '(no description)'
#
# SYNOPSYS
#       gitinit [group/]<repository> [description]

name=$1
desc=$2
user=john
directory="./"
server="git.local"

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
        group=${user}
fi

if [ -z "${desc}" ]; then
        desc="(no description)"
fi

mkdir -pv "${directory}${group}"                || { echo "Error creating directory"; exit 1; }
cd "${directory}${group}"                       || { echo "Error changing directory"; exit 1; }
git init --bare -q ${name}.git                  || { echo "Error creating git directory"; exit 1; }
echo "ref: refs/heads/main" > ./${name}.git/HEADS || { echo "Error setting main branch in HEADS file" ; exit 1; }
echo "${desc}" > "${name}.git/description"      || { echo "Error writing description"; exit 1; }

cat <<_EOF_ >&1
The project repository for "${name}" was created in the following group: "${group}".
However, the repository for this project is empty.

Command line instructions

Local Git global setup
    git config --global user.name "John Kaul"
    git config --global user.email "johnkaul@icloud.com"

Create a new repository
    git clone git@${server}:${group}/${name}.git
    cd ${name}
    touch readme.md
    git add readme.md
    git commit -m "add readme.md"
    git push -u origin master

Push an existing folder
    cd existing_folder
    git init
    git remote add origin git@${server}:${group}/${name}.git
    git add .
    git commit -m "Initial commit"
    #git push -u origin master
    git push --all

Push an existing Git repository
    cd existing_repo
    git remote rename origin old-origin
    git remote add origin git@${server}:${group}/${name}.git
    git push -u origin --all
    git push -u origin --tags
_EOF_

# vim: ft=sh
