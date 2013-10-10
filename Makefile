## == KEEN NGINX: makefile == ##

## Configuration

# nginx config
STABLE ?= 1.4.3
LATEST ?= 1.5.6

# pagespeed config
PAGESPEED ?= 1
PSOL_VERSION ?= 1.6.29.5
PAGESPEED_VERSION ?= 1.6.29.5-beta

all: sources
	@echo "Building..."
	@mkdir -p build/

clean:
	@echo "Cleaning..."
	@echo "    ... buildroot."
	@rm -fr build/
	@echo "    ... modules."
	@rm -fr modules/
	@echo "    ... sources."
	@rm -fr sources/

sources: sources/latest sources/stable modules
	@echo "Preparing sources..."

sources/latest:
	@echo "Preparing Nginx latest..."
	@mkdir -p sources/$(LATEST)
	@ln -s $(LATEST)/ sources/latest

	@echo "Fetching Nginx $(LATEST)..."
	@curl --progress-bar http://nginx.org/download/nginx-$(LATEST).zip > nginx-$(LATEST).zip
	@unzip -o nginx-$(LATEST).zip -d sources/$(LATEST)
	@mv nginx-$(LATEST).zip sources/$(LATEST)

sources/stable:
	@echo "Preparing Nginx stable..."
	@mkdir -p sources/$(STABLE)
	@ln -s $(STABLE)/ sources/stable

	@echo "Fetching Nginx $(STABLE)..."
	@curl --progress-bar http://nginx.org/download/nginx-$(STABLE).zip > nginx-$(STABLE).zip
	@unzip -o nginx-$(STABLE).zip -d sources/$(STABLE)
	@mv nginx-$(STABLE).zip sources/$(STABLE)

modules: modules/pagespeed
	@echo "Preparing Nginx modules..."

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
