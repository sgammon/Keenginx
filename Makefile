## == KEEN NGINX: makefile == ##

## dependencies: make gperf unzip subversion build-essential tar pod2pdf groff xsltproc libxml2-utils software-properties-common python-software-properties mercurial gcc-4.8

## to prepare ubuntu 12.*:
# sudo apt-get install make software-properties-common python-software-properties
# sudo add-apt-repository ppa:ubuntu-toolchain-r/test; sudo apt-get update
# sudo apt-get install gcc-4.8 g++-4.8 binutils-gold gcc-4.8-locales g++-4.8-multilib gcc-4.8-doc libstdc++6-4.8-db8-dev libgcc1-dbg libgomp1-dbg libitm1-dbg libatomic1-dbg make
# sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.8 50
# wget http://www.mr511.de/software/libelf-0.8.12.tar.gz; tar -xvf libelf-0.8.12.tar.gz;
# pushd libelf-0.8.12; ./configure --enable-compat --enable-elf64 --enable-versioning --enable-nls --enable-shared --enable-extended-format; make; sudo make install; popd; sudo ldconfig -v;
# sudo apt-get install gperf unzip subversion build-essential tar pod2pdf groff xsltproc libxml2-utils gawk libbz2-dev libsnappy1 libsnappy-dev

##### Configuration

JOBS ?= 1
DEBUG ?= 1
STAMP = 1.5x110-alpha10
WORKSPACE ?= trunk
PROJECT ?= $(shell pwd)

# nginx versioning
trunk ?= 1.5.12
stable ?= 1.4.3
latest ?= 1.5.8

# binary config
LTO ?= 1
STATIC ?= 1

# pagespeed config
PAGESPEED ?= 0
PSOL_VERSION ?= 1.7.30.3
PAGESPEED_VERSION ?= 1.7.30.3-beta
PAGESPEED_EXTRA_ENV ?=

# pcre config
PCRE ?= 1
PCRE_VERSION ?= 8.32

# pcre config
ZLIB ?= 1
ZLIB_VERSION ?= 1.2.7

# openssl config
OPENSSL ?= 1
OPENSSL_TRUNK ?= 1
OPENSSL_VERSION ?= 1.0.1f
OPENSSL_SNAPSHOT ?= 1.0.2-stable-SNAP-20140304

# libatomic config
LIBATOMIC ?= 0


##### Overrides
ifeq ($(DEBUG),1)
STATIC=0
LTO=0
endif

ifeq ($(PAGESPEED),1)
STATIC=0
LTO=0
endif


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

ifeq ($(STATIC),1)
ifeq ($(LTO),1)
LDFLAGS=-static -flto=4 -fuse-linker-plugin -save-temps -flto-report
else
LDFLAGS=-static
endif
else
LDFLAGS=
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

# optimization flags
ifeq ($(LTO),1)
_lto_cflags = -flto=4
else
_lto_cflags =
endif

ifeq (0,1)
_nginx_opt_flags = -funroll-loops -fweb -ftree-loop-distribution -floop-nest-optimize -fgraphite-identity -floop-block -floop-strip-mine -ftree-loop-linear -floop-interchange -fgcse-after-reload -fgcse-las -fgcse-sm $(_lto_cflags)
else
_nginx_opt_flags = $(_lto_cflags)
endif

# configure vars
_nginx_debug_cpuflags = -g -O0
_nginx_release_cpuflags := -Ofast -g0 -mtune=native -march=native -m64 -fomit-frame-pointer -fno-exceptions -fno-strict-aliasing -msse4.2 $(_nginx_opt_flags)

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
BUILDROOT ?= $(PWD)/build/nginx-$(CURRENT)/

# flags for mac os x
ifeq ($(OSNAME),Darwin)
	CC := clang
	PAGESPEED = 0
	ifeq ($(DEBUG),0)
		_nginx_gccflags += -mssse3
	endif
	_openssl_config := no-shared no-threads no-krb5 zlib no-md2 no-jpake no-gmp no-ssl-trace
else
	CC := gcc-4.8-sandbox
	EXTRA_FLAGS += --with-file-aio
	ifeq ($(DEBUG),1)
		_nginx_gccflags += -fno-stack-protector
	else
		_nginx_gccflags += -w
	endif
	_openssl_config := enable-rc5 enable-rfc3779 enable-ec_nistp_64_gcc_128 no-shared no-threads no-krb5 zlib no-md2 no-jpake no-gmp no-ssl-trace
endif

# do we compile-in openssl?
ifeq ($(OPENSSL),1)
	EXTRA_FLAGS += --with-http_ssl_module --with-http_spdy_module
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
	EXTRA_FLAGS += --with-pcre=pcre-$(PCRE_VERSION) --with-pcre-jit --with-pcre-opt="$(_nginx_gccflags)"
endif

# do we compile-in our version of Zlib?
ifeq ($(ZLIB),1)
	EXTRA_FLAGS += --with-zlib=zlib-$(ZLIB_VERSION) --with-zlib-opt="$(_nginx_gccflags)"
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

_nginx_config_extras :=
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

package: strip_nginx
	@echo "Packaging build..."
	#@mv pagespeed/ nginx-$(CURRENT)/pagespeed

	@echo "Packaging tarball...";
	@mv build/nginx-$(CURRENT) build/keenginx-$(STAMP);
	@cd build/; \
		tar -czvf ./keenginx-$(TARSTAMP).tar.gz keenginx-$(STAMP)
	#@mv nginx-$(CURRENT)/pagespeed ./pagespeed
	@mv build/keenginx-$(STAMP) build/nginx-$(CURRENT);
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
	@echo "Wait 5..."
	@echo ""
	@sleep 5

	@echo ""
	@echo "!!!!! Building production Keenginx WITHOUT pagespeed. !!!!!"
	$(MAKE) -j $(JOBS) PAGESPEED=0 OPENSSL=$(OPENSSL) ZLIB=$(ZLIB) PCRE=$(PCRE) STATIC=$(STATIC) LTO=$(LTO) DEBUG=0 package
	@echo ""

	@echo ""
	@echo "!!!!! Building debug Keenginx WITHOUT pagespeed. !!!!!"
	$(MAKE) -j $(JOBS) PAGESPEED=0 OPENSSL=$(OPENSSL) ZLIB=$(ZLIB) PCRE=$(PCRE) STATIC=0 LTO=0 DEBUG=1 package
	@echo ""

	@echo ""
	@echo "!!!!! Building production Keenginx WITH pagespeed. !!!!!"
	$(MAKE) -j $(JOBS) PAGESPEED=1 OPENSSL=$(OPENSSL) ZLIB=$(ZLIB) STATIC=0 LTO=0 DEBUG=0 modules/pagespeed package
	@echo ""

	@echo ""
	@echo "!!!!! Building debug Keenginx WITH pagespeed. !!!!!"
	$(MAKE) PAGESPEED=1 OPENSSL=$(OPENSSL) ZLIB=$(ZLIB) STATIC=0 LTO=0 DEBUG=1 package
	@echo ""
	@echo ""
	@echo "!!!!!!!!!! DONE :) !!!!!!!!!!"

build: patch
	@echo "Compiling Nginx $(CURRENT)..."
	@echo "Copying custom sources..."
	@cp -fr workspace/* sources/$(CURRENT)/nginx-$(CURRENT)/
	$(MAKE) configure_nginx;
	$(MAKE) build_nginx;
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
		$(MAKE) -f misc/GNUmakefile release; \
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

sources: dependencies workspace
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
	cat $^ > patches/common.patch
	-patch -N -p0 < patches/common.patch
	@echo "Patch done."

patch_$(CURRENT): $(_current_patches)
	@echo "Applying patch " $^ "..."
	cat $^ > patches/current.patch
	-patch -N -p0 < patches/current.patch
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
		$(MAKE) -f misc/GNUmakefile release; \
		cp -fr ./tmp/nginx-$(trunk) ../; \
		cd ..;

endif


#### ==== NGINX DEPENDENCIES ==== ####
dependencies/zlib:
	@echo "Fetching Zlib..."
	@mkdir -p dependencies/zlib/$(ZLIB_VERSION)
	@curl --progress-bar http://commondatastorage.googleapis.com/keen-static/dependencies/zlib/zlib-$(ZLIB_VERSION).tar.gz > zlib-$(ZLIB_VERSION).tar.gz

	@echo "Extracting Zlib..."
	@tar -xvf zlib-$(ZLIB_VERSION).tar.gz
	@mv zlib-$(ZLIB_VERSION)/ zlib-$(ZLIB_VERSION).tar.gz dependencies/zlib/$(ZLIB_VERSION)/
	@ln -s $(ZLIB_VERSION)/zlib-$(ZLIB_VERSION) dependencies/zlib/latest

	@echo "Preparing Zlib ASM..."
	@mkdir -p $(BUILDROOT)zlib-$(ZLIB_VERSION)
	@cd dependencies/zlib/latest; cp contrib/amd64/amd64-match.S match.S; \
		CFLAGS="$(_nginx_gccflags) -DASMV" ./configure; \
		cp -Lp *.h $(BUILDROOT)zlib-$(ZLIB_VERSION)/; \
		$(MAKE) -j $(JOBS) OBJA=match.o libz.a; \
		cp -Lp *.a $(BUILDROOT)zlib-$(ZLIB_VERSION)/;

dependencies/pcre:
	@echo "Fetching PCRE..."
	@mkdir -p dependencies/pcre/$(PCRE_VERSION)
	@curl --progress-bar ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-$(PCRE_VERSION).tar.gz > pcre-$(PCRE_VERSION).tar.gz

	@echo "Extracting PCRE..."
	@tar -xvf pcre-$(PCRE_VERSION).tar.gz
	@mv pcre-$(PCRE_VERSION)/ pcre-$(PCRE_VERSION).tar.gz dependencies/pcre/$(PCRE_VERSION)/
	@ln -s $(PCRE_VERSION)/pcre-$(PCRE_VERSION) dependencies/pcre/latest

	@echo "Preparing PCRE..."
	@mkdir -p $(BUILDROOT)pcre-$(PCRE_VERSION);
	@-cd dependencies/pcre/latest; CFLAGS="$(_nginx_gccflags)" ./configure \
		--disable-option-checking --disable-dependency-tracking \
		--enable-shared=no --enable-static=yes --enable-jit --enable-utf \
		--enable-unicode-properties --enable-newline-is-any --disable-valgrind \
		--disable-coverage CFLAGS="$(_nginx_gccflags)" CXXFLAGS="$(_nginx_gccflags)"; \
		cp -Lp *.h $(BUILDROOT)pcre-$(PCRE_VERSION)/; \
		$(MAKE) -j $(JOBS) libpcre.la; \
		cp -Lp .libs/* $(BUILDROOT)pcre-$(PCRE_VERSION)/; \
		cd $(BUILDROOT)pcre-$(PCRE_VERSION)/; \
		ln -s . .libs;


ifeq ($(OPENSSL),1)
ifeq ($(OPENSSL_TRUNK),0)
_nginx_config_extras += --with-openssl=dependencies/openssl/$(OPENSSL_VERSION)/openssl-$(OPENSSL_VERSION)
dependencies/openssl:
	@echo "Fetching OpenSSL..."
	@mkdir -p dependencies/openssl/$(OPENSSL_VERSION)
	@curl --progress-bar http://www.openssl.org/source/openssl-$(OPENSSL_VERSION).tar.gz > openssl-$(OPENSSL_VERSION).tar.gz

	@echo "Extracting OpenSSL..."
	@tar -xvf openssl-$(OPENSSL_VERSION).tar.gz
	@mv openssl-$(OPENSSL_VERSION)/ openssl-$(OPENSSL_VERSION).tar.gz dependencies/openssl/$(OPENSSL_VERSION)/
	@ln -s $(OPENSSL_VERSION)/openssl-$(OPENSSL_VERSION) dependencies/openssl/latest
	@mkdir -p $(BUILDROOT)openssl-$(OPENSSL_VERSION);
else
_nginx_config_extras += --with-openssl=openssl-$(OPENSSL_SNAPSHOT)
dependencies/openssl:
	@echo "Fetching OpenSSL from snapshot..."
	@mkdir -p dependencies/openssl/$(OPENSSL_SNAPSHOT)
	@curl --progress-bar ftp://ftp.openssl.org/snapshot/openssl-$(OPENSSL_SNAPSHOT).tar.gz > openssl-$(OPENSSL_SNAPSHOT).tar.gz

	@echo "Extracting OpenSSL..."
	@tar -xvf openssl-$(OPENSSL_SNAPSHOT).tar.gz
	@mv openssl-$(OPENSSL_SNAPSHOT)/ openssl-$(OPENSSL_SNAPSHOT).tar.gz dependencies/openssl/$(OPENSSL_SNAPSHOT)/
	@ln -s $(OPENSSL_SNAPSHOT)/openssl-$(OPENSSL_SNAPSHOT) dependencies/openssl/latest

	#sed -i Makefile -re "s#^CFLAG.*\$#CFLAG=${_cflags}#";

	@echo "Preparing OpenSSL..."
	@mkdir -p $(BUILDROOT)openssl-$(OPENSSL_SNAPSHOT)/openssl;
	cd dependencies/openssl/latest; \
		./config $(_openssl_config) $(_nginx_gccflags); \
		_cflags="$(egrep -e ^CFLAG Makefile | cut -d ' ' -f 2- | xargs -n 1 | egrep -e ^-D -e ^-W | xargs) $(_nginx_gccflags)" \
		$(MAKE) -j $(JOBS) depend; \
		$(MAKE) -j $(JOBS) build_libs; \
		$(MAKE) -j $(JOBS); \
		cp -Lp *.a $(BUILDROOT)openssl-$(OPENSSL_SNAPSHOT)/; \
		cd $(BUILDROOT)openssl-$(OPENSSL_SNAPSHOT)/ ; \
		ln -s . .openssl; \
		ln -s . include; \
		ln -s . lib;
	@echo "Copying OpenSSL headers...";
	@cp -Lp dependencies/openssl/latest/include/openssl/*.h $(BUILDROOT)openssl-$(OPENSSL_SNAPSHOT)/openssl/;
	@rm -fr $(BUILDROOT)openssl-$(OPENSSL_SNAPSHOT)/openssl
endif
endif

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
		$(MAKE) AR.host="$(PROJECT)/sources/pagespeed/$(PAGESPEED_VERSION)/trunk/src/build/wrappers/ar.sh" \
	         AR.target="$(PROJECT)/sources/pagespeed/$(PAGESPEED_VERSION)/trunk/src/build/wrappers/ar.sh" \
		     BUILDTYPE=$(PAGESPEED_RELEASE) \
	         mod_pagespeed_test pagespeed_automatic_test;

	@echo "Building PSOL sources..."
	-cd ./sources/pagespeed/$(PAGESPEED_VERSION)/trunk/src/net/instaweb/automatic; \
		$(MAKE) AR.host="$(PROJECT)/sources/pagespeed/$(PAGESPEED_VERSION)/trunk/src/build/wrappers/ar.sh" \
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
		../../../../dependencies/depot_tools/gclient sync --force --jobs=8;
		cd ../../../../;


endif


#### ==== BUILD RULES ==== ####
ifeq ($(STATIC),1)
ifeq ($(LTO),1)
nginx_makefile: configure_nginx
	@echo "Rewriting Makefile for an LTO-enabled static binary..."
	@cp scripts/rewrite.sh $(BUILDROOT);
	@chmod +x $(BUILDROOT)rewrite.sh;
	cd $(BUILDROOT); \
		link_order="`fgrep -e -lcrypt objs/Makefile | xargs -n 1 -r | egrep -v -e ^- | xargs` -static -flto=4 -fuse-linker-plugin -save-temps -flto-report -lm -lrt -lpthread -ldl -lcrypt" \
		bash ./rewrite.sh;
	@echo "Makefile ready for LTO-enabled static binary."
else
nginx_makefile: configure_nginx
	@echo "Rewriting Makefile for static binary..."
	@cp scripts/rewrite.sh $(BUILDROOT);
	@chmod +x $(BUILDROOT)rewrite.sh;
	cd $(BUILDROOT); \
		link_order="`fgrep -e -lcrypt objs/Makefile | xargs -n 1 -r | egrep -v -e ^- | xargs` -lm -lrt -lpthread -ldl -lcrypt -static" \
		bash ./rewrite.sh;
	@echo "Makefile ready for static binary."
endif
else
nginx_makefile: configure_nginx
	@echo "Rewriting Makefile for dynamic binary..."
	@cp scripts/rewrite.sh $(BUILDROOT);
	cd $(BUILDROOT); \
		link_order="`fgrep -e -lcrypt objs/Makefile | xargs -n 1 -r | egrep -v -e ^- | xargs` -lm -lrt -lpthread -ldl -lcrypt" \
		bash ./rewrite.sh;
	@echo "Makefile ready for dynamic binary.";
endif

build_nginx: nginx_makefile
	@echo "Compiling Nginx..."
	@mkdir -p build/ dist/
	cd $(BUILDROOT); \
		CC=$(CC) CFLAGS="$(_nginx_gccflags)" CXXFLAGS="$(CXXFLAGS)" $(NGINX_ENV) $(MAKE) CC=$(CC) CFLAGS="$(_nginx_gccflags)" CXXFLAGS="$(CXXFLAGS)";

	@echo "Patching Makefile..."
	sed -i $(BUILDROOT)objs/Makefile -re "s/install:.*/install:/"


clean_nginx:
	@echo "Cleaning Nginx..."
	@-$(MAKE) -f sources/$(CURRENT)/nginx-$(CURRENT)/Makefile clean;

	@echo "Cleaning modules..."
	@-rm -fr modules/

$(BUILDROOT)configure:
	@echo "Copying Nginx sources..."
	@cp -fr workspace/* $(BUILDROOT)

configure_nginx: workspace dependencies sources patch $(BUILDROOT)configure
	@echo "Configuring Nginx..."
	-cp -fr modules dependencies sources/$(CURRENT)/nginx-$(CURRENT); \
		cd $(BUILDROOT); \
		CC=$(CC) CFLAGS="$(_nginx_gccflags)" CXXFLAGS="$(CXXFLAGS)" $(BUILDROOT)configure $(_nginx_config_extras) $(_nginx_config_mainflags) --with-cc-opt="$(_nginx_gccflags)" --with-ld-opt="$(LDFLAGS)" --with-openssl-opt="$(_openssl_flags)";
	@echo "Stamping configuration..."
	@echo "CC=gcc CFLAGS=\"$(_nginx_gccflags)\" CXXFLAGS=\"$(CXXFLAGS)\" LDFLAGS=\"$(LDFLAGS)\" ./configure --with-cc-opt=\"$(_nginx_gccflags)\" --with-ld-opt="$(LDFLAGS)" --with-openssl-opt=\"$(_openssl_flags)\" $(_nginx_config_extras) $(_nginx_config_mainflags)" > $(BUILDROOT).build_cmd
	@echo "CC=gcc CFLAGS=\"$(_nginx_gccflags)\" CXXFLAGS=\"$(CXXFLAGS)\" LDFLAGS=\"$(LDFLAGS)\" $(NGINX_ENV) make ;" > $(BUILDROOT).make_cmd
	@cp -f $(BUILDROOT).build_cmd $(BUILDROOT).make_cmd workspace/

patch_nginx_install:
	@echo "Patching Nginx install routine..."

	@echo "Adding debug-only and original binaries..."
	@cat scripts/Makefile.append >> $(BUILDROOT)objs/Makefile

strip_nginx: build_nginx patch_nginx_install
	@echo "Performing binary post-processing..."

	@echo "Backing up original Nginx binary..."
	@cp -f $(BUILDROOT)objs/nginx $(BUILDROOT)objs/nginx.orig

	@echo "Copying debug symbols into dedicated binary..."
	@objcopy --only-keep-debug $(BUILDROOT)objs/nginx $(BUILDROOT)objs/nginx.dbg

	@echo "Stripping debug symbols from production binary..."
	@strip --strip-debug --strip-unneeded $(BUILDROOT)objs/nginx

	@echo "Restoring executable permissions..."
	@chmod a-x $(BUILDROOT)objs/nginx*

	@echo "Cleaning up..."
	@-rm -f $(BUILDROOT)objs/nginx.8;

	@echo "Generated final binary layout:"
	@file $(BUILDROOT)objs/ngin*
	@ls -la $(BUILDROOT)objs/ | grep nginx
	@sleep 10

install_nginx: strip_nginx
	@echo "Installing Nginx..."
	-cd $(BUILDROOT); \
		$(MAKE) install; \
		cd ../../../;
