#!/bin/bash
gawk '/^(openssl|pcre|zlib)/ {$0=$1;gsub("^(.*:).*$","& objs/Makefile")} /^(openssl|pcre|zlib).+:/,/^$/ { if ($0 ~ "^[[:space:]]") $0="";}; {print}' <objs/Makefile.old >objs/Makefile;
