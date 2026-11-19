#!/usr/bin/env bash
. "$(dirname "$0")/common.sh"

v="${VERSION:-latest}"
case "$ARCH" in amd64) a=x86_64;; *) a="$ARCH";; esac
f="govc_Linux_${a}.tar.gz"
if [ "$v" = latest ]; then base="https://github.com/vmware/govmomi/releases/latest/download"
else base="https://github.com/vmware/govmomi/releases/download/v${v#v}"; fi
fetch "$base/$f" "/tmp/$f" "$(sha_from "$base/checksums.txt" "$f")"
tar -C /usr/local/bin -xzf "/tmp/$f" govc && rm "/tmp/$f"
govc version
