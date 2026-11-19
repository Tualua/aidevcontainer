#!/usr/bin/env bash
. "$(dirname "$0")/common.sh"

v="${VERSION:-latest}"
[ "$v" = latest ] && v="$(curl -fsSL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r .current_version)"
v="${v#v}"
f="terraform_${v}_linux_${ARCH}.zip"
fetch "https://releases.hashicorp.com/terraform/${v}/${f}" "/tmp/$f" \
    "$(sha_from "https://releases.hashicorp.com/terraform/${v}/terraform_${v}_SHA256SUMS" "$f")"
unzip -o -q "/tmp/$f" terraform -d /usr/local/bin && rm "/tmp/$f"
echo 'complete -C /usr/local/bin/terraform terraform' > /etc/bash_completion.d/terraform

if [ "${TFLINT:-true}" = true ]; then
    f="tflint_linux_${ARCH}.zip"
    base="https://github.com/terraform-linters/tflint/releases/latest/download"
    fetch "$base/$f" "/tmp/$f" "$(sha_from "$base/checksums.txt" "$f")"
    unzip -o -q "/tmp/$f" tflint -d /usr/local/bin && rm "/tmp/$f"
fi

if [ "${OPENTOFU:-false}" = true ]; then
    t="$(gh_latest_tag opentofu/opentofu)"; tv="${t#v}"
    f="tofu_${tv}_linux_${ARCH}.tar.gz"
    base="https://github.com/opentofu/opentofu/releases/download/${t}"
    fetch "$base/$f" "/tmp/$f" "$(sha_from "$base/tofu_${tv}_SHA256SUMS" "$f")"
    tar -C /usr/local/bin -xzf "/tmp/$f" tofu && rm "/tmp/$f"
fi

terraform version
