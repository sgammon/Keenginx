#!/bin/bash

src=./
bld=./build

jobs_mul=${jobs_mul:-1}
jobs=$(egrep -c -e ^processor /proc/cpuinfo 2>/dev/null)
test -z "${jobs}" && jobs=1
let jobs*=jobs_mul

zlib=1.2.7
pcre=8.32
nginx=1.5.11
openssl=1.0.2-stable-SNAP-20140220

env_ansi() {
        export LC_ALL=C LANG=C
        return 0
}

env_build() {
        export CC=gcc
        export LD=ld.gold

        test -n "${RENEW}" && unset CPPFLAGS CFLAGS CXXFLAGS LDFLAGS MAKEFLAGS

        export CPPFLAGS

        test -n "${CPPFLAGS}" && CFLAGS=${CFLAGS:-''}${CFLAGS+' '}${CPPFLAGS}
        test -n "${VERBOSE}" && CFLAGS=${CFLAGS:-''}${CFLAGS+' '}'-v'
        CFLAGS=${CFLAGS:-''}${CFLAGS+' '}'-march=native -mtune=native -m64'
        CFLAGS=${CFLAGS:-''}${CFLAGS+' '}'-Ofast -g0 -msse4.2'
        CFLAGS=${CFLAGS:-''}${CFLAGS+' '}'-Wall -fomit-frame-pointer -fno-exceptions -fno-strict-aliasing'
        if test -n "${LTO}" ; then
                CFLAGS=${CFLAGS:-''}${CFLAGS+' '}'-flto -save-temps'
        else
                CFLAGS=${CFLAGS:-''}${CFLAGS+' '}'-pipe'
        fi
        export CFLAGS

        test -n "${CFLAGS}" && CXXFLAGS=${CXXFLAGS:-''}${CXXFLAGS+' '}${CFLAGS}
        CXXFLAGS=${CXXFLAGS:-''}${CXXFLAGS+' '}'-felide-constructors -fno-implicit-templates'
        export CXXFLAGS

        test -n "${STATIC}" && LDFLAGS=${LDFLAGS:-''}${LDFLAGS+' '}'-static'
        # ld.gold specific
        test -n "${LTO}" && CFLAGS=${CFLAGS:-''}${CFLAGS+' '}'-static-libgcc'
        export LDFLAGS

        # gcc specific
        export TMPDIR=./build
}

version() {
        eval echo -n "\$$1" 2>/dev/null || echo trunk
}

fullname() {
        echo $1-$(version $1)
}

path_src() {
        echo dependencies/$(fullname $1).tar.xz
}

path_build() {
        echo ${bld}/$(fullname $1)
}

path_prefix() {
        echo ${bld}/pfx-$(fullname $1)
}

unpack() {
        a=$(path_src $1)
        test -n "$a" || return 1
        test -f "$a" || return 2
        b=$(path_build $1)
        rm -rf "$b" || return 3
        cd ${bld} || return 4
        tar xf "$a" || return 5
}

goto() {
        cd $(path_build $1) || return 2
}

pfx=$1 ; shift
targets="$*"

test -z "${pfx}" && pfx=$(path_prefix ${this})
