#!/usr/bin/env bash
set -e
source dev-container-features-test-lib
check "python is 3.x" bash -c 'python --version 2>&1 | grep -q "^Python 3\."'
check "flex" flex --version
check "bison" bison --version
check "openssl headers" test -f /usr/include/openssl/bio.h
check "ncurses headers" test -f /usr/include/ncurses.h
check "mkimage" which mkimage
check "cpio" cpio --version
check "bc" bash -c 'echo 1+1 | bc | grep -q 2'
check "adb" adb version
check "udev rule" test -f /usr/share/aidev/udev/60-ingenic.rules
reportResults
