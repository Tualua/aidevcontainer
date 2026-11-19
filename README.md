# aidev: базовый devcontainer для AI-assisted разработки

> **Агентам:** если вы собираете окружение для проекта, читайте [docs/agent-guide.md](docs/agent-guide.md)
> (в контейнере: `/usr/share/doc/aidev/agent-guide.md`). Если меняете этот репозиторий, читайте [AGENTS.md](AGENTS.md).

Устроен в три слоя:

| Слой | Что входит | Где |
|---|---|---|
| **Базовый образ** `ghcr.io/tualua/aidev` | То, что нужно почти всегда | `image/` |
| **Features** `ghcr.io/tualua/aidevcontainer/<id>` | То, что нужно отдельным проектам | `features/src/` |
| **Шаблоны** `.devcontainer/` | Типовые комбинации и проброс устройств | `templates/` |

## Базовый образ

Ubuntu 26.04, пользователь `dev` (uid 1000, sudo без пароля).

- **AI-агенты:** Claude Code (нативный установщик, канал `latest`), opencode, qwen-code
- **Go:** последняя версия, `GOTOOLCHAIN=auto`, gopls, dlv, goimports, gofumpt, golangci-lint
- **Python:** uv/uvx (интерпретаторы ставятся через uv), ruff, pre-commit, pyright
- **Ansible:** ansible-core и ansible-lint (через `uv tool`)
- **Shell:** shellcheck, shfmt, bats
- **JS/TS:** Node LTS, typescript, typescript-language-server
- **Git-хостинги:** gh, glab, git-lfs, delta
- **Shell по умолчанию:** zsh + oh-my-zsh (плагины git, gh, golang, uv, ansible,
  kubectl, helm, terraform, fzf, direnv и др.) + autosuggestions + syntax-highlighting.
  Конфиг лежит в `/etc/aidev/zshrc`. Своё кладите в `~/.zshrc.d/*.zsh`, а в производных образах
  в `/etc/aidev/zshrc.d/`. Тему и плагины можно переопределить через `ZSH_THEME`
  и `AIDEV_OMZ_PLUGINS` в `containerEnv`. bash тоже настроен (`/etc/aidev/bashrc`)
- **Промпт:** starship для zsh и bash, конфиг в `/etc/aidev/starship.toml`. Показывает git,
  версии Go/Python/Node, workspace Terraform и **контекст Kubernetes**. Если в терминале хоста
  нет Nerd Font, выполните `starship preset plain-text-symbols -o ~/.config/starship.toml` и задайте
  `STARSHIP_CONFIG`. Чтобы вернуть тему oh-my-zsh, задайте `AIDEV_PROMPT=omz`
  (тему выбирает `ZSH_THEME`).
- **Для агента:** ast-grep (структурный поиск и замена), gotestsum (компактный вывод тестов), scc (обзор кодовой базы),
  LSP-плагины Claude Code для Go, Python и TS (gopls, pyright, typescript-language-server уже в образе)
- **Для оператора:** lazygit (ревью изменений агента), glow (markdown в терминале), zoxide (`z <часть пути>`),
  `aidev-tmux` (сессия и параллельные агенты), `aidev-notify` (уведомления)
- **Утилиты:** tmux, jq, yq (mikefarah), ripgrep, fd, fzf, bat, direnv, just, сетевые утилиты

Настройки devcontainer зашиты в label `devcontainer.metadata`. Поэтому проекту достаточно
указать `"image": "ghcr.io/tualua/aidev:latest"`, а всё остальное подтянется само:

- `remoteUser`, `init`, обновление UID/GID под пользователя хоста;
- **именованные тома. Проекты изолированы друг от друга**: у каждого проекта свои учётные данные и
  состояние агентов (сессии, память, история). Агент одного проекта не видит, над чем работает другой.
  Общий только кэш пакетов.

  | Том | Путь в контейнере |
  |---|---|
  | **Проектные** (`<id>` — `devcontainerId`, хэш пути проекта, стабилен между пересборками) | |
  | `aidev-claude-<id>` | `~/.claude` (`CLAUDE_CONFIG_DIR`, `.claude.json` тоже там) |
  | `aidev-qwen-<id>` | `~/.qwen` |
  | `aidev-opencode-config-<id>`, `aidev-opencode-data-<id>` | `~/.config/opencode`, `~/.local/share/opencode` |
  | `aidev-gh-<id>`, `aidev-glab-<id>` | `~/.config/gh`, `~/.config/glab-cli` |
  | `aidev-kube-<id>` (feature `kubernetes`) | `~/.kube`: свой kubeconfig и **текущий контекст** |
  | `aidev-cache-<id>` | `~/.cache` (go-build, gopls, oh-my-zsh: производные от кода проекта) |
  | `aidev-history-<id>` | история zsh/bash |
  | **Общий** | |
  | `aidev-pkgcache` | `~/.pkgcache`: `GOMODCACHE`, `UV_CACHE_DIR`, `NPM_CONFIG_CACHE` (исходники зависимостей, **включая приватные**) |

  Поэтому в каждом новом проекте нужно один раз авторизоваться: `claude` (`/login`), `gh auth login`,
  `glab auth login`, opencode и qwen. Для gh/glab можно передать токен с хоста:
  `"containerEnv": {"GH_TOKEN": "${localEnv:GH_TOKEN_MYPROJ}"}` (для glab: `GITLAB_TOKEN`).
  Для Claude используйте именно `/login`: токен `CLAUDE_CODE_OAUTH_TOKEN` (`claude setup-token`) не работает с Remote Control.

  Тома проекта можно найти так: `docker inspect <контейнер> --format '{{range .Mounts}}{{.Name}} {{end}}'`.
  Если удалить каталог проекта, его тома останутся. Чистка: `docker volume ls -q -f dangling=true | grep '^aidev-'`.
  Если нужна изоляция и кэша пакетов (приватные зависимости), переопределите том в проекте:
  `"mounts": [{"source": "aidev-pkgcache-${devcontainerId}", "target": "/home/dev/.pkgcache", "type": "volume"}]`.
- **Настройки Claude по умолчанию** в `~/.claude/settings.json` нового проекта (пользовательский уровень, меняются как обычно):
  - `"tui": "fullscreen"`: полноэкранный рендерер без мерцания с виртуализированной прокруткой. Вернуть
    классический: `/tui default`. Claude сам отключает его после сбоев рендерера и в tmux control mode (`-CC`);
  - `remoteControlAtStartup: true`: **Remote Control включён**, выключается через `/config`. Сессия называется по имени каталога проекта
  (`CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX`). Нужна подписка Pro/Max/Team/Enterprise и вход через `/login`.

- **Плагины Claude Code** ставит `aidev-claude-plugins` при создании контейнера (`postCreateCommand`)
  в проектный том `~/.claude`. Он идемпотентен и при отсутствии сети не роняет создание контейнера.
  По умолчанию ставится `gsd-core@gsd-core` из маркетплейса
  [open-gsd/gsd-core](https://github.com/open-gsd/gsd-core). Список задают переменные
  `AIDEV_CLAUDE_MARKETPLACES` и `AIDEV_CLAUDE_PLUGINS` в `containerEnv` проекта (значение
  заменяет список целиком). Обновить плагины: `aidev-claude-plugins --update`.
  Если `postCreateCommand` задан и в проекте, выполнятся обе команды;
- **GitHub только по HTTPS.** `git@github.com:` автоматически переписывается в `https://github.com/`,
  push авторизуется токеном из `gh auth login` (git credential helper). Для gitlab.com то же
  через `glab auth login`; SSH к gitlab.com тоже работает (ключ сервера есть в `ssh_known_hosts`).
  Для self-hosted GitLab выполните `glab auth login --hostname <host>` и
  `git config --global credential.https://<host>.helper '!glab auth git-credential'`;
- **Разрешения и хуки Claude Code по умолчанию** лежат в `/etc/claude-code/managed-settings.d/50-aidev.json`:
  - проверочные команды (тесты, сборка, линтеры, чтение git) разрешены без подтверждения. Ничего, что ходит
    в реальную инфраструктуру (`terraform plan`, `ansible-playbook`, `kubectl`) или меняет историю git;
  - хуки `Notification` и `Stop` вызывают `aidev-notify`.

  Всё это **добавляется** к пользовательским и проектным настройкам, ничего не блокирует. Свои правила
  задавайте как обычно, в `~/.claude/settings.json` или `.claude/settings.json` проекта;
- **venv не активируется автоматически** (`python.terminal.activateEnvironment: false`,
  `python-envs.terminal.autoActivationType: off`): при reload окна в терминалы ничего не
  отправляется. Используйте `uv run ...` или активируйте `source .venv/bin/activate` вручную;
- расширения VS Code для Claude Code, Go, Python/Ruff, Ansible, ShellCheck, YAML, GitHub/GitLab.

## Features

| id | Содержимое | Опции |
|---|---|---|
| `terraform` | terraform, tflint | `version`, `tflint`, `opentofu` |
| `govc` | govc (vmware/govmomi) | `version` |
| `kubernetes` | kubectl, helm, k9s, kubectx/kubens, stern; проектный том `aidev-kube-<id>` → `~/.kube` | `kubectl`, `helm`, `k9s`, `kubectx`, `stern` |
| `intel-gpu` | OpenCL, Level Zero, VA-API (iHD), clinfo, intel_gpu_top | `compute`, `media`, `devel`, `tools` |
| `usb-debug` | openocd, gdb-multiarch, stlink, dfu-util, picocom/tio/minicom | `probeRs`, `pyocd`, `esptool` |

Features рассчитаны на этот базовый образ (Ubuntu, пользователь `dev`).

## Использование в проекте

Скопируйте подходящий шаблон из `templates/` в проект: `base`, `gpu`, `usb`, `infra` или `compose-db`
(контейнер разработки плюс Percona MongoDB через Docker Compose; подробности в
[руководстве, §4a](docs/agent-guide.md#4a-сервисы-рядом-бд-брокеры-кэши-docker-compose)):

```jsonc
{
    "name": "${localWorkspaceFolderBasename}",
    "image": "ghcr.io/tualua/aidev:latest",
    "features": {
        "ghcr.io/tualua/aidevcontainer/terraform:1": {},
        "ghcr.io/tualua/aidevcontainer/kubernetes:1": { "stern": true }
    },
    "postCreateCommand": "uv sync"
}
```

Если проекту нужно что-то совсем своё, используйте Dockerfile с `FROM ghcr.io/tualua/aidev:latest`
и `"build": {"dockerfile": "Dockerfile"}`. Метаданные базового образа при этом тоже наследуются.

Без VS Code:

```bash
npm i -g @devcontainers/cli
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . tmux new -A -s main
```

## Работа с агентами

**Сессия и параллельные агенты** (`aidev-tmux`):

```bash
aidev-tmux                      # tmux-сессия проекта: окна agent (запущен claude) / shell / test
aidev-tmux fix-auth             # новое окно: claude -w fix-auth, отдельный worktree и ветка worktree-fix-auth
aidev-tmux bump-deps --model sonnet   # то же, с аргументами claude
aidev-tmux -l                   # список worktree
```

Worktree лежат в `.claude/worktrees/<task>`. После слияния:
`git worktree remove .claude/worktrees/<task> && git branch -d worktree-<task>`.
Ревью изменений агента удобно делать в `lazygit`.

**Уведомления** (`aidev-notify`): «агент закончил» (Stop) и «агент ждёт ответа» (Notification).

- **На рабочий стол хоста** уведомления идут через OSC 777. Его поддерживают GNOME Terminal и Ptyxis
  (Fedora), Ghostty, WezTerm, foot. Внутри tmux тоже работает (`allow-passthrough` включён).
  **Терминал VS Code OSC 777 не поддерживает**.
- **На телефон или в браузер** через [ntfy](https://ntfy.sh): задайте `AIDEV_NTFY_TOPIC` (длинное случайное
  имя: топики на ntfy.sh публичные), при необходимости `AIDEV_NTFY_URL` и `AIDEV_NTFY_TOKEN` для своего сервера.
  Проще всего через `containerEnv` с `${localEnv:AIDEV_NTFY_TOPIC}`.
- Вручную после долгой команды: `make build; aidev-notify`. Выключить: `AIDEV_NOTIFY=off`.

## Устройства

Пробросить устройство не может ни образ, ни feature, только `runArgs` в проекте. Поэтому это вынесено в шаблоны.

GID групп хоста (render, plugdev, dialout) не совпадают с GID в контейнере. На каждом старте
features запускают `aidev-device-groups`: он создаёт группы с GID устройств и добавляет в них `dev`.

- **Intel GPU** (`templates/gpu`): `--device=/dev/dri`. Проверка: `clinfo -l`, `vainfo`.
- **USB-отладчики** (`templates/usb`): `/dev/bus/usb` монтируется целиком и открывается
  cgroup-правилами, так что переподключение отладчика работает без перезапуска контейнера.
  Serial-порты, появившиеся после старта, создаёт `sudo aidev-serial-sync`.
  **udev-правила нужны на хосте** (например `60-openocd.rules`; его можно взять из контейнера:
  `/usr/lib/udev/rules.d/60-openocd.rules`).

### Podman

В VS Code задайте `"dev.containers.dockerPath": "podman"`. В `runArgs` проекта добавьте:

```jsonc
"runArgs": ["--userns=keep-id", "--security-opt=label=disable", "--group-add=keep-groups"],
"updateRemoteUserUID": false
```

В rootless podman `--device-cgroup-rule` не действует: доступ к устройствам определяется
правами на хосте (через `keep-groups` и udev `uaccess`).

## Сборка и публикация

```bash
make image                    # docker build -f image/Dockerfile . → ghcr.io/tualua/aidev:latest и aidev:dev
make image-fresh              # без кэша: свежие Claude Code/opencode/qwen, Go, Node, uv-инструменты
make image ENGINE=podman
make image BUILD_ARGS="--build-arg GO_VERSION=1.26.3 --build-arg CLAUDE_CODE_VERSION=latest"
make features-test            # devcontainer CLI: features поверх aidev:dev
make lint
make push features-publish REGISTRY=registry.example.com/team
```

GitHub Actions (`.github/workflows/`):

- **image.yml** собирает образ под amd64 при изменениях и **раз в неделю**.
  Плановая и ручная сборки идут без кэша, чтобы обновлялись AI CLI, Go, Node и патчи. Теги: `latest`, `YYYYMMDD`, `sha-xxxx`.
- **features.yml** публикует features в `ghcr.io/<owner>/aidevcontainer/<id>`.

Чтобы получить воспроизводимую сборку, закрепите тег образа `:YYYYMMDD` и мажорную версию feature `:1`.

## Обновление

| Что | Как обновляется |
|---|---|
| Образ (AI CLI, Go, Node, uv-инструменты, gh/glab, oh-my-zsh, пакеты Ubuntu) | CI раз в неделю собирает образ без кэша и публикует `latest` и `YYYYMMDD`. На хосте нужно сделать `docker pull` и затем **Rebuild Container** |
| Claude Code внутри работающего контейнера | Обновляется сам (нативный установщик в `~/.local`). После пересоздания контейнера берётся версия из образа |
| Плагины Claude Code | `aidev-claude-plugins --update` в каждом проекте (плагины хранятся в проектном томе) |
| Features (`:1`) | Мажорная версия закреплена. Minor/patch и `latest`-версии инструментов подтягиваются при Rebuild |
| GitHub Actions, базовый `ubuntu` | Dependabot (`.github/dependabot.yml`) |

Сам devcontainer **не скачивает** новый `latest`, пока локальный образ существует. Поэтому нужен
`docker pull ghcr.io/tualua/aidev:latest` перед Rebuild (VS Code: *Rebuild Without Cache* делает pull сам).

Тяжёлые инструменты ставятся вне `$HOME` (root-owned: `/usr/local`, `/opt/uv-tools`,
`/usr/share/oh-my-zsh`) и обновляются только пересборкой образа. Это важно: если UID/GID на хосте
не 1000, devcontainer CLI при старте делает `chown -R $HOME`, и большой `$HOME` превращал бы
старт в минуты копирования. Свои инструменты пользователь ставит как обычно (`uv tool install`,
`npm i -g`, `go install`), они попадают в `~/.local` и `~/go`.

## Безопасность

Контейнер считается песочницей для `claude --dangerously-skip-permissions` (алиас `ccy`).
Учитывайте, что внутри у агента есть sudo без пароля, сетевой доступ и учётные данные **этого** проекта
(тома других проектов ему не видны). Общий с другими проектами только кэш пакетов `aidev-pkgcache`.
Если в нём не должно быть чужих приватных зависимостей, изолируйте его (см. выше). Для недоверенного кода
стоит дополнительно ограничить исходящий трафик (по образцу `init-firewall.sh` из референсного devcontainer
Claude Code).
