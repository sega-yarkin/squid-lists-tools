#!/bin/sh

set -e

DIR="./lists"

for file in $DIR/*.3; do
    prefix=$(basename "$file" | cut -d'.' -f1)
    echo "Processing '$file'..."
    if [[ ! -f "$DIR/$prefix.4" ]]; then
        ./.bin/dnx < "$file" 3>&1 1>"/tmp/$prefix.4" 2>"/tmp/$prefix.nx"
        mv "/tmp/$prefix.4" "/tmp/$prefix.nx" "$DIR/"
    fi
done
