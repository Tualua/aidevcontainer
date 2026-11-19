#!/usr/bin/env bash
set -e
source dev-container-features-test-lib
check "govc" govc version
reportResults
