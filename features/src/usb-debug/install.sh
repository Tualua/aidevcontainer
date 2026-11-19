#!/usr/bin/env bash
. "$(dirname "$0")/common.sh"

apt_install usbutils udev openocd gdb-multiarch stlink-tools dfu-util picocom tio minicom
apt_cleanup
usermod -aG dialout,plugdev "$REMOTE_USER"
install -m 0755 "$(dirname "$0")/aidev-device-groups" /usr/local/bin/aidev-device-groups
install -m 0755 "$(dirname "$0")/aidev-serial-sync"   /usr/local/bin/aidev-serial-sync

if [ "${PROBERS:-false}" = true ]; then
    case "$ARCH" in amd64) t=x86_64-unknown-linux-gnu;; arm64) t=aarch64-unknown-linux-gnu;; esac
    f="probe-rs-tools-${t}.tar.xz"; base="https://github.com/probe-rs/probe-rs/releases/latest/download"
    fetch "$base/$f" "/tmp/$f" "$(curl -fsSL "$base/$f.sha256" | awk '{print $1}')"
    tar -C /usr/local/bin --strip-components=1 --wildcards -xJf "/tmp/$f" '*/probe-rs' '*/cargo-flash' '*/cargo-embed'
    rm "/tmp/$f"
fi

if command -v uv >/dev/null; then
    [ "${PYOCD:-false}"   = true ] && run_as_user "uv tool install pyocd"
    [ "${ESPTOOL:-false}" = true ] && run_as_user "uv tool install esptool"
fi
true
