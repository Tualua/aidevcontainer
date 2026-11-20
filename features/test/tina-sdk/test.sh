#!/usr/bin/env bash
set -e
source dev-container-features-test-lib
check "python is 2.x" bash -c 'python --version 2>&1 | grep -q "^Python 2\."'
check "python3 untouched" bash -c 'python3 --version | grep -q "^Python 3\."'
check "busybox" test -x /bin/busybox
check "i386 loader" test -e /lib/ld-linux.so.2
check "gcc" gcc --version
check "mkimage" which mkimage
check "adb" adb version
check "xfel" bash -c 'xfel 2>&1 | grep -q "usage"'
check "udev rule" test -f /usr/share/aidev/udev/60-allwinner.rules
reportResults
