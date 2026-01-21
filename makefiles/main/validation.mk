# ============================================================================
# Comandos de Validación
# ============================================================================
# Validación de .env, IPs, puertos, versiones de herramientas y diagnóstico.
#
# Uso:
#   make validate            - .env, variables, IPs, puertos, versiones, scripts
#   make validate-ips        - Solo formato de IPs en .env
#   make check-ports         - Puertos disponibles (usa PORTS si está definido)
#   make check-versions-main - Versiones mínimas de Docker, Compose, Make, Bash
#   make check-dependencies  - Docker y docker-compose instalados y en marcha
#   make validate-syntax     - Sintaxis del Makefile (make -n help-toolbox)
#   make status              - Estado de contenedores (docker ps)
#   make doctor              - Diagnóstico completo (prereqs, validate, syntax, status, secrets)
#
# Requisitos:
#   - validate, validate-ips: .env (validate-ips sale si no existe)
#   - validate: VALIDATE_EXTRA_VARS y PORTS opcionales (variables extra; puertos a validar)
#   - check-ports: script check-ports.sh; variable PORTS opcional
#   - doctor: requiere check-dependencies, validate, validate-syntax, status, secrets-check
# ============================================================================

# Base para rutas de scripts (toolbox o proyecto que incluye el toolbox)
_ROOT := $(or $(TOOLBOX_ROOT),$(PROJECT_ROOT))
COMMANDS_DIR := $(_ROOT)scripts/sh/commands

.PHONY: validate validate-ips check-ports check-versions-main check-dependencies validate-syntax status doctor

# VALIDATE_EXTRA_VARS: variables .env adicionales a comprobar (separadas por comas).
# Cada proyecto/módulo puede definirlas, ej.: make validate VALIDATE_EXTRA_VARS="SERVICE_PREFIX,DB_PASSWORD"
# Opciones: --only-env, --only-ips, --only-ports, --only-versions, --skip-cache, --parallel, --cache-ttl=N
validate: ## Valida la configuración del proyecto [validation]
	@if [ ! -f "$(COMMANDS_DIR)/validate.sh" ]; then \
		$(call LOG_ERROR, Script validate.sh no encontrado en $(COMMANDS_DIR)); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" PORTS="$(PORTS)" \
		VALIDATE_CACHE_TTL="$(VALIDATE_CACHE_TTL)" \
		VALIDATE_SKIP_CACHE="$(VALIDATE_SKIP_CACHE)" \
		VALIDATE_PARALLEL="$(VALIDATE_PARALLEL)" \
		bash "$(COMMANDS_DIR)/validate.sh" "$(VALIDATE_EXTRA_VARS)" $(VALIDATE_OPTS)

validate-ips: ## Valida el formato de direcciones IP en .env [validation]
	@if [ ! -f "$(CURDIR)/.env" ]; then \
		$(call LOG_WARN, ".env no encontrado"); \
		exit 0; \
	fi
	@if [ ! -f "$(COMMANDS_DIR)/validate-ips.sh" ]; then \
		$(call LOG_ERROR, "Script validate-ips.sh no encontrado"); \
		exit 1; \
	fi
	@FORCE_COLOR=1 bash "$(COMMANDS_DIR)/validate-ips.sh" "$(CURDIR)/.env"

check-ports: ## Verifica si los puertos necesarios están disponibles [validation]
	@if [ ! -f "$(COMMANDS_DIR)/check-ports.sh" ]; then \
		$(call LOG_ERROR, "Script check-ports.sh no encontrado"); \
		exit 1; \
	fi
	@FORCE_COLOR=1 bash "$(COMMANDS_DIR)/check-ports.sh" $(PORTS)

check-versions-main: ## Verifica versiones mínimas de herramientas [validation]
	@if [ ! -f "$(COMMANDS_DIR)/check-versions.sh" ]; then \
		$(call LOG_ERROR, "Script check-versions.sh no encontrado en $(COMMANDS_DIR)"); \
		exit 1; \
	fi
	@FORCE_COLOR=1 bash "$(COMMANDS_DIR)/check-versions.sh"

check-dependencies: ## Verifica prerrequisitos (Docker, docker-compose) [validation]
	@if [ -f "$(_ROOT)scripts/sh/commands/check-dependencies.sh" ]; then \
		FORCE_COLOR=1 bash "$(_ROOT)scripts/sh/commands/check-dependencies.sh"; \
	else \
		$(call LOG_WARN, "Script check-dependencies.sh no encontrado"); \
		command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1 || exit 1; \
	fi

validate-syntax: ## Verifica sintaxis del Makefile [validation]
	@$(MAKE) -n help-toolbox >/dev/null 2>&1

status: ## Muestra estado de contenedores [validation]
	@docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || \
		$(call LOG_INFO, "No hay contenedores en ejecución o Docker no disponible")

doctor: ## Diagnóstico completo del sistema [validation]
	@$(call LOG_TITLE, "DIAGNÓSTICO COMPLETO DEL SISTEMA")
	@EXIT_CODE=0; \
	$(call LOG_STEP, "1. Verificando prerrequisitos..."); \
	$(MAKE) check-dependencies || EXIT_CODE=1; \
	$(call LOG_BLANK); \
	$(call LOG_STEP, "2. Validando configuración..."); \
	FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" PORTS="$(PORTS)" \
		bash "$(COMMANDS_DIR)/validate.sh" "$(VALIDATE_EXTRA_VARS)" || EXIT_CODE=1; \
	$(call LOG_BLANK); \
	$(call LOG_STEP, "3. Verificando sintaxis del Makefile..."); \
	$(MAKE) validate-syntax || EXIT_CODE=1; \
	$(call LOG_BLANK); \
	$(call LOG_STEP, "4. Estado de servicios..."); \
	$(MAKE) status || EXIT_CODE=1; \
	$(call LOG_BLANK); \
	$(call LOG_STEP, "5. Verificando secretos..."); \
	$(MAKE) secrets-check || EXIT_CODE=1; \
	$(call LOG_BLANK); \
	if [ $$EXIT_CODE -eq 0 ]; then \
		$(call LOG_SUCCESS, "DIAGNÓSTICO COMPLETADO - TODO EN ORDEN"); \
	else \
		$(call LOG_ERROR, "DIAGNÓSTICO COMPLETADO - SE ENCONTRARON PROBLEMAS"); \
		exit 1; \
	fi
