## == KEEN NGINX: makefile == ##

##### Configuration

WORKSPACE ?= latest

# nginx config
STABLE ?= 1.4.3
LATEST ?= 1.5.6

# pagespeed config
PAGESPEED ?= 1
PSOL_VERSION ?= 1.6.29.5
PAGESPEED_VERSION ?= 1.6.29.5-beta

# pcre config
PCRE_VERSION = 8.33

# openssl config
OPENSSL_VERSION ?= 1.0.1e


#### ==== TOP-LEVEL RULES ==== ####

all: sources workspace package

package: build
	@echo "Packaging..."
	@echo "=== Finished Keen-Nginx build. ==="

build: patch
	@echo "Building..."
	@mkdir -p build/

patch: sources
	@echo "Patching..."

clean:
	@echo "Cleaning..."
	@echo "    ... buildroot."
	@rm -fr build/
	@echo "    ... workspace."
	@rm -fr workspace

distclean: clean
	@echo "    ... dependencies."
	@rm -fr dependencies/
	@echo "    ... modules."
	@rm -fr modules/
	@echo "    ... sources."
	@rm -fr sources/

sources: sources/latest sources/stable modules
	@echo "Finished acquiring sources."

modules: modules/pagespeed
	@echo "Downloaded module sources."

dependencies: dependencies/pcre dependencies/openssl dependencies/libatomic
	@echo "Finished fetching dependency sources."


#### ==== WORKSPACE RULES ==== ####

workspace: workspace/.$(WORKSPACE)

workspace/.latest: sources/latest
	@echo "Setting workspace to 'latest'..."
	@ln -s sources/$(LATEST)/nginx-$(LATEST)/src/ workspace
	@touch workspace/.latest

workspace/.stable: sources/stable
	@echo "Setting workspace to 'stable'..."
	@ln -s sources/$(STABLE)/nginx-$(STABLE)/src/ workspace
	@touch workspace/.stable


#### ==== NGINX SOURCES ==== ####

sources/latest:
	@echo "Preparing Nginx latest..."
	@mkdir -p sources/$(LATEST)
	@ln -s $(LATEST)/ sources/latest

	@echo "Fetching Nginx $(LATEST)..."
	@curl --progress-bar http://nginx.org/download/nginx-$(LATEST).tar.gz > nginx-$(LATEST).tar.gz

	@echo "Extracting Nginx $(LATEST)..."
	@tar -xvf nginx-$(LATEST).tar.gz
	@mv nginx-$(LATEST).tar.gz nginx-$(LATEST) sources/$(LATEST)

sources/stable:
	@echo "Preparing Nginx stable..."
	@mkdir -p sources/$(STABLE)
	@ln -s $(STABLE)/ sources/stable

	@echo "Fetching Nginx $(STABLE)..."
	@curl --progress-bar http://nginx.org/download/nginx-$(STABLE).tar.gz > nginx-$(STABLE).tar.gz

	@echo "Extracting Nginx $(STABLE)..."
	@tar -xvf nginx-$(STABLE).tar.gz
	@mv nginx-$(STABLE).tar.gz nginx-$(STABLE) sources/$(STABLE)


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
