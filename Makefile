#*******************************************************************************
#*                               xubuntu-remaster                              *
#*-----------------------------------------------------------------------------*
#* based on https://github.com/covertsh/ubuntu-autoinstall-generator           *
#*                                                                             *
#* Copyright (c) 2022 Ivan Danov                                               *
#*                                                                             *
#* MIT License                                                                 *
#*                                                                             *
#* Permission is hereby granted, free of charge, to any person obtaining a     *
#* copy of this software and associated documentation files (the "Software"),  *
#* to deal in the Software without restriction, including without limitation   *
#* the rights to use, copy, modify, merge, publish, distribute, sublicense,    *
#* and/or sell copies of the Software, and to permit persons to whom the       *
#* Software is furnished to do so, subject to the following conditions:        *
#*                                                                             *
#* The above copyright notice and this permission notice shall be included     *
#* in all copies or substantial portions of the Software.                      *
#*                                                                             *
#* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS     *
#* OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, *
#* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE *
#* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER      *
#* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING     *
#* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER         *
#* DEALINGS IN THE SOFTWARE.                                                   *
#*******************************************************************************

PROJECT = xubuntu-remaster

GIT_LAST_TAG := $(shell git describe --tags --abbrev=0 2>/dev/null)

# ifdef GIT_LAST_TAG
# PROJECT_BASE_VERSION = $(GIT_LAST_TAG)
# else
PROJECT_BASE_VERSION = 1.0
# endif

DEBNAME = $(PROJECT)
ARCH = all

VENDOR_NAME = "Ivan Danov"
VENDOR_YEAR = "2022"
VENDOR_EMAIL = ivan.danov@gmail.com
VENDOR_SITE = https://github.com/ivan-danov/xubuntu-remaster

DEBDESC  = "$(VENDOR_NAME) $(PROJECT) package\\n"
DEBDESC += "remaster ubuntu server iso"

DEBDIR = $(PROJECT)_deb

PACKAGE_DEPS += ,curl,systemd-container,squashfs-tools,xorriso,isolinux

ifneq ($(V),0)
Q =
else
Q = @
endif

# define git branch
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null)
ifndef GIT_BRANCH
GIT_BRANCH := unknown
endif

# define git revision
GIT_REV := $(shell git rev-parse --verify HEAD --short 2>/dev/null)
ifndef GIT_REV
GIT_REV := unknown
endif

# define git revision count (incremental)
ifdef GIT_BRANCH
GIT_REV_COUNT := $(shell git rev-list --count $(GIT_BRANCH) 2>/dev/null)
else
GIT_REV_COUNT := $(shell git rev-list --count HEAD 2>/dev/null)
endif
ifndef GIT_REV_COUNT
GIT_REV_COUNT := 1
endif

# see https://semver.org/
PROJECT_VERSION ?= $(PROJECT_BASE_VERSION).$(GIT_REV_COUNT)+$(GIT_REV)


# debian package full name
FINAL_DEBNAME = $(DEBNAME)_$(PROJECT_VERSION)_all.deb


all:
	$(Q)echo "make deb | make clean"

info:
	$(Q)echo "      This makefile: $(firstword $(MAKEFILE_LIST))"
	$(Q)echo "         GIT branch: $(GIT_BRANCH)"
	$(Q)echo "       GIT revision: $(GIT_REV)"
	$(Q)echo " GIT revision count: $(GIT_REV_COUNT)"
	$(Q)echo "       GIT last tag: $(GIT_LAST_TAG)"
	$(Q)echo "            Project: $(PROJECT)"
	$(Q)echo "    Project version: $(PROJECT_VERSION)"
	${Q}echo "   DEB Package name: $(FINAL_DEBNAME)"

version:
	@echo "$(PROJECT_VERSION)"


ifndef DEBDIR
DEBDIR = ${DEBNAME}_deb/
endif

GIT2CL := $(strip $(shell which git2cl))

# begin of debian packet
define deb_begin
	$(Q)$(RM) -rf $(DEBDIR)
	$(Q)mkdir -p $(DEBDIR)/usr/share/doc/$(DEBNAME)
	$(Q)mkdir -p $(DEBDIR)/DEBIAN

	$(Q)cp debian/copyright $(DEBDIR)/usr/share/doc/$(DEBNAME)/copyright
endef # deb_begin

ifneq ($(GIT2CL),)
define deb_changelog
	$(Q)git --no-pager log --pretty --numstat --summary | git2cl > $(DEBDIR)/usr/share/doc/$(DEBNAME)/changelog
	$(Q)gzip -9 -n $(DEBDIR)/usr/share/doc/$(DEBNAME)/changelog
endef # deb_changelog
else # GIT2CL
define deb_changelog
	$(Q)echo "$(shell date -R)  $(VENDOR_NAME) ($(VENDOR_EMAIL))" > $(DEBDIR)/usr/share/doc/$(DEBNAME)/changelog
	$(Q)echo "  * Release $(PROJECT_VERSION)" >> $(DEBDIR)/usr/share/doc/$(DEBNAME)/changelog
	$(Q)echo "  * Generated from:" >> $(DEBDIR)/usr/share/doc/$(DEBNAME)/changelog
	$(Q)gzip -9 -n $(DEBDIR)/usr/share/doc/$(DEBNAME)/changelog
endef # deb_changelog
endif # GIT2CL

define deb_control
	$(Q)echo "Package: $(DEBNAME)" > $(DEBDIR)/DEBIAN/control
	$(Q)echo "Version: $(PROJECT_VERSION)" >> $(DEBDIR)/DEBIAN/control
	$(Q)echo "Architecture: $(ARCH)" >> $(DEBDIR)/DEBIAN/control
	$(Q)echo "Section: misc" >> $(DEBDIR)/DEBIAN/control
	$(Q)echo "Maintainer: $(VENDOR_NAME) <$(VENDOR_EMAIL)>" >> $(DEBDIR)/DEBIAN/control
	$(Q)echo "Homepage: $(VENDOR_SITE)" >> $(DEBDIR)/DEBIAN/control
	$(Q)echo "Priority: optional" >> $(DEBDIR)/DEBIAN/control
	$(Q)echo "Depends: lsb-base, debconf (>= 0.5) | debconf-2.0 $(PACKAGE_DEPS)" >> $(DEBDIR)/DEBIAN/control
	$(Q)echo "Installed-Size: `du -sl $(DEBDIR)/|cut -f 1`" >> $(DEBDIR)/DEBIAN/control
	$(Q)echo "Description: $(DEBDESC)" >> $(DEBDIR)/DEBIAN/control
	$(Q)chmod 644 $(DEBDIR)/DEBIAN/control
endef # deb_control

# end of debian packet
define deb_end
	$(Q)$(foreach f, \
		$(wildcard debian/preinst) $(wildcard debian/postinst) \
		$(wildcard debian/prerm) $(wildcard debian/postrm) \
		$(wildcard debian/config), \
		cp $(f) $(DEBDIR)/DEBIAN/;chmod 755 $(DEBDIR)/DEBIAN/$(notdir $(f)); \
		)

	$(Q)$(foreach f, $(wildcard debian/templates) $(wildcard debian/triggers), \
		cp $(f) $(DEBDIR)/DEBIAN/;chmod 644 $(DEBDIR)/DEBIAN/$(notdir $(f)); \
		)

	$(Q)$(foreach mn, 1 2 3 4 5 6 7 8, \
		$(foreach f, $(wildcard *.$(mn)), \
			mkdir -p $(DEBDIR)/usr/share/man/man$(mn); \
			cp $(f) $(DEBDIR)/usr/share/man/man$(mn); \
			) \
		)
	$(Q)if [ -d $(DEBDIR)/usr/share/man ]; then \
		find $(DEBDIR)/usr/share/man/ -name '*.[12345678]' \
		-exec gzip -9 -n '{}' \;; fi

	$(Q)find $(DEBDIR) -name '.*.kate-swp' -exec rm -f {} \;
	$(Q)find $(DEBDIR) -name '.*.swp' -exec rm -f {} \;
	$(Q)find $(DEBDIR) -name '.AppleDouble' -exec rm -f {} \;
	$(Q)find $(DEBDIR) -name '.DS_Store' -exec rm -f {} \;

	$(Q)cd $(DEBDIR);if [ -d etc ]; then \
		find etc -type f -exec md5sum '{}' \; > DEBIAN/md5sums; fi
	$(Q)cd $(DEBDIR);if [ -d usr ]; then \
		find usr -type f -exec md5sum '{}' \; >> DEBIAN/md5sums; fi
	$(Q)cd $(DEBDIR);if [ -d lib ]; then \
		find lib -type f -exec md5sum '{}' \; >> DEBIAN/md5sums; fi

	$(Q)cd $(DEBDIR);if [ -d etc ]; then \
		find etc -type f -fprintf DEBIAN/conffiles "/%p\n"; fi

	$(Q)chmod -R g-w $(DEBDIR)
	$(Q)fakeroot dpkg --build $(DEBDIR) $(FINAL_DEBNAME)
	-$(Q)lintian $(LINTIAN_FLAGS) --no-tag-display-limit $(FINAL_DEBNAME)
endef # deb_end

define deb_func
	$(call deb_begin)
	$(call deb_changelog)
	${Q}mkdir -p $(DEBDIR)/usr/bin
	${Q}cp xubuntu-remaster $(DEBDIR)/usr/bin/$(DEBNAME)
	${Q}sed -i 's/^XUBUNTU_REMASTER_VERSION=development/XUBUNTU_REMASTER_VERSION="'"${PROJECT_VERSION}"'"/g' $(DEBDIR)/usr/bin/$(DEBNAME)
	${Q}chmod 0755 $(DEBDIR)/usr/bin/$(DEBNAME)

	${Q}cp -a examples $(DEBDIR)/usr/share/doc/$(DEBNAME)/

	$(call deb_control)
	$(call deb_end)
	$(Q)rm -r $(DEBDIR)
	$(Q)ls -la *.deb
endef #deb_func

deb:
	$(call deb_func)
	@echo $(BEERSYM)$(PROJECT) deb done.

debname:
	@echo $(FINAL_DEBNAME)

# to execute after cleaning all.
define clean_done_func
	$(Q)$(RM) -r $(DEBDIR) $(PROJECT)_*_$(ARCH).deb
	$(Q)$(RM) custom_script.log
	$(Q)$(RM) *.iso
endef

clean:
	$(call clean_done_func)
	@echo $(BEERSYM)$(PROJECT) cleaning done.

simple_iso:
	./xubuntu-remaster examples/simple/simple.conf

luks_encrypted_iso:
	./xubuntu-remaster examples/luks-encrypted/luks-encrypted.conf

check:
	shellcheck ./xubuntu-remaster
	shellcheck examples/*/*.conf examples/*/*.sh

comma := ,
install_dep:
	sudo apt update
	sudo apt install -y $(subst $(comma), ,$(strip $(PACKAGE_DEPS)))
