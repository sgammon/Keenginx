#!/bin/bash
gawk '/^(openssl|pcre|zlib)/ {$0=$1;gsub("^(.*:).*$","& objs/Makefile")} /^(openssl|pcre|zlib).+:/,/^$/ { if ($0 ~ "^[[:space:]]") $0="";}; {print}' <objs/Makefile >objs/Makefile.new;
mv -f objs/Makefile objs/Makefile.old;
mv -f objs/Makefile.new objs/Makefile;
sed -i objs/Makefile -re "/^\t.*$s-lcrypt$s.*\$/ {s##\t${link_order}#}";
echo "!!! Using link order: $link_order";
sleep 5
