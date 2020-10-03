#!/bin/sh
set -e

apk add -q --no-cache tar

DIR="./lists"

for file in $DIR/*.4; do
    prefix=$(basename "$file" | cut -d'.' -f1)
    echo "Processing '$prefix'..."
    cat "$file" $DIR/${prefix}.dstdomain.* | sort > "/tmp/${prefix}.dstdomain"
    cat $DIR/${prefix}.dstdom_re.* | sort > "/tmp/${prefix}.dstdom_re"
done

stamp=$(date '+%Y%m%d%H%M')
dst_file="/srv/squid_lists.${stamp}.tar.gz"
cd /tmp
tar -czf "$dst_file" *
