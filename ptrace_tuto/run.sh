#!/bin/sh

if [ -z $1 ]
then
	echo 'give me file name'
	exit 1;
fi
cat $1 | iconv -f utf8 -t koi8-r| preconv -e koi8-r | groff -Tps -mru -mms > some.ps
