# ============================================================================
# Gestión de Versiones de Servicios e Infraestructura
# ============================================================================
# Actualización de versiones de servicios y versionado semántico de la
# infraestructura.
#
# Uso:
#   make update-service-versions [SERVICE=postgres] [VERSION=17-alpine]
#   make check-version-compatibility SERVICE=postgres NEW_VERSION=17-alpine
#   make show-version
#   make bump-version PART=patch [SKIP_GIT_TAG=1] [SKIP_GIT_COMMIT=1]
#
# Requisitos:
#   - update-service-versions: requiere check-dependencies
#   - check-version-compatibility: requiere SERVICE y NEW_VERSION
#   - bump-version: requiere PART (major, minor, patch)
#     Opciones: SKIP_GIT_TAG=1 (no crear tag), SKIP_GIT_COMMIT=1 (no hacer commit)
# ============================================================================

# Base para rutas (toolbox o proyecto que incluye el toolbox)
_V_ROOT := $(or $(TOOLBOX_ROOT),$(PROJECT_ROOT))
COMMANDS_DIR := $(_V_ROOT)scripts/sh/commands
UTILS_DIR := $(_V_ROOT)scripts/sh/utils

.PHONY: update-service-versions check-version-compatibility show-version \
	bump-version release check-updates update-toolbox

# ============================================================================
# Gestión de Versiones de Servicios
# ============================================================================

update-service-versions: check-dependencies ## Actualiza *_VERSION en .env; interactivo sin SERVICE/VERSION [tool]
	@if [ ! -f "$(UTILS_DIR)/update-service-versions.sh" ]; then \
		$(call LOG_ERROR, Script update-service-versions.sh no encontrado en $(UTILS_DIR)); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(UTILS_DIR)/update-service-versions.sh" "$(SERVICE)" "$(VERSION)"

check-version-compatibility: ## Verifica compatibilidad de versiones [tool]
	@if [ -z "$(SERVICE)" ] || [ -z "$(NEW_VERSION)" ]; then \
		$(call LOG_ERROR, Debes especificar SERVICE y NEW_VERSION); \
		$(call LOG_INFO, Uso: make check-version-compatibility SERVICE=postgres NEW_VERSION=17-alpine); \
		exit 1; \
	fi
	@if [ ! -f "$(COMMANDS_DIR)/check-version-compatibility.sh" ]; then \
		$(call LOG_ERROR, Script check-version-compatibility.sh no encontrado en $(COMMANDS_DIR)); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" \
		VERSION_DB_PATH="$(VERSION_DB_PATH)" \
		VERSION_CHECK_STRICT="$(VERSION_CHECK_STRICT)" \
		bash "$(COMMANDS_DIR)/check-version-compatibility.sh" \
		"$(SERVICE)" "$(NEW_VERSION)" \
		$(if $(filter --json,$(VERSION_CHECK_OPTS)),--json,)

# ============================================================================
# Versionado Semántico de la Infraestructura
# ============================================================================

VERSION_FILE ?= $(PROJECT_ROOT).version

# Mensajes (en variables para evitar que comas y paréntesis rompan $(call))
_BUMP_ERROR_MSG := Debes especificar PART (major, minor, patch)
_BUMP_USAGE_MSG := Uso: make bump-version PART=patch

show-version: ## Muestra la versión actual de la infraestructura [tool]
	@if [ ! -f "$(COMMANDS_DIR)/show-version.sh" ]; then \
		$(call LOG_ERROR, Script show-version.sh no encontrado en $(COMMANDS_DIR)); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" VERSION_FILE="$(VERSION_FILE)" bash "$(COMMANDS_DIR)/show-version.sh"

bump-version: ## Incrementa versión (major, minor, patch), actualiza archivos y crea tag Git [tool]
	@if [ -z "$(PART)" ]; then \
		$(call LOG_ERROR, $(_BUMP_ERROR_MSG)); \
		$(call LOG_INFO, $(_BUMP_USAGE_MSG)); \
		exit 1; \
	fi
	@if [ ! -f "$(COMMANDS_DIR)/bump-version.sh" ]; then \
		$(call LOG_ERROR, Script bump-version.sh no encontrado en $(COMMANDS_DIR)); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" VERSION_FILE="$(VERSION_FILE)" \
		$(if $(SKIP_GIT_TAG),SKIP_GIT_TAG=1,) \
		$(if $(SKIP_GIT_COMMIT),SKIP_GIT_COMMIT=1,) \
		bash "$(COMMANDS_DIR)/bump-version.sh" "$(PART)"

release: ## Proceso completo de release: tests + bump version + tag + release notes [tool]
	@if [ -z "$(PART)" ]; then \
		$(call LOG_ERROR, Debes especificar PART major minor patch); \
		$(call LOG_INFO, Uso: make release PART=patch [DRY_RUN=1] [SKIP_TESTS=1]); \
		exit 1; \
	fi
	@if [ ! -f "$(COMMANDS_DIR)/release.sh" ]; then \
		$(call LOG_ERROR, Script release.sh no encontrado en $(COMMANDS_DIR)); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" VERSION_FILE="$(VERSION_FILE)" \
		$(if $(DRY_RUN),DRY_RUN_ENV=1,) \
		$(if $(SKIP_TESTS),SKIP_TESTS=1,) \
		bash "$(COMMANDS_DIR)/release.sh" "$(PART)" \
		$(if $(DRY_RUN),--dry-run,) \
		$(if $(SKIP_TESTS),--skip-tests,)

check-updates: ## Verifica actualizaciones disponibles [tool]
	@if [ ! -f "$(COMMANDS_DIR)/check-updates.sh" ]; then \
		$(call LOG_ERROR, Script check-updates.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" TOOLBOX_ROOT="$(TOOLBOX_ROOT)" \
		bash "$(COMMANDS_DIR)/check-updates.sh" "$(CHECK_TOOLBOX)" "$(CHECK_IMAGES)"

update-toolbox: ## Actualiza dev-toolbox a última versión [tool]
	@if [ -z "$(TOOLBOX_ROOT)" ]; then \
		$(call LOG_ERROR, TOOLBOX_ROOT no definido); \
		$(call LOG_INFO, Este comando debe ejecutarse desde un proyecto que usa dev-toolbox); \
		exit 1; \
	fi
	@if [ ! -d "$(TOOLBOX_ROOT)/.git" ]; then \
		$(call LOG_ERROR, dev-toolbox no es un repositorio Git); \
		exit 1; \
	fi
	@$(call LOG_STEP, Actualizando dev-toolbox...);
	@cd "$(TOOLBOX_ROOT)" && git pull origin main || { \
		$(call LOG_ERROR, Falló al actualizar dev-toolbox); \
		exit 1; \
	}
	@$(call LOG_SUCCESS, dev-toolbox actualizado correctamente)
