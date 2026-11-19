#!/usr/bin/env bash
# mongosh из официального релиза (npm-пакет ставится неработоспособным: npm 11 не запускает
# install-скрипты зависимостей). Ставится в ~/.local/bin; sha256 — из GitHub API.
set -euo pipefail
command -v mongosh >/dev/null && mongosh --version >/dev/null 2>&1 && exit 0
case "$(uname -m)" in x86_64) arch=x64 ;; aarch64) arch=arm64 ;; *) echo "unsupported arch" >&2; exit 1 ;; esac
rel="$(curl -fsSL --retry 3 https://api.github.com/repos/mongodb-js/mongosh/releases/latest)"
asset="$(jq -c --arg a "linux-$arch.tgz" '.assets[] | select(.name | endswith($a))' <<<"$rel")"
url="$(jq -r .browser_download_url <<<"$asset")"
sha="$(jq -r '.digest | sub("^sha256:"; "")' <<<"$asset")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
curl -fsSL --retry 3 "$url" -o "$tmp/mongosh.tgz"
echo "$sha  $tmp/mongosh.tgz" | sha256sum -c - >/dev/null
tar -xzf "$tmp/mongosh.tgz" -C "$tmp" --strip-components=1
install -D -m 0755 "$tmp/bin/mongosh" "$HOME/.local/bin/mongosh"
mongosh --version
