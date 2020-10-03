#!/bin/sh
set -e

apk add -q --no-cache grep curl sed pv

DIR="./lists"

wcl() {
    wc -l "$1" | awk '{print $1}'
}

filter_blogspots() {
    local file="$1"
    local prefix="$2"
    # Get all blogspot names
    echo " - Blogspot.com:"
    echo "   - Searching ..."
    cat "$file" \
        | grep -iP '^([\w\d-]+)\.blogspot(\.\w{2,4}){1,2}$' \
        | cut -d'.' -f1 \
        | sort | uniq > "$file.blogspots"
    cat "$file.blogspots" | sed 's|^|http://|; s|$|.blogspot.com|' > "$file.blogspots_0"
    echo "   - Filtering out ..."
    tmp=$(mktemp)
    grep -viP '\.blogspot(\.\w{2,4}){1,2}$' $file > "$tmp"
    mv "$tmp" "$file"
    # Validating names
    local CNT=$(wcl "$file.blogspots_0")
    echo "   - Checking existence ($CNT) ..."
    cat "$file.blogspots_0" | pv -lpterb -D1 -i2 -s $CNT \
        | .bin/httx 1> "$file.blogspots_1" 2> "$file.blogspots_2"
    cat "$file.blogspots_1" | cut -c8- | cut -d'.' -f1 \
        | sed 's|\-|\\-|; s|^|\^|; s|$|\\.blogspot\\.|' > "$prefix.dstdom_re.blogspots"
    local good=$(wcl "$file.blogspots_1")
    local bad=$(wcl "$file.blogspots_2")
    echo "     ex = ${good}, nx = ${bad}"
    rm -f "$file.blogspots" "$file.blogspots_0" "$file.blogspots_1" "$file.blogspots_2"
}

filter_tumblr() {
    local file="$1"
    local prefix="$2"
    echo " - Tumblr.com"
    echo "   - Searching ..."
    cat "$file" \
        | grep -iP '\.tumblr\.com$' \
        | sort | uniq > "$prefix.dstdomain.tumblrs"
    echo "   - Filtering out ..."
    tmp=$(mktemp)
    grep -viP '\.tumblr\.com$' $file > "$tmp"
    mv "$tmp" "$file"
    # NOTE: Cannot validate names due to rate limiting
}

for file in $DIR/*.1; do
    prefix=$(basename "$file" | cut -d'.' -f1)
    echo "Processing '$file'..."
    TMP="/tmp"
    file2="$TMP/$prefix.2"
    cp "$file" "$file2"
    filter_blogspots "$file2" "$TMP/$prefix"
    filter_tumblr    "$file2" "$TMP/$prefix"
    # ls -l /tmp/
    mv /tmp/* $DIR/
done
