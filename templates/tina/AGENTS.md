# AGENTS.md: прошивка на Allwinner Tina Linux SDK

<!-- Шаблон aidev (templates/tina). Заполните <...> под свой проект, лишнее удалите. -->

Рабочая копия — SDK производителя (Tina Linux, OpenWrt-based) с нашими изменениями поверх.
Плата: `<t113_woesldpspinand-tina>` (chip `<sun8iw20p1>`, ядро `lichee/linux-5.4`).

## Git: что наше, что вендорское

- Ветка `vendor` — только поставки производителя, теги `vendor/<дата>`. **Не коммитить в неё.**
- Ветка `main` — наша работа. Все изменения относительно поставки: `git diff vendor/<дата> main`.
- Новая поставка: коммит в `vendor`, затем `git merge vendor` в `main`.
- `prebuilt/` (тулчейны) и `dl/` (архивы исходников пакетов) в git не входят — распаковываются
  `aidev-sdk-fetch` по `sdk.lock`. **Не менять и не удалять** — восстановление долгое.
- `out/` — результаты сборки, не в git.

## Где наше

| Путь | Что |
|---|---|
| `device/config/chips/<t113>/configs/<board>/` | Конфигурация платы: `sys_config.fex`, разделы, env, dts |
| `target/allwinner/<board>/` | Описание target, `defconfig` |
| `package/<...>/` | Наши пакеты |
| `.config` | Текущая конфигурация сборки (`make menuconfig`) |

## Сборка

Все команды — в одной оболочке после настройки окружения:

```bash
source build/envsetup.sh && lunch <t113_woesldpspinand-tina>
make -j"$(nproc)"          # полная сборка: ~25 мин при -j4; не запускать без нужды
pack                       # упаковка: out/<board>/tina_<board>_uart0.img (< 1 мин)
```

Точечно (секунды–минуты) — предпочтительно:

```bash
make package/<name>/{clean,compile,install} V=s     # один пакет, подробный лог
make target/install                                  # пересобрать rootfs из готовых пакетов
make kernel_menuconfig / make menuconfig             # интерактивно — только оператор (нужен TTY)
```

- Ошибка в длинном логе: ищите первое `Error`/`error:` выше по выводу, а не последнюю строку.
- Предупреждения компилятора в `tools/` и вендорских пакетах — норма (тысячи), не чинить.
- `pack` может напечатать `ERROR` и всё равно вернуть 0 — проверяйте, что образ создан.
- `cp: cannot stat .../bin/*_<board>.fex` при `pack` — необязательные переопределения, норма.

## Окружение

- `python` — **Python 2** (требование SDK). Для своих скриптов: `python3` или `uv run`.
- Сборка идёт под Ubuntu 22.04 (образ `aidev:jammy`); более новые системы SDK не поддерживает.

## Плата

- Serial-консоль: `picocom -b 115200 /dev/ttyUSB0` (узлы после подключения: `sudo aidev-serial-sync`).
- adb (если в прошивке есть adbd): `adb devices`, `adb push <файл> /tmp/`, `adb shell <команда>`.
  Цикл для пакета: `make package/<x>/compile` → `adb push` бинарника → запуск → вывод.
- FEL-режим (прошивка «с нуля», SPI NAND): `xfel version`, `xfel spinand`.
- **Запись во flash (`xfel spinand write/erase`, `adb shell sysupgrade` и т.п.) — только с
  подтверждения оператора.** Чтение, `adb shell` для диагностики, консоль — можно.

## Поиск по коду

Дерево огромное (~150 тыс. файлов). Ищите в наших каталогах (таблица выше), в `lichee/linux-5.4`
и `package/` — точечно по пути; `out/`, `prebuilt/`, `dl/` не обыскивать.
