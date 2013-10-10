## == KEEN NGINX: makefile == ##

##### Configuration

DEBUG ?= 1
WORKSPACE ?= latest

# nginx config
stable ?= 1.4.3
latest ?= 1.5.6

# pagespeed config
PAGESPEED ?= 1
PSOL_VERSION ?= 1.6.29.5
PAGESPEED_VERSION ?= 1.6.29.5-beta

ifeq ($(DEBUG),0)
PAGESPEED_BUILD ?= Release
else
PAGESPEED_BUILD ?= Debug
endif

# pcre config
PCRE ?= 1
PCRE_VERSION ?= 8.33

# openssl config
OPENSSL ?= 1
OPENSSL_VERSION ?= 1.0.1e

# libatomic config
LIBATOMIC ?= 1


##### Nginx Configuration
NGINX_USER ?= nginx
NGINX_GROUP ?= keen


##### Runtime
OS := `uname`
PATCH ?= omnibus
CURRENT := $($(WORKSPACE))

# flags for mac os x
ifeq ($(OS),Darwin)
	CC ?= clang
	CPP ?= clang
	ifeq ($(DEBUG),1)
		CFLAGS += -g -O0
		CXXFLAGS += -g -O0
	else
		CFLAGS += -O3 -mtune=native -mssse3 -march=native -flto
		CXXFLAGS += -O3 -mtune=native -mssse3 -march=native -flto
	endif
endif

ifeq ($(OS),Linux)
	CC ?= gcc
	CPP ?= g++
	EXTRA_FLAGS += --with-file-aio
	ifeq ($(DEBUG),1)
		CFLAGS += -g -O0 -fno-stack-protector
		CXXFLAGS += -g -O0 -fno-stack-protector
	else
		CFLAGS += -O3 -mtune=native -march=native -w -fomit-frame-pointer -fno-stack-protector -flto
		CXXFLAGS += -O3 -mtune=native -march=native -w -fomit-frame-pointer -fno-stack-protector -flto
	endif
endif

# commands

# patch directories
_common_patches = $(wildcard patches/common/*)
_current_patches := $(wildcard patches/$(CURRENT)/*)

# configure vars
_nginx_debug_cpuflags = -O0 -g
_nginx_release_cpuflags = -O3 -mtune=x86_64-linux -march=native

ifeq ($(DEBUG),0)
	_nginx_gccflags = $(_nginx_release_cpuflags)
else
	EXTRA_FLAGS += --with-debug --with-google_perftools_module
	_nginx_gccflags = $(_nginx_debug_cpuflags)
endif

_pcre_config := --enable-shared \
				--enable-static \
				--enable-pcre16 \
				--enable-pcre32 \
				--enable-jit \
				--enable-utf \
				--enable-unicode-properties \
				--enable-newline-is-any \
				--enable-pcregrep-libz \
				--enable-pcregrep-libbz2 \
				--with-pic

_openssl_config := threads \
				   zlib

_nginx_config_mainflags := --user=$(NGINX_USER) \
						   --group=$(NGINX_GROUP) \
						   --with-rtsig_module \
						   --without-select_module \
						   --with-poll_module \
						   --with-ipv6 \
						   --with-http_ssl_module \
						   --with-http_spdy_module \
						   --with-http_gunzip_module \
						   --with-http_stub_status_module \
						   --with-http_gzip_static_module \
						   --with-http_secure_link_module \
						   --with-cc-opt="$(_nginx_gccflags)" \
						   --with-pcre=dependencies/pcre/latest \
						   --with-pcre-jit \
						   --with-pcre-opt="$(_pcre_config)" \
						   --with-md5-asm \
						   --with-sha1-asm \
						   --with-zlib-asm=pentiumpro \
						   --with-libatomic=dependencies/libatomic/latest \
						   --with-openssl=dependencies/openssl/latest \
						   --with-openssl-opt="$(_openssl_config)" \
						   --without-http_userid_module \
						   --without-http_autoindex_module \
						   --without-http_geo_module \
						   --without-http_fastcgi_module \
						   --without-http_scgi_module \
						   --without-mail_pop3_module \
						   --without-mail_imap_module \
						   --without-mail_smtp_module \
						   --with-cc=$(CC) \
						   --add-module=modules/pagespeed/$(PAGESPEED_VERSION) \
						   $(EXTRA_FLAGS) ;


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

	@mkdir -p build/ dist/
	
	@echo "Compiling Nginx..."


patch: sources patch_common patch_$(CURRENT)
	@echo "Patching complete."
	@echo "Applied patches:"
	@echo "  -- Common: " $(_common_patches)
	@echo "  -- Specific:" $(_current_patches)

clean: clean_nginx
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
	@echo "Resetting codebase..."
	@git reset --hard

sources: dependencies modules
	@echo "Finished acquiring sources."

modules: modules/pagespeed
	@echo "Downloaded module sources."

dependencies: dependencies/pcre dependencies/openssl dependencies/libatomic dependencies/depot_tools
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
	-@patch -N -p0 < $^

patch_$(CURRENT): $(_current_patches)
	@echo "Applying patch " $^ "..."
	-@patch -N -p0 < $^


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

dependencies/depot_tools:
	@echo "Fetching depot_tools..."
	@cd dependencies/; \
		svn co http://src.chromium.org/svn/trunk/tools/depot_tools; \
		cd ../;


#### ==== NGX PAGESPEED ==== ####
modules/pagespeed: sources/pagespeed build/psol
	@echo "Building PSOL..."
	@mkdir -p ./modules/pagespeed

sources/pagespeed: 
	@mkdir -p ./sources/pagespeed

	@echo "Fetching ngx_pagespeed..."
	@cd sources/pagespeed; \
		../../dependencies/depot_tools/gclient config http://modpagespeed.googlecode.com/svn/tags/$(PAGESPEED_VERSION)/; \
		../../dependencies/depot_tools/gclient sync --force --jobs=8; \
		cd ../../;

	@echo "Fetching PSOL..."
	@curl --progress-bar https://dl.google.com/dl/page-speed/psol/$(PSOL_VERSION).tar.gz > psol-$(PSOL_VERSION).tar.gz

	@echo "Extracting PSOL..."
	@tar -xvf psol-$(PSOL_VERSION).tar.gz
	@mv psol/ ngx_pagespeed-release-$(PAGESPEED_VERSION)/

build/psol: dependencies/depot_tools
	@echo "Building PSOL..."
	@cd modules/pagespeed/$(PAGESPEED_VERSION); \

	@echo "Copying sources..."
	@cp -fr ./sources/pagespeed/* ./modules/pagespeed/;

	@echo "Building pagespeed..."
	@cd ./modules/pagespeed/$(PAGESPEED_VERSION)/src; \
		make CFLAGS="$(CFLAGS)" \
			 CXXFLAGS="$(CXXFLAGS)" \
			 AR.host="$PWD/build/wrappers/ar.sh" \
			 AR.target="$PWD/build/wrappers/ar.sh" \
			 BUILDTYPE=$(PAGESPEED_BUILD) \
			 mod_pagespeed_test pagespeed_automatic_test;

	@echo "Building PSOL..."
	@cd ./modules/pagespeed/$(PAGESPEED_VERSION)/src/net/instaweb/automatic; \
		make CFLAGS="$(CFLAGS)" \
			 CXXFLAGS="-DSERF_HTTPS_FETCHING=0 $(CXXFLAGS)" \
			 AR.host="$PWD/../../../build/wrappers/ar.sh" \
			 AR.target="$PWD/../../../build/wrappers/ar.sh" \
			 BUILDTYPE=$(PAGESPEED_BUILD) \
			 all;


#### ==== BUILD RULES ==== ####
clean_nginx:
	@echo "Cleaning Nginx..."
	-@cd sources/$(CURRENT)/nginx-$(CURRENT); \
		make clean; \
		rm -f modules/; \
		cd ../../../;

configure_nginx:
	@echo "Configuring Nginx..."
	-@cd sources/$(CURRENT)/nginx-$(CURRENT); \
		ln -s ../../../modules modules; \
		./configure $(_nginx_config_mainflags) \
		cd ../../../;
