## == KEEN NGINX: makefile == ##

## Configuration

# nginx config
STABLE ?= ""
LATEST ?= "1.5.6"

# pagespeed config
PAGESPEED ?= 1
PSOL_VERSION ?= "1.6.29.5"
PAGESPEED_VERSION = "1.6.29.5-beta"

all: sources
	mkdir -p build/

clean:
	rm -fr build/
	mkdir build/
	git checkout build/

sources: modules
	mkdir -p sources/ modules/
	curl --progress-bar http://nginx.org/download/nginx-$(LATEST).zip > sources/nginx-$(LATEST).zip

modules:

	## pagespeed
	mkdir -p modules/pagespeed
	curl --progress-bar https://dl.google.com/dl/page-speed/psol/$(PSOL_VERSION).tar.gz > modules/pagespeed/psol-$(PSOL_VERSION).tar.gz
	curl --progress-bar https://github.com/pagespeed/ngx_pagespeed/archive/release-$(PSOL_VERSION).zip > modules/pagespeed/release-$(PSOL_VERSION).zip
	unzip modules/pagespeed/release-$(PSOL_VERSION).zip
