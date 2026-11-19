#!/usr/bin/env bash
set -e
source dev-container-features-test-lib
check "terraform" terraform version
check "tflint" tflint --version
reportResults
