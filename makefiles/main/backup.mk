# ============================================================================
# Gestión de Backups
# ============================================================================
# Comandos para realizar backups y restauraciones de servicios.
#
# Uso:
#   make backup-all
#   make restore-all
#   make restore-interactive SERVICE=postgres
#   make setup-backup-schedule FREQUENCY=daily
#   make update-images
#
# Variables:
#   SERVICE - Nombre del servicio (para restore-interactive)
#   SERVICES - Lista de servicios separados por espacios (opcional)
#   FREQUENCY - Frecuencia de backups: daily, weekly, monthly
#   BACKUP_PATH - Ruta del backup a restaurar
#   PARALLEL - true: ejecutar backups en paralelo (backup-all)
#   MAX_PARALLEL - Número máximo de backups paralelos (backup-all)
#   SKIP_MISSING - true: continuar si servicios no existen (backup-all, restore-all)
# ============================================================================

_ROOT := $(or $(TOOLBOX_ROOT),$(PROJECT_ROOT))
COMMANDS_DIR := $(_ROOT)scripts/sh/commands
BACKUP_DIR := $(_ROOT)scripts/sh/backup
UTILS_DIR := $(_ROOT)scripts/sh/utils

.PHONY: backup-all restore-all restore-interactive setup-backup-schedule update-images

backup-all: check-dependencies ## Realiza backup de todos los servicios con *_VERSION en .env [backup]
	@if [ ! -f "$(COMMANDS_DIR)/backup-all.sh" ]; then \
		$(call LOG_ERROR, Script backup-all.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" \
		$(if $(PARALLEL),PARALLEL="$(PARALLEL)",) \
		$(if $(MAX_PARALLEL),MAX_PARALLEL="$(MAX_PARALLEL)",) \
		$(if $(SKIP_MISSING),SKIP_MISSING="$(SKIP_MISSING)",) \
		bash "$(COMMANDS_DIR)/backup-all.sh" \
		$(if $(PARALLEL),--parallel,) \
		$(if $(MAX_PARALLEL),--max-parallel=$(MAX_PARALLEL),) \
		$(if $(SKIP_MISSING),--skip-missing,)

restore-all: check-dependencies ## Restaura backups de todos los servicios [backup]
	@if [ ! -f "$(COMMANDS_DIR)/restore-all.sh" ]; then \
		$(call LOG_ERROR, Script restore-all.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" BACKUP_PATH="$(BACKUP_PATH)" \
		bash "$(COMMANDS_DIR)/restore-all.sh"

restore-interactive: check-dependencies ## Restauración guiada interactiva [backup]
	@if [ -z "$(SERVICE)" ]; then \
		$(call LOG_ERROR, Debes especificar SERVICE); \
		$(call LOG_INFO, Uso: make restore-interactive SERVICE=nombre); \
		exit 1; \
	fi
	@if [ ! -f "$(BACKUP_DIR)/restore-interactive.sh" ]; then \
		$(call LOG_ERROR, Script restore-interactive.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(BACKUP_DIR)/restore-interactive.sh" "$(SERVICE)"

setup-backup-schedule: ## Configura programación automática de backups [backup]
	@if [ -z "$(FREQUENCY)" ]; then \
		$(call LOG_ERROR, Debes especificar FREQUENCY); \
		$(call LOG_INFO, Uso: make setup-backup-schedule FREQUENCY=daily); \
		$(call LOG_INFO, Frecuencias: daily weekly monthly); \
		exit 1; \
	fi
	@if [ ! -f "$(BACKUP_DIR)/setup-backup-schedule.sh" ]; then \
		$(call LOG_ERROR, Script setup-backup-schedule.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(BACKUP_DIR)/setup-backup-schedule.sh" \
		"$(FREQUENCY)" "$(SERVICES)"

update-images: check-dependencies ## Actualiza imágenes Docker de servicios [backup]
	@if [ ! -f "$(COMMANDS_DIR)/update-images.sh" ]; then \
		$(call LOG_ERROR, Script update-images.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" SERVICES="$(SERVICES)" \
		bash "$(COMMANDS_DIR)/update-images.sh" $(SERVICES)
