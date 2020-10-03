#!/bin/sh
set -e
apk add -q --no-cache grep

DIR="./lists"

for file in $DIR/*.2; do
    prefix=$(basename "$file" | cut -d'.' -f1)
    echo "Handling '$file'..."
    cat "$file" | \
        # These ones we could definitely block without any problems for our users
        grep -viP '\.free\.fr$|\.centerblog\.net$|\.startspot\.nl$|\.canalblog.\com$' | \
        grep -viP '\.over\-blog\.com$|\.ddns\.net$|\.co\.kr$|\.com\.ar$|\.com\.br$' | \
        # These ones do moderation
        grep -viP '\.da\.ru$|\.000webhostapp\.com$' | \
        # These ones don't exist
        grep -viP '\.cjb\.net$|\.de\.vu$' \
        > "/tmp/$prefix.3"
done
mv /tmp/*.3 "$DIR/"

cat > "$DIR/deny.dstdomain.known" << EOF
.free.fr
.centerblog.net
.startspot.nl
.canalblog.com
.over-blog.com
.ddns.net
.co.kr
.com.ar
.com.br
EOF
