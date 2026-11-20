# AGENTS.md: работа с репозиторием aidevcontainer

Здесь собирается **база** для devcontainer'ов: образ `ghcr.io/tualua/aidev` и features
`ghcr.io/tualua/aidevcontainer/<id>`.

- Собираете окружение для **проекта** оператора: читайте [docs/agent-guide.md](docs/agent-guide.md).
- Меняете **сам этот репозиторий**: читайте дальше.

## Структура

| Путь | Что |
|---|---|
| `image/Dockerfile` | Базовый образ. Контекст сборки — **корень репозитория** (`-f image/Dockerfile .`), см. `.dockerignore`. Два варианта: 26.04 (`latest`) и 22.04 (`jammy`, `--build-arg UBUNTU_VERSION=22.04`) |
| `image/rootfs/` | Файлы, копируемые в образ (поздним слоем): `/etc/aidev/{zshrc,bashrc,starship.toml}`, `/etc/tmux.conf`, `/usr/local/bin/aidev-*`, `/etc/claude-code/managed-settings.d/50-aidev.json` |
| `features/src/<id>/` | Features: `devcontainer-feature.json` + `install.sh` |
| `features/lib/common.sh` | Общие функции features. **Копируется** в каждую feature (`make features-sync`), копии в `.gitignore` |
| `features/test/<id>/test.sh` | Тесты features |
| `templates/` | Шаблоны `.devcontainer/` для проектов |
| `docs/agent-guide.md` | Руководство для агентов-сборщиков; копируется в образ в `/usr/share/doc/aidev/` |

## Инварианты

1. **Ничего тяжёлого в `$HOME` образа.** При UID/GID хоста ≠ 1000 devcontainer CLI делает
   `chown -R /home/dev`. Однажды из-за 1.6 GB в `$HOME` старт занимал 10+ минут. Инструменты
   ставятся от root в `/usr/local`, `/opt/uv-tools`, `/usr/share/oh-my-zsh`. Исключение: Claude Code
   (нативный установщик, `~/.local`, несколько крупных файлов). Проверка:
   `docker run --rm aidev:dev bash -c 'du -sh ~; find ~ -xdev | wc -l'`, ориентир ≤ 400 MB и < 100 файлов.
2. **Каталог под каждый том из `devcontainer.metadata` создаётся в образе** с владельцем `dev`,
   иначе том получит владельца root. **Проекты изолированы:** всё, кроме кэша пакетов (`aidev-pkgcache`), лежит в
   проектных томах `aidev-<x>-${devcontainerId}`: учётные данные, состояние и память агентов, kubeconfig, `~/.cache`.
   Новые общие тома допустимы только для данных без привязки к проекту.
   В именах томов не используйте `${localWorkspaceFolderBasename}`: пробел или кириллица дают недопустимое имя.
3. **github.com не должен попасть в `ssh_known_hosts`.** GitHub работает только по HTTPS (`insteadOf`
   + `gh auth git-credential`); иначе Claude Code клонирует плагины по SSH и падает.
4. **Версии берутся как `latest` во время сборки**, поэтому CI по расписанию собирает без кэша.
   Новый инструмент с `latest` добавляйте так, чтобы build-arg позволял закрепить версию.
5. **Скачанное проверяется по sha256**, если upstream публикует контрольные суммы.
6. **Features самодостаточны**: ставят всё сами, рассчитаны на Ubuntu и пользователя `_REMOTE_USER`.
   Устройства пробрасываются только из проекта (`runArgs`), не из feature.
7. **Меняя поведение для проектов** (тома, env, lifecycle, features), обновите `docs/agent-guide.md`
   и `README.md`. При несовместимом изменении feature поднимите мажорную версию в `devcontainer-feature.json`.
8. **`50-aidev.json` только добавляет.** Не задавайте в нём `allowManagedPermissionRulesOnly`,
   `allowManagedHooksOnly` и deny-правила без просьбы оператора. В allow попадают только проверочные
   команды без доступа к реальной инфраструктуре. Невалидный JSON не даёт Claude Code запуститься (сборка проверяет через `jq`).
9. **Хуки не имеют TTY.** Вывод в терминал идёт только через `{"terminalSequence": ...}`
   (допустимы OSC 0/1/2/9/99/777 и BEL, иначе поле игнорируется), stdout хука должен содержать только JSON.
10. **Dockerfile собирается на 26.04 и на 22.04.** Новый пакет apt проверьте в обоих (`make image-jammy`);
   чего нет в 22.04 или там слишком старое — ставьте из релиза (как fzf/just/delta/zoxide).
   Features только для jammy перечислены в `FEATURES_JAMMY` (Makefile) и проверяют версию ОС сами.
11. Изменения в ранних слоях Dockerfile (apt, пользователь) пересобирают всё после них, это долго.
   Новое по возможности добавляйте в поздние слои.

## Проверка изменений

```bash
# lint
docker run --rm -v "$PWD:/w:ro" -w /w koalaman/shellcheck:stable -x -e SC1091 -s bash \
  features/lib/common.sh features/src/*/install.sh features/src/usb-debug/aidev-serial-sync \
  image/rootfs/usr/local/bin/aidev-* image/rootfs/etc/aidev/bashrc

# образ
docker build -f image/Dockerfile -t aidev:dev .
docker run --rm -t aidev:dev zsh -ic 'claude --version && go version && uv --version'   # без ошибок zsh

# features (нужен make features-sync или ручное копирование common.sh/aidev-device-groups)
make features-sync && (cd features && npx -y @devcontainers/cli features test --skip-scenarios --project-folder . -i aidev:dev \
  -f terraform -f govc -f kubernetes -f intel-gpu -f usb-debug)
# вариант jammy и его features
docker build --build-arg UBUNTU_VERSION=22.04 -f image/Dockerfile -t aidev:jammy-dev .
(cd features && npx -y @devcontainers/cli features test --skip-scenarios --project-folder . -i aidev:jammy-dev -f tina-sdk)

# сквозной тест: шаблон проекта с image: aidev:dev
devcontainer up --workspace-folder <tmp-проект> --remove-existing-container   # старт, postCreate без WARN
```

Сообщайте, что проверено, а что нет (например, проброс GPU/USB без реального устройства).

## Git

- Ветка `main`, коммиты с trailer `Co-Authored-By`, если их делает агент.
- Не пушить и не публиковать образы без явной просьбы оператора.
