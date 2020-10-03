#!/bin/sh

if [ -z "$ZSH_VERSION" ]; then
    # in ash
    apk add -q --no-cache grep wget tar coreutils zsh
    SCRIPT_PATH=$(realpath $0)
    exec /bin/zsh "$SCRIPT_PATH"
fi

set -e

DST="/srv/lists"
TMP="/tmp/lists"
LIST_ADS="deny-10-ads"
LIST_FILES="deny-20-files"
LIST_ADULT="deny-30-adult"
LIST_PROXY="deny-40-proxy"
LIST_SPY="deny-50-spy"
LIST_ENTERT="deny-60-entert"

mkdir -p $TMP
mkdir -p $DST
truncate -s 0 $TMP/{$LIST_ADS,$LIST_FILES,$LIST_ADULT,$LIST_PROXY,$LIST_SPY,$LIST_ENTERT}


#
# Shalla's Blacklists
# Homepage: http://www.shallalist.de
#
echo "Handling Source1..."
SOURCE1_URL="http://www.shallalist.de/Downloads/shallalist.tar.gz"
SOURCE1_TMP="/tmp/source1"
mkdir -p "$SOURCE1_TMP"
echo "- Downloading..."
wget -qO- --show-progress "$SOURCE1_URL" | tar -xzf- -C "$SOURCE1_TMP" --strip-components=1

echo "- Making lists..."
cat $SOURCE1_TMP/{adv,tracker}/domains \
    >> "$TMP/$LIST_ADS"

cat $SOURCE1_TMP/{downloads,imagehosting,movies,music,warez,webradio,webtv}/domains \
    >> "$TMP/$LIST_FILES"

cat $SOURCE1_TMP/{aggressive,alcohol,drugs,gamble,porn,sex/lingerie,weapons}/domains \
    >> "$TMP/$LIST_ADULT"

cat $SOURCE1_TMP/{anonvpn,dynamic,redirector}/domains \
    >> "$TMP/$LIST_PROXY"

cat $SOURCE1_TMP/{costtraps,spyware}/domains \
    >> "$TMP/$LIST_SPY"

cat $SOURCE1_TMP/{chat,dating,socialnet}/domains \
    >> "$TMP/$LIST_ENTERT"


#
# The Université Toulouse 1 Capitole
# Homepage: http://dsi.ut-capitole.fr/blacklists/index_en.php
#
echo "Handling Source2..."
SOURCE2_URL="http://dsi.ut-capitole.fr/blacklists/download/blacklists.tar.gz"
SOURCE2_TMP="/tmp/source2"
mkdir -p "$SOURCE2_TMP"
echo "- Downloading..."
wget -qO- --show-progress "$SOURCE2_URL" | tar -xzf- -C "$SOURCE2_TMP" --strip-components=1

echo "- Making lists..."
cat $SOURCE2_TMP/ads/domains \
    >> "$TMP/$LIST_ADS"

cat $SOURCE2_TMP/{audio-video,download,filehosting,radio,warez}/domains \
    >> "$TMP/$LIST_FILES"

cat $SOURCE2_TMP/{adult,aggressive,dangerous_material,ddos,drugs,gambling,lingerie,mixed_adult}/domains \
    >> "$TMP/$LIST_ADULT"

cat $SOURCE2_TMP/proxy/domains \
    >> "$TMP/$LIST_PROXY"

cat $SOURCE2_TMP/{malware,phishing}/domains \
    >> "$TMP/$LIST_SPY"

cat $SOURCE2_TMP/{chat,dating,social_networks}/domains \
    >> "$TMP/$LIST_ENTERT"


echo "Post processing..."
post() {
    echo "- $1"
    cat "$TMP/$1" | sort | uniq > "$DST/$1.0"
}

post "$LIST_ADS"
post "$LIST_FILES"
post "$LIST_ADULT"
post "$LIST_PROXY"
post "$LIST_SPY"
post "$LIST_ENTERT"

echo "Done!"
