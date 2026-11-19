# syntax=docker/dockerfile:1.7
#
# aidev — базовый образ для AI-assisted разработки.
# Go / Python / Shell / Ansible / Node(JS/TS) + tmux + Claude Code / opencode / qwen-code.
# Всё проектно-специфичное (terraform, govc, k8s, Intel GPU, USB) — в devcontainer features.

ARG UBUNTU_VERSION=26.04
FROM ghcr.io/astral-sh/uv:latest AS uv

FROM ubuntu:${UBUNTU_VERSION}

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
# "latest" или конкретная версия: 1.27.4 / 26 / 2.1.30 и т.п.
ARG GO_VERSION=latest
ARG NODE_MAJOR=26
ARG CLAUDE_CODE_VERSION=latest
ARG OPENCODE_VERSION=latest
ARG QWEN_CODE_VERSION=latest

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# --- Системные пакеты ---------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget gnupg sudo tzdata locales \
        git git-lfs openssh-client gnupg2 \
        zsh zsh-autosuggestions zsh-syntax-highlighting \
        bash-completion less vim-tiny nano man-db file \
        tmux jq ripgrep fd-find fzf bat tree htop procps psmisc lsof strace \
        unzip zip xz-utils zstd rsync patch \
        make build-essential pkg-config \
        shellcheck shfmt bats just direnv git-delta \
        python3 python3-venv python3-dev sshpass \
        iproute2 iputils-ping dnsutils netcat-openbsd \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI — из официального репозитория (в Ubuntu сильно устаревший)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# GitLab CLI — из релизов GitLab (в Ubuntu сильно устаревший)
ARG GLAB_VERSION=latest
RUN arch="$(dpkg --print-architecture)" \
    && v="${GLAB_VERSION}" \
    && if [ "$v" = latest ]; then v="$(curl -fsSL https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases/permalink/latest | jq -r .tag_name)"; fi \
    && v="${v#v}" && f="glab_${v}_linux_${arch}.deb" \
    && base="https://gitlab.com/gitlab-org/cli/-/releases/v${v}/downloads" \
    && curl -fsSL "$base/$f" -o "/tmp/$f" \
    && (cd /tmp && curl -fsSL "$base/checksums.txt" | grep " $f\$" | sha256sum -c -) \
    && apt-get install -y --no-install-recommends "/tmp/$f" && rm -f "/tmp/$f" \
    && rm -rf /var/lib/apt/lists/*

# SSH known_hosts для GitHub (ключи из API по HTTPS) и GitLab
RUN curl -fsSL https://api.github.com/meta | jq -r '.ssh_keys[] | "github.com " + .' > /etc/ssh/ssh_known_hosts \
    && ssh-keyscan -t ed25519,rsa,ecdsa gitlab.com 2>/dev/null >> /etc/ssh/ssh_known_hosts \
    && grep -q '^gitlab.com ' /etc/ssh/ssh_known_hosts

# yq (mikefarah, Go-версия; в Ubuntu пакет yq — это другой, python-обёртка над jq)
RUN arch="$(dpkg --print-architecture)" \
    && curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${arch}" -o /usr/local/bin/yq \
    && chmod 0755 /usr/local/bin/yq

# --- Go ------------------------------------------------------------------------
RUN arch="$(dpkg --print-architecture)" \
    && v="${GO_VERSION}" \
    && if [ "$v" = latest ]; then v="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1)"; else v="go${v#go}"; fi \
    && curl -fsSL "https://dl.google.com/go/${v}.linux-${arch}.tar.gz" -o /tmp/go.tgz \
    && echo "$(curl -fsSL "https://dl.google.com/go/${v}.linux-${arch}.tar.gz.sha256")  /tmp/go.tgz" | sha256sum -c - \
    && tar -C /usr/local -xzf /tmp/go.tgz && rm /tmp/go.tgz

# golangci-lint — официально рекомендуется бинарник, а не go install
RUN curl -sSfL https://golangci-lint.run/install.sh | sh -s -- -b /usr/local/bin

# --- Node.js (нужен qwen-code, LSP и для JS/TS) ---------------------------------
RUN arch="$(dpkg --print-architecture)"; case "$arch" in amd64) arch=x64;; esac \
    && base="https://nodejs.org/dist/latest-v${NODE_MAJOR}.x" \
    && curl -fsSL "$base/SHASUMS256.txt" -o /tmp/SHASUMS256.txt \
    && f="$(grep -oE "node-v[0-9.]+-linux-${arch}\.tar\.xz" /tmp/SHASUMS256.txt | head -1)" \
    && curl -fsSL "$base/$f" -o "/tmp/$f" \
    && (cd /tmp && grep " $f\$" SHASUMS256.txt | sha256sum -c -) \
    && tar -C /usr/local --strip-components=1 --exclude='*.md' --exclude=LICENSE -xJf "/tmp/$f" \
    && rm -f /tmp/node-* /tmp/SHASUMS256.txt

# --- starship (промпт для zsh и bash) -----------------------------------------
RUN case "$(dpkg --print-architecture)" in amd64) t=x86_64;; arm64) t=aarch64;; esac \
    && f="starship-${t}-unknown-linux-musl.tar.gz" \
    && base="https://github.com/starship/starship/releases/latest/download" \
    && curl -fsSL "$base/$f" -o "/tmp/$f" \
    && echo "$(curl -fsSL "$base/$f.sha256")  /tmp/$f" | sha256sum -c - \
    && tar -C /usr/local/bin -xzf "/tmp/$f" starship && rm "/tmp/$f"

# --- uv (Python-тулчейн) -------------------------------------------------------
COPY --from=uv /uv /uvx /usr/local/bin/

# --- Пользователь ---------------------------------------------------------------
# В ubuntu-образе уже есть пользователь ubuntu с uid 1000 — удаляем.
RUN if id ubuntu >/dev/null 2>&1; then userdel -r ubuntu; fi \
    && groupadd --gid "${USER_GID}" "${USERNAME}" \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" -m -s /usr/bin/zsh \
        -G sudo,dialout,plugdev,video "${USERNAME}" \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}" \
    && chmod 0440 "/etc/sudoers.d/${USERNAME}" \
    && git config --system safe.directory '*' \
    && git config --system init.defaultBranch main

COPY rootfs/ /

ENV GOPATH=/home/${USERNAME}/go \
    GOTOOLCHAIN=auto \
    NPM_CONFIG_PREFIX=/home/${USERNAME}/.local \
    UV_LINK_MODE=copy \
    UV_PYTHON_PREFERENCE=managed \
    CLAUDE_CONFIG_DIR=/home/${USERNAME}/.claude \
    EDITOR=vi \
    SHELL=/usr/bin/zsh \
    STARSHIP_CONFIG=/etc/aidev/starship.toml \
    AIDEV_CLAUDE_MARKETPLACES="https://github.com/open-gsd/gsd-core.git" \
    AIDEV_CLAUDE_PLUGINS="gsd-core@gsd-core" \
    PATH=/home/${USERNAME}/.local/bin:/home/${USERNAME}/go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ВАЖНО: тяжёлые инструменты ставим ВНЕ $HOME (root-owned, обновляются пересборкой образа).
# Если UID/GID пользователя хоста не 1000, devcontainer CLI делает `chown -R $HOME`,
# и каждый файл в $HOME копируется в новый слой — гигабайты и минуты на каждом старте.

# oh-my-zsh
RUN git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git /usr/share/oh-my-zsh \
    && rm -rf /usr/share/oh-my-zsh/.git

# Go-инструменты → /usr/local/bin
RUN export GOBIN=/usr/local/bin GOPATH=/tmp/gopath GOCACHE=/tmp/gocache \
    && go install golang.org/x/tools/gopls@latest \
    && go install golang.org/x/tools/cmd/goimports@latest \
    && go install github.com/go-delve/delve/cmd/dlv@latest \
    && go install mvdan.cc/gofumpt@latest \
    && rm -rf /tmp/gopath /tmp/gocache

# Python / Ansible инструменты (изолированные окружения uv tool) → /opt/uv-tools, бинарники в /usr/local/bin
RUN export UV_TOOL_DIR=/opt/uv-tools UV_TOOL_BIN_DIR=/usr/local/bin UV_PYTHON_INSTALL_DIR=/opt/uv-python \
        UV_CACHE_DIR=/tmp/uv-cache \
    && uv tool install ruff \
    && uv tool install pre-commit \
    && uv tool install ansible-core \
    && uv tool install ansible-lint \
    && rm -rf /tmp/uv-cache

# LSP для JS/TS/Python + opencode, qwen-code → /usr/local
RUN npm install -g --prefix /usr/local --no-fund --no-audit \
        typescript typescript-language-server pyright \
        "opencode-ai@${OPENCODE_VERSION}" \
        "@qwen-code/qwen-code@${QWEN_CODE_VERSION}" \
    && npm cache clean --force && rm -rf /root/.npm

# Каталоги, на которые монтируются тома (см. LABEL ниже) — создаём заранее,
# чтобы новый том получил правильного владельца.
RUN h="/home/${USERNAME}" \
    && install -d -o "${USERNAME}" -g "${USERNAME}" \
        "$h/.claude" "$h/.qwen" "$h/.config" "$h/.config/opencode" "$h/.config/gh" "$h/.config/glab-cli" \
        "$h/.local" "$h/.local/bin" "$h/.local/share" "$h/.local/share/opencode" \
        "$h/.cache" "$h/.commandhistory" "$h/go" "$h/go/pkg" "$h/go/pkg/mod" \
    && echo '[ -f /etc/aidev/bashrc ] && . /etc/aidev/bashrc' >> "$h/.bashrc" \
    && printf '%s\n' \
        '# Общая конфигурация aidev (oh-my-zsh, плагины, история): /etc/aidev/zshrc' \
        '# Переменные ZSH_THEME / AIDEV_OMZ_PLUGINS можно задать ДО source.' \
        'source /etc/aidev/zshrc' > "$h/.zshrc" \
    && chown "${USERNAME}:${USERNAME}" "$h/.zshrc"

USER ${USERNAME}
WORKDIR /home/${USERNAME}

# Claude Code — нативный установщик (~/.local; сам обновляется, несколько крупных файлов)
RUN curl -fsSL https://claude.ai/install.sh | bash -s "${CLAUDE_CODE_VERSION}" \
    && rm -rf "$HOME/.cache/"*

# Метаданные devcontainer: подхватываются автоматически любым проектом,
# использующим образ. В devcontainer.json проекта их можно дополнить/переопределить.
LABEL org.opencontainers.image.title="aidev" \
      org.opencontainers.image.description="Base devcontainer for AI-assisted development (Go/Python/Shell/Ansible/Node)" \
      devcontainer.metadata='[{ \
        "remoteUser": "dev", \
        "containerUser": "dev", \
        "updateRemoteUserUID": true, \
        "init": true, \
        "postCreateCommand": "/usr/local/bin/aidev-claude-plugins", \
        "mounts": [ \
          {"source": "aidev-claude",          "target": "/home/dev/.claude",               "type": "volume"}, \
          {"source": "aidev-qwen",            "target": "/home/dev/.qwen",                 "type": "volume"}, \
          {"source": "aidev-opencode-config", "target": "/home/dev/.config/opencode",      "type": "volume"}, \
          {"source": "aidev-opencode-data",   "target": "/home/dev/.local/share/opencode", "type": "volume"}, \
          {"source": "aidev-gh",              "target": "/home/dev/.config/gh",            "type": "volume"}, \
          {"source": "aidev-glab",            "target": "/home/dev/.config/glab-cli",      "type": "volume"}, \
          {"source": "aidev-gomodcache",      "target": "/home/dev/go/pkg/mod",            "type": "volume"}, \
          {"source": "aidev-cache",           "target": "/home/dev/.cache",                "type": "volume"}, \
          {"source": "aidev-history-${devcontainerId}", "target": "/home/dev/.commandhistory", "type": "volume"} \
        ], \
        "customizations": {"vscode": { \
          "settings": { \
            "terminal.integrated.defaultProfile.linux": "zsh", \
            "python.terminal.activateEnvironment": false, \
            "python-envs.terminal.autoActivationType": "off" \
          }, \
          "extensions": [ \
          "anthropic.claude-code", \
          "golang.go", \
          "ms-python.python", "charliermarsh.ruff", \
          "redhat.ansible", \
          "timonwong.shellcheck", "mkhl.shfmt", \
          "redhat.vscode-yaml", \
          "github.vscode-github-actions", "gitlab.gitlab-workflow", \
          "dbaeumer.vscode-eslint" \
        ]}} \
      }]'

CMD ["sleep", "infinity"]
