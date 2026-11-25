#!/usr/bin/env bash
. "$(dirname "$0")/common.sh"

# buildroot 2023.08 из SDK не собирается GCC 15 (Ubuntu 26.04): старый gnulib в host-m4 и др.
# ломается на C23 («expected identifier or '(' before 'int'» в gl_oset.h). На 22.04 (GCC 11) — собирается.
. /etc/os-release
case "${ID}:${VERSION_ID}" in
    ubuntu:22.04) ;;
    *) echo "ingenic-sdk: нужен Ubuntu 22.04 (buildroot 2023.08 не собирается новым GCC), а здесь ${PRETTY_NAME}. Используйте образ ghcr.io/tualua/aidev:jammy" >&2
       exit 1 ;;
esac

# Набор проверен полной сборкой Ingenic Linux SDK X2600 v5.0 (x2600halley7.v10_nand_5.10-eng):
# buildroot 2023.08 (support/dependencies: cpio, bc), ядро 5.10 (flex/bison, openssl для
# extract-cert, mkimage для uImage), u-boot.
apt_install \
    build-essential make gcc g++ perl patch file \
    cpio bc rsync unzip wget bzip2 xz-utils git \
    flex bison libssl-dev libncurses-dev \
    u-boot-tools \
    python3 python-is-python3
[ "${ADB:-true}" = true ] && apt_install adb
apt_cleanup

# Build-система SDK зовёт именно `python` (build/core/tools/findleaves.py — поиск Build.mk,
# u-boot/make_spl/copy_spl.py). Без него `make` «успешно» завершается, но без ядра и u-boot.
python --version 2>&1 | grep -q '^Python 3\.' || { echo "ingenic-sdk: python не указывает на Python 3" >&2; exit 1; }

# udev-правило для ХОСТА (в контейнере udev не действует): USB-boot Ingenic (cloner).
install -d /usr/share/aidev/udev
cat > /usr/share/aidev/udev/60-ingenic.rules <<'RULES'
# Ingenic: USB-boot (кнопка USB_BOOT + RST) — прошивка через cloner.
# Скопировать на ХОСТ: sudo cp 60-ingenic.rules /etc/udev/rules.d/ && sudo udevadm control --reload
SUBSYSTEM=="usb", ATTR{idVendor}=="a108", MODE="0660", GROUP="plugdev", TAG+="uaccess"
RULES
getent group plugdev >/dev/null || groupadd plugdev
usermod -aG plugdev "$REMOTE_USER"
true
