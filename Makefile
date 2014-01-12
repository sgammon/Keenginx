## == KEEN NGINX: makefile == ##

## dependencies: gperf unzip subversion build-essential tar pod2pdf groff xsltproc libxml2-utils

##### Configuration

DEBUG ?= 1
STAMP = 1.5x70-alpha7
WORKSPACE ?= trunk
PROJECT ?= $(shell pwd)

# nginx config
trunk ?= 1.5.9
stable ?= 1.4.3
latest ?= 1.5.8

# pagespeed config
PAGESPEED ?= 0
PSOL_VERSION ?= 1.7.30.2
PAGESPEED_VERSION ?= 1.7.30.2-beta
PAGESPEED_EXTRA_ENV ?=

# pcre config
PCRE ?= 1
PCRE_VERSION ?= 8.32

# pcre config
ZLIB ?= 1
ZLIB_VERSION ?= 1.2.7

# openssl config
OPENSSL ?= 1
OPENSSL_VERSION ?= 1.0.1f

# libatomic config
LIBATOMIC ?= 1


##### Nginx Configuration
NGINX_BASEPATH ?= opt/keenginx-$(STAMP)
NGINX_CONFPATH ?= etc/nginx/nginx.conf
NGINX_LOCKPATH ?= tmp/nginx.lock
NGINX_SBINPATH ?= $(NGINX_BASEPATH)/sbin/nginx
NGINX_LOGPATH ?= var/log/nginx
NGINX_TEMPPATH ?= tmp
NGINX_PIDPATH ?= var/run/nginx.pid
NGINX_PERFTOOLS ?= 0

ifeq ($(DEBUG),1)
OVERRIDE_PATHS ?= 1
PAGESPEED_RELEASE ?= Debug
NGINX_USER ?= $(shell whoami)
NGINX_GROUP ?= $(shell id -g -n $(NGINX_USER))
NGINX_ROOT ?= /

ifeq ($(PAGESPEED),1)
TARSTAMP:=$(STAMP)-ps-debug
else
TARSTAMP:=$(STAMP)-debug
endif

else
OVERRIDE_PATHS ?= 1
PAGESPEED_RELEASE ?= Release
NGINX_USER ?= www-data
NGINX_GROUP ?= keen
NGINX_ROOT ?= /

ifeq ($(PAGESPEED),1)
TARSTAMP:=$(STAMP)-ps
else
TARSTAMP:=$(STAMP)
endif

endif

ifeq ($(PAGESPEED),1)
PAGESPEED_MODULE=pagespeed
PATCH_PAGESPEED=patch_pagespeed
DEPENDENCIES_PAGESPEED=dependencies/depot_tools
endif

NGINX_PREFIX:=$(NGINX_ROOT)$(NGINX_BASEPATH)

PSOL_ENV := PSOL_BINARY=$(PROJECT)/modules/pagespeed/$(PAGESPEED_VERSION)/psol/lib/$(PAGESPEED_RELEASE)/linux/x64/pagespeed_automatic.a
PAGESPEED_ENV := $(PSOL_ENV) MOD_PAGESPEED_DIR=$(PROJECT)/sources/pagespeed/$(PAGESPEED_VERSION)/trunk/src
NGINX_ENV += $(PAGESPEED_ENV)

# configure vars
_nginx_debug_cpuflags = -g -O0
_nginx_release_cpuflags = -O3 -mtune=native -march=native -m64 -fomit-frame-pointer -fno-exceptions -fno-strict-aliasing

# openssl flags
_openssl_flags:=-DOPENSSL_EC_NISTP_64_GCC_128 -DOPENSSL_RC5

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
OSNAME := `uname`
PATCH ?= omnibus
CURRENT := $($(WORKSPACE))

# flags for mac os x
ifeq ($(OSNAME),Darwin)
	CC := clang
	PAGESPEED = 0
	ifeq ($(DEBUG),0)
		_nginx_gccflags = $(_nginx_gccflags) -mssse3
	endif
endif

ifeq ($(OSNAME),Linux)
	CC := gcc
	EXTRA_FLAGS += --with-file-aio
	ifeq ($(DEBUG),1)
		_nginx_gccflags = $(_nginx_gccflags) -fno-stack-protector
	else
		_nginx_gccflags = $(_nginx_gccflags) -w
	endif
endif

# do we compile-in openssl?
ifeq ($(OPENSSL),1)
	EXTRA_FLAGS += --with-openssl=dependencies/openssl/$(OPENSSL_VERSION)/openssl-$(OPENSSL_VERSION) --with-http_ssl_module --with-http_spdy_module
endif


# patch directories
_common_patches = $(wildcard patches/common/*)
_current_patches := $(wildcard patches/$(CURRENT)/*)
_pagespeed_patches = $(wildcard patches/pagespeed/*)

# do we compile-in pagespeed?
ifeq ($(PAGESPEED),1)
	EXTRA_FLAGS += --add-module=modules/pagespeed/$(PAGESPEED_VERSION)
endif

# do we compile-in our version of PCRE?
ifeq ($(PCRE),1)
	EXTRA_FLAGS += --with-pcre=dependencies/pcre/$(PCRE_VERSION)/pcre-$(PCRE_VERSION) --with-pcre-jit #--with-pcre-opt="$(_nginx_gccflags)"
endif

# do we compile-in our version of Zlib?
ifeq ($(ZLIB),1)
	EXTRA_FLAGS += --with-zlib=dependencies/zlib/$(ZLIB_VERSION)/zlib-$(ZLIB_VERSION) #--with-zlib-opt="$(_nginx_gccflags)"
endif

# do we compile-in libatomic?
ifeq ($(LIBATOMIC),1)
	EXTRA_FLAGS += --with-libatomic=dependencies/libatomic/7.2/libatomic_ops-7.2
endif

# do we override paths?
ifeq ($(OVERRIDE_PATHS),1)
	EXTRA_FLAGS += --prefix=$(NGINX_PREFIX) \
				   --pid-path=$(NGINX_ROOT)$(NGINX_PIDPATH) \
				   --sbin-path=$(NGINX_ROOT)$(NGINX_SBINPATH) \
				   --lock-path=$(NGINX_ROOT)$(NGINX_LOCKPATH) \
				   --conf-path=$(NGINX_ROOT)$(NGINX_CONFPATH) \
				   --http-log-path=$(NGINX_ROOT)$(NGINX_LOGPATH)/access.log \
				   --error-log-path=$(NGINX_ROOT)$(NGINX_LOGPATH)/error.log \
				   --http-scgi-temp-path=$(NGINX_ROOT)$(NGINX_TEMPPATH)/scgi \
				   --http-uwsgi-temp-path=$(NGINX_ROOT)$(NGINX_TEMPPATH)/uwsgi \
				   --http-proxy-temp-path=$(NGINX_ROOT)$(NGINX_TEMPPATH)/proxy \
				   --http-fastcgi-temp-path=$(NGINX_ROOT)$(NGINX_TEMPPATH)/fastcgi \
				   --http-client-body-temp-path=$(NGINX_ROOT)$(NGINX_TEMPPATH)/client
endif

_nginx_config_mainflags := --user=$(NGINX_USER) \
						   --group=$(NGINX_GROUP) \
						   --with-file-aio \
						   --with-ipv6 \
						   --with-rtsig_module \
						   --without-poll_module \
						   --without-select_module \
						   --with-http_gunzip_module \
						   --with-http_stub_status_module \
						   --with-http_gzip_static_module \
						   --with-md5-asm \
						   --with-sha1-asm \
						   --without-http_ssi_module \
						   --without-http_userid_module \
						   --without-http_geo_module \
						   --without-http_split_clients_module \
						   --without-http_referer_module \
						   --without-http_fastcgi_module \
						   --without-http_scgi_module \
						   --without-http_browser_module \
						   --without-mail_smtp_module \
						   --without-mail_pop3_module \
						   --without-mail_imap_module \
						   $(EXTRA_FLAGS)


#### ==== TOP-LEVEL RULES ==== ####
all: sources modules workspace package

seal:
	@echo "Removing omnibus..."
	@rm -f patches/$(CURRENT)/omnibus.patch.bk

	@echo "Generating new core patch..."
	-diff -Naurdw sources/$(CURRENT)/nginx-$(CURRENT)/src/ workspace/ > patches/$(CURRENT)/omnibus.patch

	@echo "Generating new pagespeed patch..."
	-diff -Naurdw sources/pagespeed/$(PAGESPEED_VERSION)/ pagespeed/ > patches/pagespeed/omnibus.patch

package: build
	@echo "Packaging build..."
	@mv sources/$(CURRENT)/nginx-$(CURRENT) ./nginx-$(STAMP)/;
	#@mv pagespeed/ nginx-$(CURRENT)/pagespeed

	@echo "Packaging tarball..."
	@tar -czvf keenginx-$(TARSTAMP).tar.gz nginx-$(STAMP)/
	#@mv nginx-$(CURRENT)/pagespeed ./pagespeed
	@mv nginx-$(STAMP)/ sources/$(CURRENT)/nginx-$(CURRENT);
	@mv keenginx-$(TARSTAMP).tar.gz build/;
	@echo "=== Finished Keen-Nginx build. ==="

release:
	@echo "------------------------------------"
	@echo "!!!!! Starting Keenginx build. !!!!!"
	@echo "------------------------------------"
	@echo ""
	@echo "This will most certainly take awhile. Today we'll be building four versions:"
	@echo "--production with no pagespeed"
	@echo "--production with pagespeed"
	@echo "--debug with no pagespeed"
	@echo "--debug with pagespeed"
	@echo ""
	@echo "Waiting for 30..."
	@echo ""
	@sleep 30

	@echo ""
	@echo "!!!!! Building production Keenginx WITHOUT pagespeed. !!!!!"
	@sleep 5
	make PAGESPEED=0 OPENSSL=$(OPENSSL) ZLIB=$(ZLIB) DEBUG=0 all
	@echo ""

	@echo ""
	@echo "!!!!! Building debug Keenginx WITHOUT pagespeed. !!!!!"
	@sleep 5
	make PAGESPEED=0 OPENSSL=$(OPENSSL) ZLIB=$(ZLIB) DEBUG=1 all
	@echo ""

	@echo ""
	@echo "!!!!! Building production Keenginx WITH pagespeed. !!!!!"
	@sleep 5
	make PAGESPEED=1 OPENSSL=$(OPENSSL) ZLIB=$(ZLIB) DEBUG=0 modules/pagespeed all
	@echo ""

	@echo ""
	@echo "!!!!! Building debug Keenginx WITH pagespeed. !!!!!"
	@sleep 5
	make PAGESPEED=1 OPENSSL=$(OPENSSL) ZLIB=$(ZLIB) DEBUG=1 all
	@echo ""
	@echo ""
	@echo "!!!!!!!!!! DONE :) !!!!!!!!!!"

build: patch
	@echo "Compiling Nginx $(CURRENT)..."
	@echo "Copying custom sources..."
	@cp -fr workspace/* sources/$(CURRENT)/nginx-$(CURRENT)/
	make configure_nginx;
	make build_nginx;
	@echo "Creating directories..."
	@mkdir -p build/cache/nginx/client build/cache/nginx/proxy
	@echo "Finished building Nginx $(CURRENT)."

ifneq ($(WORKSPACE),trunk)
patch: sources dependencies workspace patch_common patch_$(CURRENT) $(PATCH_PAGESPEED)
	@echo "Patching complete."
	@echo "Applied patches:"
	@echo "  -- Common: " $(_common_patches)
	@echo "  -- Specific:" $(_current_patches)
endif
ifeq ($(WORKSPACE),trunk)
patch: sources dependencies workspace patch_common patch_$(CURRENT) $(PATCH_PAGESPEED)
	@echo "Building Nginx release metapackage..."
	@cd sources/$(CURRENT)/master; \
		make -f misc/GNUmakefile release; \
		cp -fr ./tmp/nginx-$(trunk) ../; \
		cd ..;
endif

clean: clean_nginx
	@echo "Cleaning..."
	@echo "    ... buildroot."
	@-rm -fr build/
	@echo "    ... workspace."
	@-rm -fr workspace
	@echo "    ... pagespeed."
	@-rm -fr pagespeed

distclean: clean
	@echo "    ... dependencies."
	@rm -fr dependencies/
	@echo "    ... modules."
	@rm -fr modules/
	@echo "    ... sources."
	@rm -fr sources/
	@echo "Resetting codebase..."
	@git reset --hard
	@echo "Cleaning files..."
	@git clean -xdf

sources: dependencies
	@echo "Finished acquiring sources."

modules: $(PAGESPEED_MODULE)
	@echo "Downloaded module sources."

dependencies: dependencies/pcre dependencies/zlib dependencies/openssl dependencies/libatomic $(DEPENDENCIES_PAGESPEED)
	@echo "Finished fetching dependency sources."


#### ==== WORKSPACE RULES ==== ####
workspace: workspace/.$(WORKSPACE)

workspace/.$(WORKSPACE): sources/$(WORKSPACE)
	@echo "Setting workspace to '$(WORKSPACE)'..."
	@mkdir -p workspace/
	@cp -fr sources/$(CURRENT)/nginx-$(CURRENT)/* workspace/
	@touch workspace/.$(WORKSPACE)


#### ==== PATCH APPLICATION ==== ####
patch_common: $(_common_patches)
	@echo "Applying patch " $^ "..."
	-patch -N -p0 < `cat $^`
	@echo "Patch done."

patch_$(CURRENT): $(_current_patches)
	@echo "Applying patch " $^ "..."
	-patch -N -p0 < `cat $^`
	@echo "Patch done."

ifeq ($(PAGESPEED),1)
patch_pagespeed: $(_pagespeed_patches)
	@echo "Applying patch " $^ "..."
	-@cd modules/pagespeed/$(PAGESPEED_VERSION); \
		-patch -N -p1 < ../../../$^; \
		cd ../../../;
	@echo "Patch done."
endif

#### ==== NGINX SOURCES ==== ####
ifneq ($(WORKSPACE),trunk)
sources/$(WORKSPACE):
	@echo "Preparing Nginx $(WORKSPACE)..."
	@mkdir -p sources/$(CURRENT)
	@ln -s $(CURRENT)/ sources/$(WORKSPACE)

	@echo "Fetching Nginx $(CURRENT)..."
	@curl --progress-bar http://nginx.org/download/nginx-$(CURRENT).tar.gz > nginx-$(CURRENT).tar.gz

	@echo "Extracting Nginx $(CURRENT)..."
	@tar -xvf nginx-$(CURRENT).tar.gz
	@mv nginx-$(CURRENT).tar.gz nginx-$(CURRENT) sources/$(CURRENT)
endif
ifeq ($(WORKSPACE),trunk)
sources/$(WORKSPACE):
	@echo "Preparing Nginx trunk..."
	@mkdir -p sources/$(CURRENT)
	@ln -s $(CURRENT)/ sources/$(WORKSPACE)

	@echo "Cloning Nginx sources..."
	@hg clone http://hg.nginx.org/nginx sources/$(CURRENT)/master

	@echo "Building Nginx release metapackage..."
	@cd sources/$(CURRENT)/master; \
		make -f misc/GNUmakefile release; \
		cp -fr ./tmp/nginx-$(trunk) ../; \
		cd ..;

endif


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
	@curl --progress-bar http://commondatastorage.googleapis.com/keen-static/dependencies/zlib/zlib-$(ZLIB_VERSION).tar.gz > zlib-$(ZLIB_VERSION).tar.gz

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


ifeq ($(PAGESPEED),1)
#### ==== NGX PAGESPEED ==== ####
pagespeed: sources/pagespeed
	@echo "Mounting Pagespeed sources..."
	@mkdir -p pagespeed/
	@cp -fr sources/pagespeed/$(PAGESPEED_VERSION)/* pagespeed/

modules/pagespeed: dependencies/depot_tools sources/pagespeed
	@echo "Preparing ngx_pagespeed..."
	@mkdir -p ./modules/pagespeed

	-@mv ngx_pagespeed-release-$(PAGESPEED_VERSION)/ modules/pagespeed/$(PAGESPEED_VERSION)
	-@mv psol-$(PSOL_VERSION).tar.gz release-$(PAGESPEED_VERSION).zip sources/pagespeed/

	@echo "Building pagespeed core..."
	-cd ./sources/pagespeed/$(PAGESPEED_VERSION)/trunk/src; \
		make AR.host="$(PROJECT)/sources/pagespeed/$(PAGESPEED_VERSION)/trunk/src/build/wrappers/ar.sh" \
	         AR.target="$(PROJECT)/sources/pagespeed/$(PAGESPEED_VERSION)/trunk/src/build/wrappers/ar.sh" \
		     BUILDTYPE=$(PAGESPEED_RELEASE) \
	         mod_pagespeed_test pagespeed_automatic_test;

	@echo "Building PSOL sources..."
	-cd ./sources/pagespeed/$(PAGESPEED_VERSION)/trunk/src/net/instaweb/automatic; \
		make AR.host="$(PROJECT)/sources/pagespeed/$(PAGESPEED_VERSION)/trunk/src/build/wrappers/ar.sh" \
	         AR.target="$(PROJECT)/sources/pagespeed/$(PAGESPEED_VERSION)/trunk/src/build/wrappers/ar.sh" \
		     BUILDTYPE=$(PAGESPEED_RELEASE) \
	         all;

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
endif

#### ==== BUILD RULES ==== ####
build_nginx:
	@echo "Compiling Nginx..."
	@mkdir -p build/ dist/
	cd sources/$(CURRENT)/nginx-$(CURRENT); \
		CC=$(CC) CFLAGS="$(_nginx_gccflags)" CXXFLAGS="$(CXXFLAGS)" $(NGINX_ENV) make;

clean_nginx:
	@echo "Cleaning Nginx..."
	@-make -f sources/$(CURRENT)/nginx-$(CURRENT)/Makefile clean;

	@echo "Cleaning modules..."
	@-rm -fr modules/

configure_nginx:
	@echo "Configuring Nginx..."
	-cp -fr modules dependencies sources/$(CURRENT)/nginx-$(CURRENT); \
		cd sources/$(CURRENT)/nginx-$(CURRENT); \
		CC=$(CC) CFLAGS="$(_nginx_gccflags)" CXXFLAGS="$(CXXFLAGS)" ./configure $(_nginx_config_mainflags) --with-cc-opt="$(_nginx_gccflags)" --with-openssl-opt="$(_openssl_flags)"; \
		cd ../../../;
	@echo "Stamping configuration..."
	@echo "CC=$(CC) CFLAGS=\"$(_nginx_gccflags)\" CXXFLAGS=\"$(CXXFLAGS)\" ./configure --with-cc-opt=\"$(_nginx_gccflags)\" --with-openssl-opt=\"$(_openssl_flags)\" $(_nginx_config_mainflags)" > workspace/.build_cmd
	@echo "CC=$(CC) CFLAGS=\"$(_nginx_gccflags)\" CXXFLAGS=\"$(CXXFLAGS)\" $(NGINX_ENV) make ;" > workspace/.make_cmd
	@cp -f workspace/.build_cmd workspace/.make_cmd sources/$(CURRENT)/nginx-$(CURRENT)

install_nginx:
	@echo "Installing Nginx..."
	-cd sources/$(CURRENT)/nginx-$(CURRENT); \
		make install; \
		cd ../../../;
