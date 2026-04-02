# ============================================================================
# Setup y Configuración
# ============================================================================
# Comandos para configuración inicial, instalación y verificación.
#
# Uso:
#   make setup
#   make install-dependencies
#   make verify-installation
#   make rotate-logs [DAYS=7] [SERVICE=nombre]
#   make start-required [SERVICES="servicio1 servicio2"]
#   make create-service SERVICE=nombre
#
# Variables:
#   SERVICE - Nombre del servicio (para rotate-logs, create-service, env-show)
#   SERVICES - Lista de servicios separados por espacios (opcional)
#   DAYS - Días de retención para logs (default: 7)
#   EDITOR - Editor a usar para env-edit (default: $EDITOR o detectado)
# ============================================================================

_ROOT := $(or $(TOOLBOX_ROOT),$(PROJECT_ROOT))
SETUP_DIR := $(_ROOT)scripts/sh/setup
COMMANDS_DIR := $(_ROOT)scripts/sh/commands
UTILS_DIR := $(_ROOT)scripts/sh/utils

.PHONY: setup install-dependencies verify-installation rotate-logs start-required create-service \
	info list-services list-volumes list-networks list-images config-show env-show env-edit \
	install-pre-commit validate-pre-commit

setup: check-dependencies ## Configuración inicial completa del proyecto [main]
	@if [ ! -f "$(SETUP_DIR)/setup.sh" ]; then \
		$(call LOG_ERROR, Script setup.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(SETUP_DIR)/setup.sh"

install-dependencies: ## Intenta instalar dependencias faltantes [main]
	@if [ ! -f "$(SETUP_DIR)/install-dependencies.sh" ]; then \
		$(call LOG_ERROR, Script install-dependencies.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(SETUP_DIR)/install-dependencies.sh"

verify-installation: check-dependencies ## Verificación post-instalación [main]
	@if [ ! -f "$(COMMANDS_DIR)/verify-installation.sh" ]; then \
		$(call LOG_ERROR, Script verify-installation.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(COMMANDS_DIR)/verify-installation.sh"

rotate-logs: check-dependencies ## Rota logs de contenedores y archivos del sistema [main]
	@if [ ! -f "$(UTILS_DIR)/rotate-logs.sh" ]; then \
		$(call LOG_ERROR, Script rotate-logs.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" \
		LOG_RETENTION_DAYS="$(LOG_RETENTION_DAYS)" \
		LOG_DIR="$(LOG_DIR)" \
		bash "$(UTILS_DIR)/rotate-logs.sh" \
		$(if $(DAYS),$(DAYS),) \
		$(if $(filter --containers-only,$(LOG_ROTATE_OPTS)),--containers-only,) \
		$(if $(filter --files-only,$(LOG_ROTATE_OPTS)),--files-only,) \
		$(if $(SERVICE),$(SERVICE),)

clean-logs: check-dependencies ## Limpia logs antiguos del sistema [main]
	@if [ ! -f "$(UTILS_DIR)/log-file-manager.sh" ]; then \
		$(call LOG_ERROR, Script log-file-manager.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" \
		LOG_RETENTION_DAYS="$(LOG_RETENTION_DAYS)" \
		LOG_DIR="$(LOG_DIR)" \
		bash -c ' \
			source "$(UTILS_DIR)/log-file-manager.sh" && \
			cleaned=$$(cleanup_old_logs "$(LOG_DIR)") && \
			echo "Archivos limpiados: $$cleaned" \
		'

start-required: check-dependencies ## Inicia contenedores requeridos si no están corriendo [main]
	@$(call LOG_STEP, Iniciando contenedores requeridos...);
	@if [ -z "$(SERVICES)" ] && [ -f "$(PROJECT_ROOT).env" ]; then \
		SERVICES_LIST=$$(grep -E '^[A-Z_]+_VERSION=' "$(PROJECT_ROOT).env" 2>/dev/null | \
			sed 's/_VERSION=.*//' | tr '[:upper:]' '[:lower:]' | tr '_' '-' | tr '\n' ' ' || echo ""); \
	elif [ -n "$(SERVICES)" ]; then \
		SERVICES_LIST="$(SERVICES)"; \
	else \
		$(call LOG_WARN, No hay servicios disponibles para iniciar); \
		exit 0; \
	fi
	@if [ -z "$$SERVICES_LIST" ]; then \
		$(call LOG_WARN, No hay servicios disponibles para iniciar); \
		exit 0; \
	fi
	@for service in $$SERVICES_LIST; do \
		if [ -z "$(SERVICE_PREFIX)" ]; then \
			CONTAINER_NAME="$$service"; \
		else \
			CONTAINER_NAME="$(SERVICE_PREFIX)-$$service"; \
		fi; \
		if ! docker ps --format '{{.Names}}' | grep -q "^$$CONTAINER_NAME$$"; then \
			$(call LOG_INFO, Iniciando $$service...); \
			$(MAKE) up-$$service || $(call LOG_WARN, No se pudo iniciar $$service); \
		else \
			$(call LOG_SUCCESS, $$service ya está corriendo); \
		fi; \
	done
	@$(call LOG_SUCCESS, Contenedores requeridos iniciados);

create-service: check-dependencies ## Crea estructura base para un nuevo servicio [main]
	@if [ -z "$(SERVICE)" ]; then \
		$(call LOG_ERROR, Debes especificar SERVICE); \
		$(call LOG_INFO, Uso: make create-service SERVICE=nombre); \
		exit 1; \
	fi
	@if [ ! -f "$(SETUP_DIR)/create-service.sh" ]; then \
		$(call LOG_ERROR, Script create-service.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(SETUP_DIR)/create-service.sh" "$(SERVICE)"

info: check-dependencies ## Muestra información completa del proyecto [main]
	@if [ ! -f "$(COMMANDS_DIR)/info.sh" ]; then \
		$(call LOG_ERROR, Script info.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(COMMANDS_DIR)/info.sh"

list-services: check-dependencies ## Lista servicios configurados [main]
	@if [ ! -f "$(COMMANDS_DIR)/list-services.sh" ]; then \
		$(call LOG_ERROR, Script list-services.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(COMMANDS_DIR)/list-services.sh"

list-volumes: check-dependencies ## Lista volúmenes Docker [main]
	@if [ ! -f "$(COMMANDS_DIR)/list-volumes.sh" ]; then \
		$(call LOG_ERROR, Script list-volumes.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(COMMANDS_DIR)/list-volumes.sh"

list-networks: check-dependencies ## Lista redes Docker [main]
	@if [ ! -f "$(COMMANDS_DIR)/list-networks.sh" ]; then \
		$(call LOG_ERROR, Script list-networks.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(COMMANDS_DIR)/list-networks.sh"

config-show: ## Muestra configuración del proyecto (sin secretos) [main]
	@if [ ! -f "$(COMMANDS_DIR)/config-show.sh" ]; then \
		$(call LOG_ERROR, Script config-show.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(COMMANDS_DIR)/config-show.sh"

install-pre-commit: ## Instala pre-commit hooks [main]
	@if [ ! -f "$(SETUP_DIR)/install-pre-commit.sh" ]; then \
		$(call LOG_ERROR, Script install-pre-commit.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(SETUP_DIR)/install-pre-commit.sh" --auto-install

validate-pre-commit: ## Valida e instala pre-commit, luego ejecuta todas las validaciones [ci-cd]
	@if [ ! -f "$(SETUP_DIR)/install-pre-commit.sh" ]; then \
		$(call LOG_ERROR, Script install-pre-commit.sh no encontrado); \
		exit 1; \
	fi
	@$(call LOG_STEP, Instalando y validando pre-commit...);
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(SETUP_DIR)/install-pre-commit.sh" \
		--auto-install --run

list-images: check-dependencies ## Lista imágenes Docker del proyecto [main]
	@if [ ! -f "$(COMMANDS_DIR)/list-images.sh" ]; then \
		$(call LOG_ERROR, Script list-images.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(COMMANDS_DIR)/list-images.sh"

env-show: ## Muestra variables de entorno (sanitizadas) [main]
	@if [ ! -f "$(COMMANDS_DIR)/env-show.sh" ]; then \
		$(call LOG_ERROR, Script env-show.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(COMMANDS_DIR)/env-show.sh" "$(SERVICE)"

env-edit: ## Abre .env en editor por defecto [main]
	@if [ ! -f "$(COMMANDS_DIR)/env-edit.sh" ]; then \
		$(call LOG_ERROR, Script env-edit.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" EDITOR="$(EDITOR)" \
		bash "$(COMMANDS_DIR)/env-edit.sh"
