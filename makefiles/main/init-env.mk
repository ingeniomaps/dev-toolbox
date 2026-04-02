# ============================================================================
# Inicialización de Archivos de Entorno
# ============================================================================
# Wrapper Make para init-env.sh. La lógica está en scripts/sh/setup/init-env.sh
#
# Uso:
#   make init-env                      - Crea .env desde la primera plantilla
#   make init-env NAME=development     - Crea .env.development
#   make init-env FORCE=true           - Fuerza recreación aunque exista
#   make init-env SILENT=true          - Solo errores (sin mensajes normales)
#   make setup-env                     - init-env + validate + validate-passwords + secrets-check
#
# Variables (init-env):
#   NAME   - Sufijo del .env (ej. development → .env.development). Vacío = .env
#   FORCE  - true: recrear aunque exista. default: false
#   SILENT - true: solo errores. default: false
#
# Plantillas (en este orden): .env-template, .env.template, .env-example, .env.example
# ============================================================================

NAME ?=
FORCE ?= false
SILENT ?= false

# Base para rutas (toolbox o proyecto que incluye el toolbox)
_INIT_ROOT := $(or $(TOOLBOX_ROOT),$(PROJECT_ROOT))
INIT_ENV_SCRIPT := $(_INIT_ROOT)scripts/sh/setup/init-env.sh
COMMANDS_DIR := $(_INIT_ROOT)scripts/sh/commands

.PHONY: init-env setup-env export-config

init-env: ## Crea un archivo de entorno a partir de su plantilla si no existe [main]
	@if [ ! -f "$(INIT_ENV_SCRIPT)" ]; then \
		$(call LOG_ERROR, Script init-env.sh no encontrado en $(INIT_ENV_SCRIPT)); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(INIT_ENV_SCRIPT)" \
		$(if $(NAME),$(NAME),) \
		$(if $(filter true,$(FORCE)),--force,) \
		$(if $(filter true,$(SILENT)),--silent,)


# Mensajes para setup-env (en variables para evitar que comas y paréntesis rompan $(call))
_SETUP_STEP1 := 1. Validando configuración (.env, variables, IPs, puertos, versiones)...
_SETUP_STEP2 := 2. Validando contraseñas...
_SETUP_STEP3 := 3. Verificando secretos...

setup-env: init-env ## init-env + validate + validate-passwords + secrets-check [main]
	@$(call LOG_TITLE, "CONFIGURACIÓN INICIAL DEL PROYECTO")
	@EXIT_CODE=0; \
	$(call LOG_STEP, $(_SETUP_STEP1)); \
	FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" PORTS="$(PORTS)" \
		bash "$(COMMANDS_DIR)/validate.sh" "$(VALIDATE_EXTRA_VARS)" || EXIT_CODE=1; \
	$(call LOG_BLANK); \
	$(call LOG_STEP, $(_SETUP_STEP2)); \
	$(MAKE) validate-passwords || EXIT_CODE=1; \
	$(call LOG_BLANK); \
	$(call LOG_STEP, $(_SETUP_STEP3)); \
	$(MAKE) secrets-check || EXIT_CODE=1; \
	$(call LOG_BLANK); \
	if [ $$EXIT_CODE -eq 0 ]; then \
		$(call LOG_SUCCESS, "Configuración inicial completada"); \
	else \
		$(call LOG_WARN, "Configuración completada con advertencias. Revisa los mensajes anteriores."); \
	fi

export-config: ## Exporta configuración a formato portable [main]
	@if [ ! -f "$(COMMANDS_DIR)/export-config.sh" ]; then \
		$(call LOG_ERROR, Script export-config.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" FORMAT="$(FORMAT)" \
		OUTPUT="$(OUTPUT)" bash "$(COMMANDS_DIR)/export-config.sh" "$(FORMAT)" "$(OUTPUT)"
