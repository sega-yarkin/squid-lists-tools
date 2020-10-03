#!/bin/sh
set -e

DIR="./lists"

for file in $DIR/*.0; do
    prefix=$(basename "$file" | cut -d'.' -f1)
    echo "Processing '$file'..."
    ./.bin/filter-ip < "$file" > "/tmp/$prefix.1" 2> "/tmp/$prefix.ips"
    mv "/tmp/$prefix.1" "/tmp/$prefix.ips" "$DIR/"
done
