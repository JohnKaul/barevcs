<!--------------------------------------------*- MARKDOWN -*------
File Last Updated: 01.25.26 11:39:16

File:    readme.md
Author:  John Kaul <john.kaul@outlook.com>
Brief:   `barevcs` is a small POSIX toolkit, with minimal
         dependencies, for managing bare VCS repositories on 
         headless servers (initially Git) which which can be 
         hopefully used as a skeleton to offer support for 
         other VCS' like `got`, `fossil` or `svn`.
------------------------------------------------------------------>

# barevcs 

`barevcs` is a lighweight toolkit--currently in Proof of Concept
stage--for creating, listing, and inspecting bare version-control
repositories on headless servers. It aims for POSIX portability, and
secure interaction via ssh(1). 

_Current backend: `git` (Future backends may include other server-side
VCS implementations like: `fossil`, `got`, `svn`, etc.)._

## QUICK START
1. Makefile installs scripts to `/usr/local/bin`
2. Edit `/usr/local/etc/barevcs.conf`
3. From your laptop, call via SSH:
   - Create:   ssh git@server 'barevcs-gitinit john/acme "Amazing Program"'
   - List:     ssh git@server 'barevcs-gitls'
   - Info:     ssh git@server 'barevcs-gitinfo john/acme'
   - View Log: ssh git@server 'barevcs-gitlog john/acme'

## REMOTE CONFIGURATION EXAMPLE (/usr/local/etc/barevcs.conf)
```
 # barevcs configuration
 BASE_DIR=/var/db/git
 SERVER_HOSTNAME=git
 DEFAULT_GROUP=unnamed
 OWNER=git
 GROUP_OWNER=wheel
 README_SANITIZER=/usr/local/bin/md2text
```

## LOCAL CONFIGURATION EXAMPLE ($HOME/.zshrc)
Interaction with the `barevcs` scripts is best done with the use of a
shell rc function like below:

```
 # gitls --
 #   Call the 'barevcs-gitls' shell script on the git server to
 #   list out the bare (remote) repositories.
 function gitls() {
         ssh \
         -p 22 \
         -l git \
         -i ~/.ssh/id_ed25519 \
         192.168.0.2 \
         -t "barevcs-gitls"
 }

 # gitlog --
 #   Call the 'gitlog' shell script on the git server to
 #   list a repos logs.
 # EX:
 #   gitlog [group/]repo
 function gitlog() {
         ssh \
         -p 22 \
         -l git \
         -i ~/.ssh/id_ed25519 \
         192.168.0.2 \
         -t "barevcs-gitlog $1"
 }

 # gitinit --
 #   Call the 'gitinit' shell script on the git server to
 #   create a new repository.
 # EX:
 #   gitinit [group/]newrepo "Repository description"
 function gitinit() {
         ssh \
         -p 22 \
         -l git \
         -i ~/.ssh/id_ed25519 \
         192.168.0.2 \
         -t "barevcs-gitinit $1 $(printf '%q' "$2")"
 }

 # gitinfo --
 #   Call the 'gitinfo' shell script on the git server to
 #   list out the remote repositories.
 # EX:
 #  gitinfo [group/]repo
 function gitinfo() {
         ssh \
         -p 22 \
         -l git \
         -i ~/.ssh/id_ed25519 \
         192.168.0.2 \
         -t "barevcs-gitinfo $1 | more"
 }
```
## TOOL NAMING CONVENTIONS
- Executables: `barevcs-<backend><command>`, -e.g., `barevcs-gitinit`
- Config: `/usr/local/etc/barevcs.conf` for system-wide control
- Manpages: `/usr/local/share/man/man1`

## WHY
I created this because I'm typically already in the terminal workig
with my VCS so didn't feel like I should have to open a browser window
to interact with my local VCS server.

## HISTORY
Created for my personal use.

## AUTHOR
* John Kaul - john.kaul@outlook.com
