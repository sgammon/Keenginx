## == KEEN NGINX: makefile == ##

## dependencies: gperf, unzip, subversion, build-essential tar

##### Configuration

DEBUG ?= 1
WORKSPACE ?= latest
PROJECT ?= $(shell pwd)

# nginx config
stable ?= 1.4.3
latest ?= 1.5.6

# pagespeed config
PAGESPEED ?= 0
PSOL_VERSION ?= 1.6.29.5
PAGESPEED_VERSION ?= 1.6.29.5-beta
PAGESPEED_EXTRA_ENV ?=

# pcre config
PCRE ?= 1
PCRE_VERSION ?= 8.33

# pcre config
ZLIB ?= 1
ZLIB_VERSION ?= 1.2.8

# openssl config
OPENSSL ?= 1
OPENSSL_VERSION ?= 1.0.1e

# libatomic config
LIBATOMIC ?= 1


##### Nginx Configuration
NGINX_BASEPATH ?= ns/keen
NGINX_LOGPATH ?= data/logs/nginx
NGINX_TEMPPATH ?= cache/nginx
NGINX_PERFTOOLS ?= 0

ifeq ($(DEBUG),1)
OVERRIDE_PATHS ?= 1
PAGESPEED_RELEASE ?= Debug
NGINX_USER ?= $(shell whoami)
NGINX_GROUP ?= $(shell id -g -n $(NGINX_USER))
NGINX_ROOT ?= $(PROJECT)/build/
else
OVERRIDE_PATHS ?= 0
PAGESPEED_RELEASE ?= Release
NGINX_USER ?= nginx
NGINX_GROUP ?= keen
NGINX_ROOT ?= /
endif

PSOL_ENV := PSOL_BINARY=$(PROJECT)/modules/pagespeed/$(PAGESPEED_VERSION)/psol/lib/$(PAGESPEED_RELEASE)/linux/x64/pagespeed_automatic.a
PAGESPEED_ENV := $(PSOL_ENV) MOD_PAGESPEED_DIR=$(PROJECT)/sources/pagespeed/$(PAGESPEED_VERSION)/trunk/src
NGINX_ENV += $(PAGESPEED_ENV)

# configure vars
_nginx_debug_cpuflags = -g -O0
_nginx_release_cpuflags = -O3 -mtune=native -march=native

ifeq ($(DEBUG),0)
	_nginx_gccflags = $(_nginx_release_cpuflags)
else
	EXTRA_FLAGS += --with-debug
	ifeq ($(NGINX_PERFTOOLS),1)
		EXTRA_FLAGS += --with-google_perftools_module
	endif
	_nginx_gccflags = $(_nginx_debug_cpuflags)
endif


##### Runtime
OS := `uname`
PATCH ?= omnibus
CURRENT := $($(WORKSPACE))

# flags for mac os x
ifeq ($(OS),Darwin)
	CC := clang
	PAGESPEED = 0
	ifeq ($(DEBUG),0)
		_nginx_gccflags = $(_nginx_gccflags) -mssse3 -flto
	endif
endif

ifeq ($(OS),Linux)
	CC := gcc
	EXTRA_FLAGS += --with-file-aio
	ifeq ($(DEBUG),1)
		_nginx_gccflags = $(_nginx_gccflags) -fno-stack-protector
	else
		_nginx_gccflags = $(_nginx_gccflags) -w -fomit-frame-pointer -fno-stack-protector -flto
	endif

	# do we compile-in openssl?
	ifeq ($(OPENSSL),1)
		EXTRA_FLAGS += --with-openssl=../../../dependencies/openssl/latest --with-http_ssl_module --with-http_spdy_module #--with-openssl-opt="$(_nginx_gccflags)"
	endif
endif

# patch directories
_common_patches = $(wildcard patches/common/*)
_current_patches := $(wildcard patches/$(CURRENT)/*)

# do we compile-in pagespeed?
ifeq ($(PAGESPEED),1)
	EXTRA_FLAGS += --add-module=../../../modules/pagespeed/$(PAGESPEED_VERSION)
endif

# do we compile-in our version of PCRE?
ifeq ($(PCRE),1)
	EXTRA_FLAGS += --with-pcre=../../../dependencies/pcre/latest --with-pcre-jit #--with-pcre-opt="$(_nginx_gccflags)"
endif

# do we compile-in our version of Zlib?
ifeq ($(ZLIB),1)
	EXTRA_FLAGS += --with-zlib=../../../dependencies/zlib/latest #--with-zlib-opt="$(_nginx_gccflags)"
endif

# do we compile-in libatomic?
ifeq ($(LIBATOMIC),1)
	EXTRA_FLAGS += --with-libatomic=../../../dependencies/libatomic/latest
endif

# do we override paths?
ifeq ($(OVERRIDE_PATHS),1)
	EXTRA_FLAGS += --prefix=$(NGINX_ROOT)$(NGINX_BASEPATH) \
				   --http-log-path=$(NGINX_ROOT)$(NGINX_LOGPATH)/access.log \
				   --error-log-path=$(NGINX_ROOT)$(NGINX_LOGPATH)/error.log \
				   --http-scgi-temp-path=$(NGINX_ROOT)$(NGINX_TEMPPATH)/scgi \
				   --http-proxy-temp-path=$(NGINX_ROOT)$(NGINX_TEMPPATH)/proxy \
				   --http-uwsgi-temp-path=$(NGINX_ROOT)$(NGINX_TEMPPATH)/uwsgi \
				   --http-fastcgi-temp-path=$(NGINX_ROOT)$(NGINX_TEMPPATH)/fastcgi \
				   --http-client-body-temp-path=$(NGINX_ROOT)$(NGINX_TEMPPATH)/client
endif

_nginx_config_mainflags := --user=$(NGINX_USER) \
						   --group=$(NGINX_GROUP) \
						   --with-ipv6 \
						   --with-poll_module \
						   --with-rtsig_module \
						   --without-select_module \
						   --with-http_gunzip_module \
						   --with-http_gzip_static_module \
						   --with-http_secure_link_module \
						   --with-cc-opt="$(_nginx_gccflags)" \
						   --with-md5-asm \
						   --with-sha1-asm \
						   $(EXTRA_FLAGS) ;


#### ==== TOP-LEVEL RULES ==== ####
all: sources modules workspace package

seal:
	@echo "Removing omnibus..."
	@rm -f patches/$(CURRENT)/omnibus.patch.bk

	@echo "Generating new patch..."
	-diff -Naurdw sources/$(CURRENT)/nginx-$(CURRENT)/src/ workspace/ > patches/$(CURRENT)/omnibus.patch

package: build
	@echo "Packaging build..."
	make install_nginx;
	@mv workspace/ nginx-$(CURRENT)/;
	@echo "Packaging tarball..."
	@tar -czvf nginx-$(CURRENT).tar.gz nginx-$(CURRENT)/
	@mv nginx-$(CURRENT)/ workspace/;
	@mv nginx-$(CURRENT).tar.gz build/;
	@echo "=== Finished Keen-Nginx build. ==="

build: patch
	@echo "Compiling Nginx $(CURRENT)..."
	make configure_nginx;
	make build_nginx;
	@echo "Creating directories..."
	@mkdir -p build/cache/nginx/client build/cache/nginx/proxy
	@echo "Finished building Nginx $(CURRENT)."

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

sources: dependencies
	@echo "Finished acquiring sources."

modules: modules/pagespeed
	@echo "Downloaded module sources."

dependencies: dependencies/pcre dependencies/zlib dependencies/openssl dependencies/libatomic dependencies/depot_tools
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
	-@cd sources/$(CURRENT)/nginx-$(CURRENT)/src; \
		patch -N -p1 < ../../../../$^; \
		cd ../../../../;
	@echo "Patch done."

patch_$(CURRENT): $(_current_patches)
	@echo "Applying patch " $^ "..."
	-@cd sources/$(CURRENT)/nginx-$(CURRENT)/src; \
		patch -N -p1 < ../../../../$^; \
		cd ../../../../;
	@echo "Patch done."


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

dependencies/zlib:
	@echo "Fetching Zlib..."
	@mkdir -p dependencies/zlib/$(ZLIB_VERSION)
	@curl --progress-bar http://zlib.net/zlib-$(ZLIB_VERSION).tar.gz > zlib-$(ZLIB_VERSION).tar.gz

	@echo "Extracting Zlib..."
	@tar -xvf zlib-$(ZLIB_VERSION).tar.gz
	@mv zlib-$(ZLIB_VERSION)/ zlib-$(ZLIB_VERSION).tar.gz dependencies/zlib/$(ZLIB_VERSION)/
	@ln -s $(ZLIB_VERSION)/zlib-$(ZLIB_VERSION) dependencies/zlib/latest

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
modules/pagespeed: dependencies/depot_tools sources/pagespeed
	@echo "Preparing ngx_pagespeed..."
	@mkdir -p ./modules/pagespeed

	-@mv ngx_pagespeed-release-$(PAGESPEED_VERSION)/ modules/pagespeed/$(PAGESPEED_VERSION)
	-@mv psol-$(PSOL_VERSION).tar.gz release-$(PAGESPEED_VERSION).zip sources/pagespeed/

	#@echo "Building pagespeed core..."
	#-cd ./sources/pagespeed/$(PAGESPEED_VERSION)/trunk/src; \
	#	make AR.host="$(PROJECT)/sources/pagespeed/$(PAGESPEED_VERSION)/trunk/src/build/wrappers/ar.sh" \
	#         AR.target="$(PROJECT)/sources/pagespeed/$(PAGESPEED_VERSION)/trunk/src/build/wrappers/ar.sh" \
	#	     BUILDTYPE=$(PAGESPEED_RELEASE) \
	#         mod_pagespeed_test pagespeed_automatic_test;

	#@echo "Building PSOL sources..."
	#-cd ./sources/pagespeed/$(PAGESPEED_VERSION)/trunk/src/net/instaweb/automatic; \
	#	make AR.host="$(PROJECT)/sources/pagespeed/$(PAGESPEED_VERSION)/trunk/src/build/wrappers/ar.sh" \
	#         AR.target="$(PROJECT)/sources/pagespeed/$(PAGESPEED_VERSION)/trunk/src/build/wrappers/ar.sh" \
	#	     BUILDTYPE=$(PAGESPEED_RELEASE) \
	#         all;

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

	@echo "Fetching ngx_pagespeed..."
	@mkdir -p sources/pagespeed/$(PAGESPEED_VERSION)/trunk;
	cd sources/pagespeed/$(PAGESPEED_VERSION)/trunk; \
		../../../../dependencies/depot_tools/gclient config http://modpagespeed.googlecode.com/svn/tags/$(PSOL_VERSION)/src; \
		../../../../dependencies/depot_tools/gclient sync --force --jobs=1;
		cd ../../../../;


#### ==== BUILD RULES ==== ####
build_nginx:
	@echo "Compiling Nginx..."
	@mkdir -p build/ dist/
	cd sources/$(CURRENT)/nginx-$(CURRENT); \
		CC=$(CC) CFLAGS="$(_nginx_gccflags)" CXXFLAGS="$(CXXFLAGS)" $(NGINX_ENV) make;

clean_nginx:
	@echo "Cleaning Nginx..."
	-@cd sources/$(CURRENT)/nginx-$(CURRENT); \
		make clean; \
		rm -f modules/; \
		cd ../../../;

configure_nginx:
	@echo "Configuring Nginx..."
	-cd sources/$(CURRENT)/nginx-$(CURRENT); \
		CC=$(CC) CFLAGS="$(_nginx_gccflags)" CXXFLAGS="$(CXXFLAGS)" $(NGINX_ENV) ./configure $(_nginx_config_mainflags) \
		cd ../../../;
	@echo "Stamping configuration..."
	@echo "CC=$(CC) CFLAGS=\"$(_nginx_gccflags)\" CXXFLAGS=\"$(CXXFLAGS)\" $(NGINX_ENV) ./configure $(_nginx_config_mainflags); CC=$(CC) CFLAGS=\"$(_nginx_gccflags)\" CXXFLAGS=\"$(CXXFLAGS)\" $(NGINX_ENV) make ; sudo make install" > workspace/.build_cmd

install_nginx:
	@echo "Installing Nginx..."
	-cd sources/$(CURRENT)/nginx-$(CURRENT); \
		make install; \
		cd ../../../;
