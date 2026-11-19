#!/usr/bin/env bash
set -e
source dev-container-features-test-lib
check "kubectl" kubectl version --client
check "helm" helm version
check "k9s" k9s version -s
check "kubectx" which kubectx kubens
reportResults
