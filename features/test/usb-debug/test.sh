#!/usr/bin/env bash
set -e
source dev-container-features-test-lib
check "openocd" openocd --version
check "gdb-multiarch" gdb-multiarch --version
check "lsusb" which lsusb
check "serial-sync" test -x /usr/local/bin/aidev-serial-sync
reportResults
