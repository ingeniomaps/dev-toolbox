# Detecta automáticamente la raíz del proyecto
PROJECT_ROOT := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
TOOLBOX_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# No mostrar "se entra/se sale del directorio" en submakes
MAKEFLAGS += --no-print-directory

# Cargar primero los .mk comunes (requeridos por los main)
include $(TOOLBOX_ROOT)makefiles/common/colors.mk
include $(TOOLBOX_ROOT)makefiles/common/logging.mk

# Cargar todos los .mk de makefiles/main/
# (MAIN_MK en vez de MAKEFILES para no chocar con la variable especial de Make
#  que provoca relecturas y advertencias "se anulan las instrucciones")
MAIN_MK := $(wildcard $(TOOLBOX_ROOT)makefiles/main/*.mk)
include $(MAIN_MK)

# Exporta la raíz para los archivos .mk
export PROJECT_ROOT

# Carga el .env si existe
ifneq (,$(wildcard .env))
	include .env
	export $(shell sed 's/=.*//' .env)
endif

## COMANDOS
.DEFAULT_GOAL := help-toolbox

help-toolbox: ## Muestra esta ayuda [main]
	@HELP_CATS="\
	main:Comandos Principales,\
	validation:Validación de Configuración,\
	security:Gestión de Seguridad,\
	load:Infisical y Herramientas,\
	tool:Gestión de Versiones,\
	monitoring:Monitoreo y Métricas,\
	backup:Backups y Restauraciones,\
	ci-cd:Integración CI/CD" \
	awk -f "$(TOOLBOX_ROOT)/awk/help.awk" \
	$(MAKEFILE_LIST) $(MAIN_MK)

# === Comandos ocultos ===

network-tool: init-env ## Crea o verifica la red Docker [tool]
	@if [ -f "$(PROJECT_ROOT).env" ]; then \
		if [ "$(RECREATE)" = "true" ]; then \
			bash $(TOOLBOX_ROOT)scripts/sh/utils/ensure-network.sh --recreate; \
		else \
			bash $(TOOLBOX_ROOT)scripts/sh/utils/ensure-network.sh; \
		fi \
	fi

sleep-tool:
	@sleep 5
