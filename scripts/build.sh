#!/bin/bash
# this is ~/bin/krd_build_nginx
this=nginx
jobs_mul=4

. ./env.sh

# do a barrel rool!
env_ansi

t=$(path_build $this)
t_zlib=$(fullname zlib)
t_pcre=$(fullname pcre)
t_ssl=$(fullname openssl)

do_zlib() {
        z=$t/${t_zlib}
        unpack zlib
        goto zlib
        mkdir -p $z
        cp contrib/amd64/amd64-match.S match.S
        CFLAGS="${CFLAGS} -DASMV" ./configure
        cp -Lp *.h $z/
        make -j ${jobs} OBJA=match.o libz.a
        cp -Lp *.a $z/
        rm -rf $(path_build zlib)
}

do_pcre() {
        z=$t/${t_pcre}
        unpack pcre
        goto pcre
        mkdir -p $z
#               --enable-newline-is-anycrlf \
#               --with-match-limit=1048576 \
#               --with-match-limit-recursion=1048576 \
#               --enable-pcre16 \
#               --enable-pcre32 \
        ./configure \
                --disable-option-checking \
                --disable-dependency-tracking \
                --enable-shared=no \
                --enable-static=yes \
                --enable-jit \
                --enable-utf \
                --enable-unicode-properties \
                --enable-newline-is-any \
                --disable-valgrind \
                --disable-coverage \
                CFLAGS="${CFLAGS}" CXXFLAGS="${CXXFLAGS}"
        cp -Lp *.h $z/
#       make -j ${jobs} libpcre.la libpcre16.la libpcre32.la
        make -j ${jobs} libpcre.la
        cd .libs
        cp -Lp * $z/
        cd $z/
        ln -s . .libs
        rm -rf $(path_build pcre)
}

do_openssl() {
        z=$t/${t_ssl}
        unpack openssl
        goto openssl
        mkdir -p $z
        make clean
        ./config enable-rfc3779 no-shared no-threads
#       cp -LpR crypto ${t_ssl}/
        cp -LpR include/openssl $z/
        cflags=$(egrep -e ^CFLAG Makefile | cut -d ' ' -f 2- | xargs -n 1 | egrep -e ^-D -e ^-W | xargs)
        cflags="${cflags} ${CFLAGS}"
        sed -i Makefile -re "s#^CFLAG.*\$#CFLAG=${cflags}#"
        make -j ${jobs} depend
        make -j ${jobs} build_libs
        cp -Lp *.a $z/
        cd $z/
        ln -s . .openssl
        ln -s . include
        ln -s . lib
        rm -rf $(path_build openssl)
}

do_nginx() {
        goto nginx
        log=${pfx}/log
        run=${pfx}/run
#               --sbin-path=${pfx}/sbin/nginx \
#               --conf-path=${pfx}/conf/nginx.conf \
        ./configure \
                --with-zlib=${t_zlib} \
                --with-pcre=${t_pcre} \
                --with-openssl=${t_ssl} \
                --prefix=${pfx} \
                --with-file-aio \
                --with-http_ssl_module \
                --with-http_realip_module \
                --with-http_gzip_static_module \
                --with-http_secure_link_module \
                --with-http_degradation_module \
                --with-http_stub_status_module \
                --without-http_uwsgi_module \
                --without-http_scgi_module \
                --without-http_memcached_module \
                --without-mail_pop3_module \
                --without-mail_imap_module \
                --without-mail_smtp_module \
                --error-log-path=${log}/error.log \
                --http-log-path=${log}/http.log \
                --pid-path=${run}/nginx.pid \
                --lock-path=${run}/nginx.lock \
                --http-client-body-temp-path=${run}/client \
                --http-proxy-temp-path=${run}/proxy \
                --http-fastcgi-temp-path=${run}/fastcgi \
                --http-uwsgi-temp-path=${run}/uwsgi \
                --http-scgi-temp-path=${run}/scgi \
                --with-cc-opt="${CFLAGS}" \
                --with-ld-opt="${LDFLAGS}" \

        mv -f objs/Makefile objs/Makefile.old

        # this `awk' may be used too, but we'll build under nginx source root
#       gawk -re '/^\// {$0=$1;gsub("^(.*:).*$","& objs/Makefile")} /^\/.+:/,/^$/ { if ($0 ~ "^/") ; else $0="";}; {print}' <objs/Makefile.old >objs/Makefile

        gawk '/^(openssl|pcre|zlib)/ {$0=$1;gsub("^(.*:).*$","& objs/Makefile")} /^(openssl|pcre|zlib).+:/,/^$/ { if ($0 ~ "^[[:space:]]") $0="";}; {print}' <objs/Makefile.old >objs/Makefile

        if test -n "${STATIC}"; then
                # linking order is VERY IMPORTANT
                # (i've understood this fact after ~20 hours of linking)
                link_order=$(fgrep -e -lcrypt objs/Makefile | xargs -n 1 -r | egrep -v -e ^- | xargs)
                link_order="${link_order} -static -lm -lrt -lpthread -ldl -lcrypt"
                s='[[:space:]]'
                sed -i objs/Makefile -re "/^\t.*$s-lcrypt$s.*\$/ {s##\t${link_order}#}"
        fi

        make -j ${jobs} ${targets}
}

# uncomment to produce statically linked binary
STATIC=1

# renew environment (CPPFLAGS,CFLAGS,CXXFLAGS,LDFLAGS)
RENEW=1

# enable link-time optimization
# http://gcc.gnu.org/wiki/LinkTimeOptimization
LTO=1

env_build

unpack nginx
do_zlib
do_pcre
do_openssl
do_nginx
