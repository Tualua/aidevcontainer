# Локальная сборка/публикация. ENGINE=podman для podman.
ENGINE    ?= docker
REGISTRY  ?= ghcr.io/tualua
IMAGE     ?= $(REGISTRY)/aidev
TAG       ?= latest
FEATURES  := $(notdir $(wildcard features/src/*))
# Features только для варианта jammy (Ubuntu 22.04): тестируются на aidev:jammy-dev
FEATURES_JAMMY := tina-sdk
BUILD_ARGS ?=

.PHONY: image image-jammy image-fresh push features-sync features-test features-test-jammy features-publish lint clean

image:  ## Собрать базовый образ (+ локальный тег aidev:dev)
	$(ENGINE) build $(BUILD_ARGS) -f image/Dockerfile -t $(IMAGE):$(TAG) -t aidev:dev .

image-jammy:  ## Вариант на Ubuntu 22.04 (для вендорских SDK) → $(IMAGE):jammy + aidev:jammy-dev
	$(ENGINE) build $(BUILD_ARGS) --build-arg UBUNTU_VERSION=22.04 -f image/Dockerfile -t $(IMAGE):jammy -t aidev:jammy-dev .

image-fresh:  ## Без кэша: подтянуть последние AI CLI, Go, Node, плагины и т.п.
	$(MAKE) image BUILD_ARGS="$(BUILD_ARGS) --no-cache --pull"

push: image
	$(ENGINE) push $(IMAGE):$(TAG)

# Features публикуются как независимые артефакты — общие файлы копируются в каждую.
features-sync:
	@for f in $(FEATURES); do \
	  cp features/lib/common.sh features/src/$$f/common.sh; \
	  cp image/rootfs/usr/local/bin/aidev-device-groups features/src/$$f/aidev-device-groups; \
	done

# Требует devcontainer CLI: npm i -g @devcontainers/cli
features-test: features-sync image
	cd features && devcontainer features test --skip-scenarios --project-folder . -i aidev:dev $(addprefix -f ,$(filter-out $(FEATURES_JAMMY),$(FEATURES)))

features-test-jammy: features-sync image-jammy
	cd features && devcontainer features test --skip-scenarios --project-folder . -i aidev:jammy-dev $(addprefix -f ,$(FEATURES_JAMMY))

features-publish: features-sync
	devcontainer features publish -r $(firstword $(subst /, ,$(REGISTRY))) \
	  -n $(patsubst $(firstword $(subst /, ,$(REGISTRY)))/%,%,$(REGISTRY))/aidevcontainer features/src

lint:
	shellcheck -x features/lib/common.sh features/src/*/install.sh features/src/usb-debug/aidev-serial-sync \
	  image/rootfs/usr/local/bin/aidev-device-groups image/rootfs/usr/local/bin/aidev-sdk-fetch
