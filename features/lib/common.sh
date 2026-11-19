# Общие функции для install.sh features. Копируется в каждую feature (make sync-lib),
# т.к. features публикуются как независимые OCI-артефакты.
set -euo pipefail

# shellcheck disable=SC2034  # используется в install.sh
ARCH="$(dpkg --print-architecture)"             # amd64 | arm64
REMOTE_USER="${_REMOTE_USER:-dev}"

# Все curl в install.sh — с защитой от нестабильной сети: таймаут подключения, обрыв «застрявшей»
# загрузки (< 1 KB/s в течение 60 s) и повторы при любых ошибках (включая HTTP/2 PROTOCOL_ERROR).
curl() {
    command curl --connect-timeout 20 --speed-limit 1024 --speed-time 60 \
        --retry 5 --retry-all-errors --retry-delay 3 "$@"
}

apt_install() {
    export DEBIAN_FRONTEND=noninteractive
    if [ -z "$(find /var/lib/apt/lists -maxdepth 1 -type f -name '*Packages*' -print -quit 2>/dev/null)" ]; then
        apt-get update
    fi
    apt-get install -y --no-install-recommends "$@"
}

apt_cleanup() { rm -rf /var/lib/apt/lists/*; }

# Последний тег релиза GitHub без API (нет rate limit): gh_latest_tag owner/repo
gh_latest_tag() {
    curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest" | sed 's#.*/tag/##'
}

# fetch URL DEST [SHA256]
fetch() {
    curl -fsSL "$1" -o "$2"
    if [ -n "${3:-}" ]; then echo "$3  $2" | sha256sum -c - >/dev/null; fi
}

# sha256 из файла checksums: sha_from SUMS_URL FILENAME
sha_from() { curl -fsSL "$1" | awk -v f="$2" '$2==f || $2=="*"f {print $1}'; }

run_as_user() { su - "$REMOTE_USER" -c "$*"; }

bash_completion() { # bash_completion NAME CMD...
    local name="$1"; shift
    "$@" > "/etc/bash_completion.d/$name" 2>/dev/null || rm -f "/etc/bash_completion.d/$name"
}
