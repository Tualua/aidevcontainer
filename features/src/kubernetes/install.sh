#!/usr/bin/env bash
. "$(dirname "$0")/common.sh"

# kubectl
v="${KUBECTL:-latest}"
[ "$v" = latest ] && v="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
v="v${v#v}"
fetch "https://dl.k8s.io/release/${v}/bin/linux/${ARCH}/kubectl" /usr/local/bin/kubectl \
    "$(curl -fsSL "https://dl.k8s.io/release/${v}/bin/linux/${ARCH}/kubectl.sha256")"
chmod 0755 /usr/local/bin/kubectl
bash_completion kubectl kubectl completion bash

# helm
v="${HELM:-latest}"
if [ "$v" != none ]; then
    [ "$v" = latest ] && v="$(curl -fsSL https://get.helm.sh/helm-latest-version)"
    v="v${v#v}"; f="helm-${v}-linux-${ARCH}.tar.gz"
    fetch "https://get.helm.sh/$f" "/tmp/$f" "$(curl -fsSL "https://get.helm.sh/$f.sha256sum" | awk '{print $1}')"
    tar -C /usr/local/bin --strip-components=1 -xzf "/tmp/$f" "linux-${ARCH}/helm" && rm "/tmp/$f"
    bash_completion helm helm completion bash
fi

if [ "${K9S:-true}" = true ]; then
    f="k9s_Linux_${ARCH}.tar.gz"; base="https://github.com/derailed/k9s/releases/latest/download"
    fetch "$base/$f" "/tmp/$f" "$(sha_from "$base/checksums.sha256" "$f")"
    tar -C /usr/local/bin -xzf "/tmp/$f" k9s && rm "/tmp/$f"
fi

if [ "${KUBECTX:-true}" = true ]; then
    t="$(gh_latest_tag ahmetb/kubectx)"
    case "$ARCH" in amd64) a=x86_64;; *) a="$ARCH";; esac
    for tool in kubectx kubens; do
        f="${tool}_${t}_linux_${a}.tar.gz"
        base="https://github.com/ahmetb/kubectx/releases/download/${t}"
        fetch "$base/$f" "/tmp/$f" "$(sha_from "$base/checksums.txt" "$f")"
        tar -C /usr/local/bin -xzf "/tmp/$f" "$tool" && rm "/tmp/$f"
    done
fi

if [ "${STERN:-false}" = true ]; then
    t="$(gh_latest_tag stern/stern)"; f="stern_${t#v}_linux_${ARCH}.tar.gz"
    base="https://github.com/stern/stern/releases/download/${t}"
    fetch "$base/$f" "/tmp/$f" "$(sha_from "$base/checksums.txt" "$f")"
    tar -C /usr/local/bin -xzf "/tmp/$f" stern && rm "/tmp/$f"
fi

install -d -o "$REMOTE_USER" -g "$REMOTE_USER" "$(getent passwd "$REMOTE_USER" | cut -d: -f6)/.kube"
kubectl version --client
