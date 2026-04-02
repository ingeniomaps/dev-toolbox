# ============================================================================
# Sistema de Rollback
# ============================================================================
# Guarda y restaura estados del sistema para rollback.
#
# Uso:
#   make save-state [STATE_NAME_CUSTOM=nombre]
#   make list-states
#   make rollback STATE=20241231_120000
#
# Variables:
#   STATE_NAME_CUSTOM - Nombre personalizado para el estado (opcional)
#   STATE - Nombre del estado a restaurar (requerido para rollback)
#   STATES_DIR - Directorio donde se guardan los estados (default: .states)
# ============================================================================

STATES_DIR ?= $(PROJECT_ROOT).states

_ROOT := $(or $(TOOLBOX_ROOT),$(PROJECT_ROOT))
COMMANDS_DIR := $(_ROOT)scripts/sh/commands

.PHONY: save-state list-states rollback

save-state: check-dependencies ## Guarda el estado actual del sistema [main]
	@if [ ! -f "$(COMMANDS_DIR)/save-state.sh" ]; then \
		$(call LOG_ERROR, Script save-state.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" STATES_DIR="$(STATES_DIR)" \
		bash "$(COMMANDS_DIR)/save-state.sh" "$(STATE_NAME_CUSTOM)"

list-states: ## Lista todos los estados guardados [main]
	@if [ ! -f "$(COMMANDS_DIR)/list-states.sh" ]; then \
		$(call LOG_ERROR, Script list-states.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" STATES_DIR="$(STATES_DIR)" \
		bash "$(COMMANDS_DIR)/list-states.sh"

rollback: check-dependencies ## Restaura un estado guardado [main]
	@if [ -z "$(STATE)" ]; then \
		$(call LOG_ERROR, Debes especificar STATE); \
		$(call LOG_INFO, Uso: make rollback STATE=20241231_120000); \
		$(call LOG_INFO, Lista estados: make list-states); \
		exit 1; \
	fi
	@if [ ! -f "$(COMMANDS_DIR)/rollback.sh" ]; then \
		$(call LOG_ERROR, Script rollback.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" STATES_DIR="$(STATES_DIR)" \
		bash "$(COMMANDS_DIR)/rollback.sh" "$(STATE)"
