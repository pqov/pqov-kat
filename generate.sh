#!/bin/sh
# Regenerate the KAT files from a pinned pqov and verify them against pqov's
# published SHA256SUMS. Writes KAT/<config>/PQCsignKAT_*.rsp.xz.
set -e

PQOV_URL=https://github.com/pqov/pqov.git
PQOV_COMMIT=49dc53c09717763759911c47c7e4c8000fda1cc5

# config name -> "VARIANT:PARAM". VARIANT 1=classic, 2=pkc, 3=pkc+skc.
# PARAM 1=Is, 3=Ip (both NIST level 1); 4=III and 5=V also work.
CONFIGS="Is:1:1 Is-pkc:2:1 Is-pkc-skc:3:1 Ip:1:3 Ip-pkc:2:3 Ip-pkc-skc:3:3"

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

git clone -q "$PQOV_URL" "$WORK/pqov"
git -C "$WORK/pqov" checkout -q "$PQOV_COMMIT"

: > "$HERE/SHA256SUMS"
for c in $CONFIGS; do
    name=${c%%:*}; rest=${c#*:}; variant=${rest%%:*}; param=${rest##*:}

    ( cd "$WORK/pqov" && make clean >/dev/null 2>&1 || true )
    ( cd "$WORK/pqov" && make VARIANT="$variant" PARAM="$param" KAT=1 PQCgenKAT_sign >/dev/null )
    ( cd "$WORK/pqov" && ./PQCgenKAT_sign >/dev/null )

    rsp=$(ls "$WORK/pqov"/PQCsignKAT_*.rsp)
    got=$(sha256sum "$rsp" | awk '{print $1}')
    want=$(awk -v n="KAT/$name" '$4 == n {print $1}' "$WORK/pqov/SHA256SUMS")
    [ -n "$want" ] || { echo "no published sum for KAT/$name"; exit 1; }
    [ "$got" = "$want" ] || { echo "$name: sha256 mismatch"; echo "  got  $got"; echo "  want $want"; exit 1; }
    echo "$name: verified against pqov SHA256SUMS"

    mkdir -p "$HERE/KAT/$name"
    xz -9 -c "$rsp" > "$HERE/KAT/$name/$(basename "$rsp").xz"
    echo "$got  KAT/$name/$(basename "$rsp")" >> "$HERE/SHA256SUMS"
    ( cd "$WORK/pqov" && rm -f PQCsignKAT_* )
done
echo "done; sums of the uncompressed .rsp are in SHA256SUMS"
