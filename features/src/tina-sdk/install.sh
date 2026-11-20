#!/usr/bin/env bash
. "$(dirname "$0")/common.sh"

# python2 есть только до Ubuntu 22.04 включительно; Tina (build/prereq-build.mk) требует `python` = 2.x
. /etc/os-release
case "${ID}:${VERSION_ID}" in
    ubuntu:18.04|ubuntu:20.04|ubuntu:22.04) ;;
    *) echo "tina-sdk: нужен Ubuntu ≤ 22.04 (python2), а здесь ${PRETTY_NAME}. Используйте образ ghcr.io/tualua/aidev:jammy" >&2
       exit 1 ;;
esac

# Утилиты упаковки прошивки (tools/pack-bintools: dragon, fsbuild, update_23…) — 32-битные
dpkg --add-architecture i386
apt-get update
apt_install \
    python2 busybox \
    libc6:i386 lib32z1 lib32stdc++6 \
    build-essential gawk flex bison m4 autoconf automake libtool gettext texinfo \
    libncurses-dev zlib1g-dev libssl-dev libxml-parser-perl \
    quilt xsltproc subversion unzip wget file bc rsync cpio bzip2 \
    u-boot-tools device-tree-compiler ccache
# Именно `python`: его проверяет prereq SDK. python3 и uv не затрагиваются.
ln -sf /usr/bin/python2 /usr/local/bin/python

[ "${ADB:-true}" = true ] && apt_install adb

if [ "${XFEL:-true}" = true ]; then
    apt_install libusb-1.0-0-dev pkg-config git
    tag="${XFELVERSION:-latest}"
    [ "$tag" = latest ] && tag="$(gh_latest_tag xboot/xfel)"
    git clone -q --depth 1 -b "$tag" https://github.com/xboot/xfel.git /tmp/xfel
    make -C /tmp/xfel -j"$(nproc)" >/dev/null
    install -m 0755 /tmp/xfel/xfel /usr/local/bin/xfel
    rm -rf /tmp/xfel
fi
apt_cleanup

# udev-правило для ХОСТА (в контейнере udev не действует): FEL-режим и USB-гаджеты Allwinner
install -d /usr/share/aidev/udev
cat > /usr/share/aidev/udev/60-allwinner.rules <<'RULES'
# Allwinner: FEL-режим (1f3a:efe8) и USB-гаджеты прошивок Tina (adb, rndis).
# Скопировать на ХОСТ: sudo cp 60-allwinner.rules /etc/udev/rules.d/ && sudo udevadm control --reload
SUBSYSTEM=="usb", ATTR{idVendor}=="1f3a", MODE="0660", GROUP="plugdev", TAG+="uaccess"
RULES
usermod -aG plugdev "$REMOTE_USER"
true
