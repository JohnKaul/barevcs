#===---------------------------------------------*- makefile -*---===
#: barevcs
#===--------------------------------------------------------------===
SRCDIR		=	src
DOCDIR		=	doc
INCDIR		:=	src/include

PREFIX		:=	/usr/local/bin
MANPATH 	:= /usr/local/share/man/man1
CONFPATH 	:= /usr/local/etc

CC			:=	cc
CFLAGS		:=	-fno-exceptions -pipe -Wall -W -I $(SRCDIR) -I $(INCDIR)
REMOVE		:=	rm -f
CP			:=	cp
CTAGS       :=	ctags

#--------------------------------------------------------------------
# Define the target compile instructions.
#--------------------------------------------------------------------
barevcs: clean
	BAREVCS_TARGET='barevcs'
		@$(CC) $(CFLAGS) -o ./md2txt $(SRCDIR)/md2txt.c
		@$(CP) $(SRCDIR)/barevcs-gitinit.sh ./barevcs-gitinit
		@chmod +x ./barevcs-gitinit
		@$(CP) $(SRCDIR)/barevcs-gitinfo.sh ./barevcs-gitinfo
		@chmod +x ./barevcs-gitinfo
		@$(CP) $(SRCDIR)/barevcs-gitls.sh ./barevcs-gitls
		@chmod +x ./barevcs-gitls
		@$(CP) $(SRCDIR)/barevcs-gitlog.sh ./barevcs-gitlog
		@chmod +x ./barevcs-gitlog

.PHONY: clean
clean:
	@$(REMOVE) md2txt
	@$(REMOVE) barevcs-gitinit
	@$(REMOVE) barevcs-gitinfo
	@$(REMOVE) barevcs-gitlog
	@$(REMOVE) barevcs-gitls

.PHONY: install
install:
	@$(CP) md2txt $(PREFIX)/md2txt
	@$(CP) barevcs-gitinit $(PREFIX)/barevcs-gitinit
	@$(CP) barevcs-gitinfo $(PREFIX)/barevcs-gitinfo
	@$(CP) barevcs-gitlog $(PREFIX)/barevcs-gitlog
	@$(CP) barevcs-gitls $(PREFIX)/barevcs-gitls
	@$(CP) etc/barevcs.conf $(CONFPATH)/barevcs.conf
	@$(CP) doc/barevcs.1 $(MANPATH)/barevcs.1

.PHONY: uninstall
uninstall:
	@$(REMOVE) $(PREFIX)/md2txt
	@$(REMOVE) $(PREFIX)/barevcs-gitinit
	@$(REMOVE) $(PREFIX)/barevcs-gitinfo
	@$(REMOVE) $(PREFIX)/barevcs-gitlog
	@$(REMOVE) $(PREFIX)/barevcs-gitls
	@$(REMOVE) $(MANPATH)/barevcs.1
	@$(REMOVE) $(CONFPATH)/barevcs.conf

.PHONY: all
all: barevcs

# vim: set noet
