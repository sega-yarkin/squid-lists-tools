#!/bin/sh
set -e

echo "Getting deps..."
apk add --no-cache --quiet git
go get github.com/miekg/dns

for app in $*; do
    echo "Building $app..."
	cd $app
    go build
	mv ./$app ../.bin/
    cd ..
done
