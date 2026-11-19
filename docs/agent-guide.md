# aidev: руководство для агентов, собирающих рабочие окружения

Документ для AI-агентов (Claude Code, opencode, qwen и др.), которые по просьбе **оператора**
(человека) готовят devcontainer для конкретного проекта на основе базового образа aidev.

- Источник: `https://github.com/Tualua/aidevcontainer/blob/main/docs/agent-guide.md`
- Внутри любого aidev-контейнера: `/usr/share/doc/aidev/agent-guide.md`

**Результат работы агента:** каталог `.devcontainer/` в репозитории проекта
(`devcontainer.json`, при необходимости `Dockerfile`), проверенный запуском, плюс короткий отчёт
оператору (см. [§9](#9-отчёт-оператору)).

---

## 1. Модель: три слоя

| Слой | Ссылка | Что даёт |
|---|---|---|
| Базовый образ | `ghcr.io/tualua/aidev:latest` | Языки, AI-агенты, shell, тома, настройки VS Code |
| Features | `ghcr.io/tualua/aidevcontainer/<id>:1` | Опциональные наборы инструментов |
| Проект | `.devcontainer/devcontainer.json` | Features, устройства, зависимости проекта, env |

Агент **пишет только третий слой**. Если для задачи кажется, что нужно менять базу или feature,
сообщите об этом оператору как о предложении в репозиторий aidevcontainer, а не обходите
проблему в проекте.

## 2. Что уже есть в базе: НЕ дублировать

Ubuntu 26.04. Пользователь `dev` (uid 1000, passwordless sudo), shell zsh + oh-my-zsh + starship.

| Область | Инструменты |
|---|---|
| AI | `claude` (канал latest, сам обновляется), `opencode`, `qwen`. Плагин Claude `gsd-core` ставится при создании контейнера |
| Go | последний Go, `GOTOOLCHAIN=auto` (версию из `go.mod` скачает сам), gopls, dlv, goimports, gofumpt, golangci-lint |
| Python | `uv`/`uvx` (интерпретаторы ставит uv по `.python-version`/`pyproject.toml`), системный python3, ruff, pre-commit, pyright |
| Ansible | `ansible-core`, `ansible-lint` (глобально, через uv tool) |
| JS/TS | Node LTS, npm, typescript, typescript-language-server. **Нет** pnpm/yarn/corepack |
| Shell | shellcheck, shfmt, bats |
| Git | git, git-lfs, delta, `gh`, `glab` |
| Утилиты | tmux, jq, yq (mikefarah), ripgrep, fd, fzf, bat, direnv, just, make, build-essential, сетевые утилиты |
| Для агента | ast-grep, gotestsum, scc; LSP-плагины Claude Code `gopls-lsp`, `pyright-lsp`, `typescript-lsp` |
| Для оператора | lazygit, glow, zoxide, `aidev-tmux`, `aidev-notify` |

Уже настроено в метаданных образа (label `devcontainer.metadata`), в проекте **не повторять**:
`remoteUser`, `containerUser`, `init`, `updateRemoteUserUID`, тома (ниже), терминал zsh,
расширения VS Code для Go/Python/Ruff/Ansible/ShellCheck/YAML/GitHub/GitLab/Claude Code,
отключённая автоактивация venv, `postCreateCommand` для плагинов Claude.

Claude Code: в `/etc/claude-code/managed-settings.d/50-aidev.json` разрешены проверочные команды
(тесты, сборка, линтеры, чтение git) и подключены хуки уведомлений. Эти настройки **объединяются** с
пользовательскими и проектными. Проектные разрешения кладите в `.claude/settings.json` проекта
(например, `Bash(make e2e *)`), базовые не повторяйте. Не создавайте `managed-settings.json`
в проекте или производном образе без просьбы оператора: это корпоративный уровень, и испорченный файл
не даёт Claude Code запуститься.

Тома. **Проекты изолированы**: учётные данные и состояние агентов у каждого проекта свои. Общий только кэш пакетов.

| Том | Путь |
|---|---|
| `aidev-claude-${devcontainerId}` | `~/.claude` (`CLAUDE_CONFIG_DIR`); в новом томе `settings.json` с `remoteControlAtStartup: true` и `tui: fullscreen` |
| `aidev-qwen-${devcontainerId}` | `~/.qwen` |
| `aidev-opencode-config-${devcontainerId}`, `aidev-opencode-data-${devcontainerId}` | `~/.config/opencode`, `~/.local/share/opencode` |
| `aidev-gh-${devcontainerId}`, `aidev-glab-${devcontainerId}` | `~/.config/gh`, `~/.config/glab-cli` |
| `aidev-kube-${devcontainerId}` (feature `kubernetes`) | `~/.kube` (свой контекст kubectl) |
| `aidev-cache-${devcontainerId}` | `~/.cache` |
| `aidev-history-${devcontainerId}` | `~/.commandhistory` |
| `aidev-pkgcache` (**общий**) | `~/.pkgcache`: `GOMODCACHE`, `UV_CACHE_DIR`, `NPM_CONFIG_CACHE` |

Не используйте для проекта токены `CLAUDE_CODE_OAUTH_TOKEN`/`ANTHROPIC_API_KEY`: с ними не работает Remote Control.
Оператор входит через `/login` в каждом проекте. `CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX` уже равен имени каталога проекта.

Git: GitHub **только по HTTPS** (`git@github.com:` переписывается автоматически), авторизация
через `gh auth login`, выполняемый **в каждом проекте** (токены у проектов разные). Альтернатива без логина:
`"containerEnv": {"GH_TOKEN": "${localEnv:<ПЕРЕМЕННАЯ>}"}`, для GitLab `GITLAB_TOKEN`. Для gitlab.com аналогично
через `glab auth login`, SSH к gitlab.com тоже работает.

## 3. Процедура

### 3.1. Изучить проект

Определите потребности по файлам в репозитории:

| Признак | Потребность | Действие |
|---|---|---|
| `go.mod` | Go | ничего (база); `postCreateCommand`: `go mod download` |
| `pyproject.toml` + `uv.lock` | Python/uv | `uv sync` |
| `requirements*.txt` без uv | Python/pip | `uv venv && uv pip install -r requirements.txt` |
| `ansible.cfg`, `playbooks/`, `roles/`, `requirements.yml` | Ansible | `ansible-galaxy install -r requirements.yml`; python-зависимости модулей (pyvmomi, kubernetes, netaddr…) ставить в venv проекта, см. 3.4 |
| `*.tf`, `.terraform.lock.hcl` | Terraform | feature `terraform`; `.terraform-version` → опция `version` |
| `tofu` в скриптах/CI | OpenTofu | feature `terraform` с `"opentofu": true` |
| `govc` в скриптах, `GOVC_*` | vSphere | feature `govc` |
| `kustomization.yaml`, `Chart.yaml`, `kubectl` в скриптах | Kubernetes | feature `kubernetes` |
| `package.json` | Node | ничего (база); `npm ci`. pnpm/yarn: `npm i -g pnpm` в `postCreateCommand` или Dockerfile |
| OpenCL / Level Zero / VA-API / oneAPI, `/dev/dri` в документации | Intel GPU | feature `intel-gpu` + проброс устройства (§4) |
| `platformio.ini`, `*.cfg` для openocd, `.cargo/config.toml` с `probe-rs`, `Embed.toml`, ESP-IDF | USB-отладка | feature `usb-debug` + проброс (§4) |
| драйвер БД в зависимостях (`go.mongodb.org/mongo-driver`, `pgx`, `go-redis`, `pymongo`, `psycopg`…), `docker-compose.yml` для разработки, testcontainers в тестах | сервисы рядом | шаблон `compose-db`, §4a |
| `.envrc` | direnv | ничего: хук уже подключён, оператор делает `direnv allow` |
| `.tool-versions`, `mise.toml` | менеджер версий | mise/asdf **нет** в базе. Используйте механизмы базы (Go toolchain, uv python); если не хватает, спросите оператора |

Прочитайте README, CI-конфиги (`.github/workflows`, `.gitlab-ci.yml`) и Makefile/justfile:
версии инструментов и команды сборки чаще всего именно там.

### 3.2. Выбрать features

| id | Опции (по умолчанию) |
|---|---|
| `terraform` | `version` (`latest`), `tflint` (`true`), `opentofu` (`false`) |
| `govc` | `version` (`latest`); ставит `GOVC_INSECURE=1` |
| `kubernetes` | `kubectl` (`latest`), `helm` (`latest`, `none` — не ставить), `k9s` (`true`), `kubectx` (`true`), `stern` (`false`) |
| `intel-gpu` | `compute` (`true`), `media` (`true`), `devel` (`false`), `tools` (`true`) |
| `usb-debug` | `probeRs` (`false`), `pyocd` (`false`), `esptool` (`false`) |

Версии закрепляйте только если проект этого требует (lock-файл, CI, `.terraform-version`).

### 3.3. Начать с шаблона

Шаблоны: `templates/{base,gpu,usb,infra,compose-db}/.devcontainer/` в репозитории
aidevcontainer (`compose-db`: контейнер разработки + Percona MongoDB через Docker Compose, §4a). Возьмите ближайший, удалите лишнее, комментарии оставьте только полезные проекту.

### 3.4. Зависимости проекта

- Ставьте в `postCreateCommand` (один раз при создании). Команду образа (`aidev-claude-plugins`)
  он **не заменяет**: выполнятся обе, сначала из образа.
- Несколько шагов: объектная форма, шаги выполняются параллельно:
  ```jsonc
  "postCreateCommand": { "py": "uv sync", "go": "go mod download", "galaxy": "ansible-galaxy install -r requirements.yml" }
  ```
  Если порядок важен, используйте строку с `&&`.
- `postStartCommand` только для того, что нужно на каждом старте и выполняется быстро.
- Python-зависимости для Ansible-модулей кладите в venv проекта (`uv sync` / `uv venv`) и запускайте
  ansible оттуда (`uv run ansible-playbook ...`) **или** добавьте `ansible-core` в зависимости проекта.
  Глобальный `ansible` из базы этих библиотек не видит.

### 3.5. Секреты и параметры окружения

- Никогда не записывайте секреты в `devcontainer.json`. Пробрасывайте их из окружения хоста:
  `"containerEnv": { "GOVC_PASSWORD": "${localEnv:GOVC_PASSWORD}" }`.
- Конфиги с секретами (kubeconfig, `.vault_pass`) лежат в томах или монтируются read-only
  с хоста: `"source=${localEnv:HOME}/.kube/config-prod,target=/home/dev/.kube/config,type=bind,readonly"`.
  Предварительно спросите оператора, где они лежат.
- Список переменных, которые оператор должен задать на хосте, обязательно включите в отчёт (§9).

### 3.6. Если нужного инструмента нет

Порядок предпочтения:

1. Опция существующей aidev-feature.
2. Официальная feature `ghcr.io/devcontainers/features/*` (на Ubuntu они работают).
3. Однострочная установка в `postCreateCommand` (`uv tool install X`, `npm i -g X`, `go install X@v`),
   если инструмент лёгкий. Он попадёт в `~/.local` или `~/go/bin` и будет переустанавливаться при пересоздании.
4. `.devcontainer/Dockerfile` с `FROM ghcr.io/tualua/aidev:latest` и `"build": {"dockerfile": "Dockerfile"}`.
   Метаданные базы при этом наследуются. **Ставьте как root в системные пути** (`/usr/local`, `/opt`),
   а не в `$HOME`, см. §5.1. В конце Dockerfile верните `USER dev`.
5. Если инструмент пригодится многим проектам, предложите оператору новую feature в aidevcontainer.

## 4. Устройства

Пробрасывать устройства можно **только** через `runArgs`/`mounts` проекта: ни образ, ни
feature этого не умеют. Проверьте, что устройство реально есть на хосте (`ls -l /dev/dri`, `lsusb`),
если агент работает на хосте; иначе спросите оператора.

**Intel GPU:**
```jsonc
"features": { "ghcr.io/tualua/aidevcontainer/intel-gpu:1": {} },
"runArgs": ["--device=/dev/dri"]
```

**USB-отладчики и serial** (переподключение без перезапуска контейнера):
```jsonc
"features": { "ghcr.io/tualua/aidevcontainer/usb-debug:1": {} },
"runArgs": [
    "--device-cgroup-rule=c 189:* rmw",   // USB
    "--device-cgroup-rule=c 166:* rmw",   // ttyACM*
    "--device-cgroup-rule=c 188:* rmw"    // ttyUSB*
],
"mounts": ["type=bind,source=/dev/bus/usb,target=/dev/bus/usb"]
```
Serial-порт, появившийся после старта: `sudo aidev-serial-sync`.

Группы устройств (render, plugdev, dialout хоста) подхватывает `aidev-device-groups` на старте,
добавлять `--group-add` для Docker не нужно.

**Требования к хосту** (выполняет оператор, внесите их в отчёт):
- udev-правила для отладчиков (`60-openocd.rules`, правила probe-rs/PlatformIO/ESP);
- для GPU пользователь хоста должен иметь доступ к `/dev/dri/renderD*`.

**Podman (rootless)** вместо Docker. Спросите оператора, если движок неизвестен:
```jsonc
"runArgs": ["--userns=keep-id", "--security-opt=label=disable", "--group-add=keep-groups", "--device=/dev/dri"],
"updateRemoteUserUID": false
```
`--device-cgroup-rule` в rootless не действует: доступ к USB определяется правами на хосте.

## 4a. Сервисы рядом (БД, брокеры, кэши): Docker Compose

Когда проекту нужна база данных или другой сервис, devcontainer переводится в compose-режим:
`devcontainer.json` ссылается на `compose.yaml`, в котором сервис `dev` использует базовый образ, а рядом
работают нужные сервисы. Начинайте с шаблона `templates/compose-db` (Percona MongoDB) и меняйте сервис БД.

**Что меняется по сравнению с обычным режимом:**

| | Обычный режим | Compose |
|---|---|---|
| Образ | `"image"` в devcontainer.json | `image:` у сервиса `dev` в compose.yaml, `"service": "dev"` |
| Монтирование проекта | автоматически | **явно**: `volumes: [..:/workspace:cached]` + `"workspaceFolder": "/workspace"` |
| Устройства | `runArgs` | **`runArgs` игнорируются**: `devices:`, `device_cgroup_rules:`, `volumes:` у сервиса `dev` |
| Метаданные образа, features, lifecycle, `containerEnv`, `mounts` | работают | работают так же (проверено) |
| Имена томов | как в метаданных | compose добавляет префикс `<проект>_devcontainer_`. Общий `aidev-pkgcache` закреплён в compose.yaml через `name:`, его не удаляйте |

**Правила:**
- Сервисы доступны из `dev` по имени сервиса (`mongo:27017`). Адрес передавайте переменной окружения
  (`MONGODB_URI`, `DATABASE_URL`, …) в `environment:` сервиса `dev`, а не зашивайте в код.
- `depends_on` с `condition: service_healthy` плюс `healthcheck` у сервиса: контейнер разработки стартует,
  когда БД уже готова, и тесты не падают на первом запуске.
- Порты наружу не публикуйте. Если оператору нужен GUI-клиент на хосте, публикуйте только на `127.0.0.1`.
- Данные БД храните в именованном томе compose-проекта. Сброс с хоста:
  `docker compose -p <каталог>_devcontainer down -v`.
- Учётные данные БД по умолчанию держите только для локального использования. Переопределение через
  `.devcontainer/.env` (добавьте в `.gitignore`), значения в compose.yaml подставляйте как `${VAR:-default}`.
- Клиенты БД (mongosh, psql, redis-cli) ставьте в `postCreateCommand`. **Не через `npm i -g`, если пакету нужны
  install-скрипты**: npm 11 их не запускает, и, например, mongosh ставится неработоспособным. Берите
  релизный бинарник (пример: `install-mongosh.sh` в шаблоне) или apt-пакет в производном Dockerfile.
- `"shutdownAction": "stopCompose"`: закрытие окна останавливает и сервисы.

**Особенности MongoDB** (учтены в шаблоне):
- Транзакции и change streams работают только в replica set, поэтому даже один узел запускается как
  `--replSet rs0`. Инициализирует его healthcheck (`rs.initiate`) с хостом участника `mongo:27017`.
  С `localhost` драйвер из контейнера `dev` не найдёт PRIMARY.
- Replica set с авторизацией требует `keyFile` даже для одного узла. Шаблон генерирует его при старте.

**PostgreSQL** (замена сервиса `mongo`, replica set и keyFile не нужны):
```yaml
  db:
    image: postgres:17
    environment: { POSTGRES_PASSWORD: postgres }
    volumes: [pg-data:/var/lib/postgresql/data]
    healthcheck: { test: ["CMD", "pg_isready", "-U", "postgres"], interval: 5s, retries: 30 }
```
и в `dev`: `DATABASE_URL: postgres://postgres:postgres@db:5432/postgres?sslmode=disable`.

**testcontainers** (тесты сами поднимают БД) требуют доступа к Docker изнутри контейнера. В базе его нет
намеренно: доступ к сокету Docker хоста равен root на хосте. Если проект построен на testcontainers,
сообщите оператору и предложите compose-сервис для разработки. Включать доступ к Docker можно только по
его явному решению.

## 5. Инварианты: нарушать нельзя

### 5.1. Не раздувать `$HOME`

Если UID/GID оператора не 1000:1000, devcontainer CLI при старте делает `chown -R /home/dev`.
Каждый файл в `$HOME` образа копируется в новый слой, и при гигабайтах это занимает минуты.
В производных Dockerfile ставьте тяжёлое только в `/usr/local`, `/opt` и т.п. от root.
Для uv tool: `UV_TOOL_DIR=/opt/uv-tools UV_TOOL_BIN_DIR=/usr/local/bin UV_PYTHON_INSTALL_DIR=/opt/uv-python`.
Для npm: `npm i -g --prefix /usr/local`. Для Go: `GOBIN=/usr/local/bin`.

### 5.2. Тома

- Слияние: `mounts` проекта **добавляются** к томам образа; при совпадении `target` **побеждает
  проект**. Например, если у проекта приватные зависимости, его кэш пакетов изолируют так:
  ```jsonc
  "mounts": [
      { "source": "aidev-pkgcache-${devcontainerId}", "target": "/home/dev/.pkgcache", "type": "volume" }
  ]
  ```
- Новый том на путь, **которого нет в образе**, создаётся с владельцем root, и `dev` не сможет в него писать.
  Либо создайте каталог в производном Dockerfile (`install -d -o dev -g dev /home/dev/.foo`), либо
  добавьте `"postCreateCommand": "sudo chown dev:dev /home/dev/.foo"`.
- Новый том для **секретов или состояния, специфичных для проекта**, делайте проектным: `"source": "<имя>-${devcontainerId}"`.
  Не используйте в имени тома `${localWorkspaceFolderBasename}`: каталог с пробелом или кириллицей даст
  недопустимое имя тома, и контейнер не запустится. Общий для всех проектов том (`aidev-*`) годится только для кэшей
  и данных без привязки к проекту. Не делайте общими тома с учётными данными или состоянием агентов:
  проекты должны быть изолированы.
- Не монтируйте `~/.ssh`, `~/.config/gh` и прочие каталоги с секретами хоста целиком без явной просьбы оператора.

### 5.3. Окружение и настройки

- `containerEnv` проекта объединяется с образом; при совпадении ключа значение проекта **заменяет** базовое.
  Пример: `AIDEV_CLAUDE_PLUGINS` заменяет весь список, поэтому чтобы добавить плагин, перечислите и базовый:
  ```jsonc
  "containerEnv": {
      "AIDEV_CLAUDE_MARKETPLACES": "open-gsd/gsd-core owner/other-marketplace",
      "AIDEV_CLAUDE_PLUGINS": "gsd-core@gsd-core other-plugin@other-marketplace"
  }
  ```
  Пустая строка отключает установку плагинов.
- Не включайте обратно автоактивацию venv (`python.terminal.activateEnvironment`): она мешает при reload окна.
- Не добавляйте github.com в `known_hosts` и не переключайте GitHub на SSH: Claude Code начнёт
  клонировать плагины по SSH и упадёт без ключа.
- Shell-настройки проекта не правьте через `~/.zshrc`. Используйте `/etc/aidev/zshrc.d/*.zsh`
  (в Dockerfile) или `~/.zshrc.d/*.zsh`. Для bash: `bashrc.d/*.sh`. Промпт: `AIDEV_PROMPT=omz`,
  `ZSH_THEME`, `AIDEV_OMZ_PLUGINS` через `containerEnv`.

### 5.4. Прочее

- `"image"` указывает на `ghcr.io/tualua/aidev:latest`. Тег `:YYYYMMDD` используйте только по просьбе оператора (воспроизводимость).
- Features указывайте с мажорной версией `:1`, без `:latest`.
- Не используйте `--privileged` и `--network=host`, если оператор явно не попросил.
- Не добавляйте `forwardPorts` «на всякий случай», только реальные порты проекта.

## 6. Работа агента внутри окружения: экономия времени и контекста

- **Обзор незнакомого репозитория:** `scc --no-cocomo` (языки и объём), `tree -L 2 -d`, `git log --oneline -20`.
- **Поиск по коду:** `rg` для текста, `ast-grep` для структуры: `ast-grep run -p 'fmt.Errorf($$$)' -l go`.
  Массовая замена: `ast-grep run -p 'old($A)' -r 'new($A)' -l go -U`. Это надёжнее sed.
- **Тесты с компактным выводом:** `gotestsum --format pkgname -- ./...`, `uv run pytest -q --tb=short`,
  `ruff check --output-format concise`, `golangci-lint run --output.text.print-issued-lines=false`.
- **LSP:** плагины gopls, pyright и typescript дают диагностику сразу после правки, а также переход к
  определению и поиск использований. Используйте их вместо грепа по именам.
- **Параллельная работа:** `aidev-tmux <task>` запускает отдельного агента в своём worktree. Не правьте
  чужой worktree.
- **Долгая операция:** по завершении вызовите `aidev-notify "заголовок" "текст"`, чтобы оператор узнал.

## 7. Проверка (обязательно перед отчётом)

Нужен devcontainer CLI (`npx -y @devcontainers/cli` или `devcontainer`) и доступ к Docker/Podman.
Если агент работает внутри контейнера без доступа к движку, пропустите проверку и **явно
сообщите оператору**, что окружение не запускалось.

```bash
# 1. Итоговая конфигурация после слияния с образом и features
devcontainer read-configuration --workspace-folder . --include-merged-configuration \
  | jq '.mergedConfiguration | {mounts, containerEnv, postCreateCommands, runArgs}'

# 2. Сборка и запуск (засеките время; повторный старт должен занимать секунды)
devcontainer up --workspace-folder . --remove-existing-container

# 3. Инструменты проекта
devcontainer exec --workspace-folder . zsh -lc 'go version && uv run python -V && terraform version'

# 4. Сборка/тесты проекта: команда из README/CI
devcontainer exec --workspace-folder . zsh -lc 'make test'
```

Проверки по features:

| feature | Проверка |
|---|---|
| `intel-gpu` | `clinfo -l` (видны платформы Intel), `vainfo` |
| `usb-debug` | `lsusb` (виден отладчик), `openocd -f interface/<probe>.cfg -f target/<mcu>.cfg -c 'init; exit'` или `probe-rs list` |
| `kubernetes` | `kubectl version --client`, `kubectl config get-contexts` (если kubeconfig есть) |
| `govc` | `govc about` (если заданы `GOVC_*`) |
| `terraform` | `terraform -chdir=<dir> init -backend=false && terraform validate` |

В выводе `postCreateCommand` строки `aidev-claude-plugins: WARN` не фатальны (нет сети);
упомяните их в отчёте.

Если отладку USB или GPU нельзя проверить (нет устройства), так и напишите в отчёте.

## 8. Примеры

**Go-сервис + Python-скрипты:**
```jsonc
{
    "name": "${localWorkspaceFolderBasename}",
    "image": "ghcr.io/tualua/aidev:latest",
    "postCreateCommand": { "go": "go mod download", "py": "uv sync" },
    "forwardPorts": [8080]
}
```

**Инфраструктура: Ansible + Terraform + vSphere + Kubernetes:**
```jsonc
{
    "name": "${localWorkspaceFolderBasename}",
    "image": "ghcr.io/tualua/aidev:latest",
    "features": {
        "ghcr.io/tualua/aidevcontainer/terraform:1": {},   // или { "version": "<из .terraform-version>" }
        "ghcr.io/tualua/aidevcontainer/govc:1": {},
        "ghcr.io/tualua/aidevcontainer/kubernetes:1": { "stern": true }
    },
    "postCreateCommand": "uv sync && uv run ansible-galaxy install -r requirements.yml",
    "containerEnv": {
        "GOVC_URL": "${localEnv:GOVC_URL}",
        "GOVC_USERNAME": "${localEnv:GOVC_USERNAME}",
        "GOVC_PASSWORD": "${localEnv:GOVC_PASSWORD}",
        "ANSIBLE_VAULT_PASSWORD_FILE": "/home/dev/.vault_pass"
    },
    "mounts": [
        "source=${localEnv:HOME}/.config/ansible/vault_pass,target=/home/dev/.vault_pass,type=bind,readonly"
    ]
}
```

**Прошивка: USB-отладчик + probe-rs + Intel GPU для визуализации:**
```jsonc
{
    "name": "${localWorkspaceFolderBasename}",
    "image": "ghcr.io/tualua/aidev:latest",
    "features": {
        "ghcr.io/tualua/aidevcontainer/usb-debug:1": { "probeRs": true },
        "ghcr.io/tualua/aidevcontainer/intel-gpu:1": { "media": false }
    },
    "runArgs": [
        "--device=/dev/dri",
        "--device-cgroup-rule=c 189:* rmw",
        "--device-cgroup-rule=c 166:* rmw",
        "--device-cgroup-rule=c 188:* rmw"
    ],
    "mounts": ["type=bind,source=/dev/bus/usb,target=/dev/bus/usb"]
}
```

**Свой инструмент через Dockerfile:**
```dockerfile
FROM ghcr.io/tualua/aidev:latest
USER root
RUN apt-get update && apt-get install -y --no-install-recommends protobuf-compiler \
    && rm -rf /var/lib/apt/lists/* \
    && GOBIN=/usr/local/bin GOPATH=/tmp/gp GOCACHE=/tmp/gc \
       go install google.golang.org/protobuf/cmd/protoc-gen-go@latest \
    && rm -rf /tmp/gp /tmp/gc
USER dev
```
```jsonc
{ "name": "${localWorkspaceFolderBasename}", "build": { "dockerfile": "Dockerfile" } }
```

## 9. Отчёт оператору

Коротко, по пунктам:

1. **Что создано**: файлы и выбранные features с обоснованием («`*.tf` → terraform»).
2. **Что сделать на хосте**: переменные окружения (`GOVC_*`…), файлы для bind-mount, udev-правила,
   группы, `docker pull ghcr.io/tualua/aidev:latest`.
3. **Первый запуск**: «Reopen in Container» в VS Code или `devcontainer up --workspace-folder .`.
   **Однократно в этом проекте** (тома проектные): `claude` → `/login`, `gh auth login`, `glab auth login`
   (или токены через `containerEnv`), логин в opencode и qwen, kubeconfig в `~/.kube`.
4. **Результат проверки**: что запускалось и прошло; что **не** проверено и почему.
5. **Предложения в aidevcontainer**, если что-то стоит вынести в базу или feature.

Не коммитьте `.devcontainer/` без подтверждения оператора, если он не просил об этом явно.
