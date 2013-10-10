## == KEEN NGINX: makefile == ##

##### Configuration

WORKSPACE ?= latest

# nginx config
stable ?= 1.4.3
latest ?= 1.5.6

# pagespeed config
PAGESPEED ?= 1
PSOL_VERSION ?= 1.6.29.5
PAGESPEED_VERSION ?= 1.6.29.5-beta

# pcre config
PCRE ?= 1
PCRE_VERSION ?= 8.33

# openssl config
OPENSSL ?= 1
OPENSSL_VERSION ?= 1.0.1e

# libatomic config
LIBATOMIC ?= 1


##### Runtime
PATCH ?= omnibus
CURRENT := $($(WORKSPACE))

# patch directories
_common_patches = $(wildcard patches/common/*)
_current_patches := $(wildcard patches/$(CURRENT)/*)


#### ==== TOP-LEVEL RULES ==== ####
all: sources workspace package

seal:
	@echo "Removing omnibus..."
	@rm -f patches/$(CURRENT)/omnibus.patch.bk

	@echo "Generating new patch..."
	-diff -Naurdw sources/$(CURRENT)/nginx-$(CURRENT)/src/ workspace/ > patches/$(CURRENT)/omnibus.patch

package: build
	@echo "Packaging..."
	@echo "=== Finished Keen-Nginx build. ==="

build: patch
	@echo "Building..."

	@mkdir -p build/
	@echo "Configuring Nginx..."
	@echo "Compiling Nginx..."

patch: sources patch_common patch_$(CURRENT)
	@echo "Patching complete."
	@echo "Applied patches:"
	@echo "  -- Common: " $(_common_patches)
	@echo "  -- Specific:" $(_current_patches)

clean:
	@echo "Cleaning..."
	@echo "    ... buildroot."
	@rm -fr build/

distclean: clean
	@echo "    ... workspace."
	@rm -fr workspace
	@echo "    ... dependencies."
	@rm -fr dependencies/
	@echo "    ... modules."
	@rm -fr modules/
	@echo "    ... sources."
	@rm -fr sources/
	@echo "Resetting codebase..."
	@git reset --hard

sources: dependencies modules
	@echo "Finished acquiring sources."

modules: modules/pagespeed
	@echo "Downloaded module sources."

dependencies: dependencies/pcre dependencies/openssl dependencies/libatomic
	@echo "Finished fetching dependency sources."


#### ==== WORKSPACE RULES ==== ####
workspace: workspace/.$(WORKSPACE)

workspace/.$(WORKSPACE): sources/$(WORKSPACE)
	@echo "Setting workspace to '$(WORKSPACE)'..."
	@mkdir -p workspace/
	@cp -fr sources/$(CURRENT)/nginx-$(CURRENT)/src/* workspace/
	@touch workspace/.$(WORKSPACE)


#### ==== PATCH APPLICATION ==== ####
patch_common: $(_common_patches)
	@echo "Applying patch " $^ "..."

patch_$(CURRENT): $(_current_patches)
	@echo "Applying patch " $^ "..."


#### ==== NGINX SOURCES ==== ####
sources/$(WORKSPACE):
	@echo "Preparing Nginx $(WORKSPACE)..."
	@mkdir -p sources/$(CURRENT)
	@ln -s $(CURRENT)/ sources/$(WORKSPACE)

	@echo "Fetching Nginx $(CURRENT)..."
	@curl --progress-bar http://nginx.org/download/nginx-$(CURRENT).tar.gz > nginx-$(CURRENT).tar.gz

	@echo "Extracting Nginx $(CURRENT)..."
	@tar -xvf nginx-$(CURRENT).tar.gz
	@mv nginx-$(CURRENT).tar.gz nginx-$(CURRENT) sources/$(CURRENT)


#### ==== NGINX DEPENDENCIES ==== ####
dependencies/pcre:
	@echo "Fetching PCRE..."
	@mkdir -p dependencies/pcre/$(PCRE_VERSION)
	@curl --progress-bar ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-$(PCRE_VERSION).tar.gz > pcre-$(PCRE_VERSION).tar.gz

	@echo "Extracting PCRE..."
	@tar -xvf pcre-$(PCRE_VERSION).tar.gz
	@mv pcre-$(PCRE_VERSION)/ pcre-$(PCRE_VERSION).tar.gz dependencies/pcre/$(PCRE_VERSION)/
	@ln -s $(PCRE_VERSION)/pcre-$(PCRE_VERSION) dependencies/pcre/latest

dependencies/openssl:
	@echo "Fetching OpenSSL..."
	@mkdir -p dependencies/openssl/$(OPENSSL_VERSION)
	@curl --progress-bar http://www.openssl.org/source/openssl-$(OPENSSL_VERSION).tar.gz > openssl-$(OPENSSL_VERSION).tar.gz

	@echo "Extracting OpenSSL..."
	@tar -xvf openssl-$(OPENSSL_VERSION).tar.gz
	@mv openssl-$(OPENSSL_VERSION)/ openssl-$(OPENSSL_VERSION).tar.gz dependencies/openssl/$(OPENSSL_VERSION)/
	@ln -s $(OPENSSL_VERSION)/openssl-$(OPENSSL_VERSION) dependencies/openssl/latest

dependencies/libatomic:
	@echo "Fetching libatomic..."
	@mkdir -p dependencies/libatomic/7.2
	@curl --progress-bar http://www.hpl.hp.com/research/linux/atomic_ops/download/libatomic_ops-7.2d.tar.gz > libatomic_ops-7.2d.tar.gz

	@echo "Extracting libatomic..."
	@tar -xvf libatomic_ops-7.2d.tar.gz
	@mv libatomic_ops-7.2 libatomic_ops-7.2d.tar.gz dependencies/libatomic/7.2
	@ln -s 7.2/libatomic_ops-7.2 dependencies/libatomic/latest


#### ==== NGX PAGESPEED ==== ####
modules/pagespeed: sources/pagespeed
	@echo "Preparing ngx_pagespeed..."
	@mkdir -p ./modules/pagespeed

	@mv ngx_pagespeed-release-$(PAGESPEED_VERSION)/ modules/pagespeed/$(PAGESPEED_VERSION)
	@mv psol-$(PSOL_VERSION).tar.gz release-$(PAGESPEED_VERSION).zip sources/pagespeed/

sources/pagespeed:
	@mkdir -p ./sources/pagespeed

	@echo "Fetching ngx_pagespeed..."
	@curl --progress-bar https://codeload.github.com/pagespeed/ngx_pagespeed/zip/release-$(PAGESPEED_VERSION) > release-$(PAGESPEED_VERSION).zip

	@echo "Extracting ngx_pagespeed..."
	@unzip -o release-$(PAGESPEED_VERSION).zip

	@echo "Fetching PSOL..."
	@curl --progress-bar https://dl.google.com/dl/page-speed/psol/$(PSOL_VERSION).tar.gz > psol-$(PSOL_VERSION).tar.gz

	@echo "Extracting PSOL..."
	@tar -xvf psol-$(PSOL_VERSION).tar.gz
	@mv psol/ ngx_pagespeed-release-$(PAGESPEED_VERSION)/
