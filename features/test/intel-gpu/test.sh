#!/usr/bin/env bash
set -e
source dev-container-features-test-lib
check "clinfo" which clinfo
check "vainfo" which vainfo
check "level-zero" bash -c 'ldconfig -p | grep -q libze_intel_gpu'
check "device-groups helper" test -x /usr/local/bin/aidev-device-groups
reportResults
