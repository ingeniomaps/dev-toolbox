# ============================================================================
# Gestión de Servicios
# ============================================================================
# Comandos para gestionar servicios Docker: logs, restart, limpieza.
#
# Uso:
#   make logs SERVICE=postgres
#   make restart SERVICE=postgres
#   make clean
#
# Variables:
#   SERVICE - Nombre del servicio (requerido para logs, restart, shell, exec, rebuild)
#   SERVICES - Lista de servicios separados por espacios (opcional)
#   SERVICE_PREFIX - Prefijo para nombres de contenedores (opcional)
#   SHELL - Comando shell a usar (default: /bin/bash o /bin/sh) [solo shell]
#   CMD - Comando a ejecutar [solo exec]
#   PRUNE_ALL - Usar --all para limpieza completa [solo prune]
#   BUILD_ARGS - Argumentos adicionales para docker build [solo build, rebuild]
# ============================================================================

_ROOT := $(or $(TOOLBOX_ROOT),$(PROJECT_ROOT))
COMMANDS_DIR := $(_ROOT)scripts/sh/commands
UTILS_DIR := $(_ROOT)scripts/sh/utils

.PHONY: logs restart clean start stop shell exec up down ps prune \
	build rebuild clean-volumes clean-images clean-networks

start: check-dependencies ## Inicia uno o más servicios [main]
	@if [ ! -f "$(COMMANDS_DIR)/start.sh" ]; then \
		$(call LOG_ERROR, Script start.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" SERVICES="$(SERVICES)" \
		bash "$(COMMANDS_DIR)/start.sh" $(SERVICES) $(SERVICE)

stop: check-dependencies ## Detiene uno o más servicios [main]
	@if [ ! -f "$(COMMANDS_DIR)/stop.sh" ]; then \
		$(call LOG_ERROR, Script stop.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" SERVICES="$(SERVICES)" \
		bash "$(COMMANDS_DIR)/stop.sh" $(SERVICES) $(SERVICE)

up: start ## Alias de start (levanta servicios) [main]

down: stop ## Alias de stop (baja servicios) [main]

shell: check-dependencies ## Abre shell interactivo en un contenedor [main]
	@if [ -z "$(SERVICE)" ]; then \
		$(call LOG_ERROR, Debes especificar SERVICE); \
		$(call LOG_INFO, Uso: make shell SERVICE=nombre [SHELL=/bin/bash]); \
		exit 1; \
	fi
	@if [ ! -f "$(COMMANDS_DIR)/shell.sh" ]; then \
		$(call LOG_ERROR, Script shell.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(COMMANDS_DIR)/shell.sh" \
		"$(SERVICE)" "$(SHELL)"

exec: check-dependencies ## Ejecuta comando en un contenedor [main]
	@if [ -z "$(SERVICE)" ] || [ -z "$(CMD)" ]; then \
		$(call LOG_ERROR, Debes especificar SERVICE y CMD); \
		$(call LOG_INFO, Uso: make exec SERVICE=nombre CMD=comando); \
		exit 1; \
	fi
	@if [ ! -f "$(COMMANDS_DIR)/exec.sh" ]; then \
		$(call LOG_ERROR, Script exec.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(COMMANDS_DIR)/exec.sh" \
		"$(SERVICE)" $(CMD)

ps: check-dependencies ## Lista servicios con detalles (mejora de status) [main]
	@docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" \
		2>/dev/null || $(call LOG_INFO, "No hay contenedores corriendo")

logs: check-dependencies ## Muestra logs de un servicio [main]
	@if [ -z "$(SERVICE)" ]; then \
		$(call LOG_ERROR, Debes especificar SERVICE); \
		$(call LOG_INFO, Uso: make logs SERVICE=nombre); \
		exit 1; \
	fi
	@if [ -z "$(SERVICE_PREFIX)" ]; then \
		CONTAINER_NAME="$(SERVICE)"; \
	else \
		CONTAINER_NAME="$(SERVICE_PREFIX)-$(SERVICE)"; \
	fi
	@if docker ps --format '{{.Names}}' | grep -q "^$$CONTAINER_NAME$$"; then \
		$(call LOG_INFO, Logs de $$CONTAINER_NAME:); \
		docker logs -f $$CONTAINER_NAME; \
	else \
		$(call LOG_ERROR, Contenedor $$CONTAINER_NAME no está corriendo); \
		exit 1; \
	fi

restart: check-dependencies ## Reinicia un servicio [main]
	@if [ -z "$(SERVICE)" ]; then \
		$(call LOG_ERROR, Debes especificar SERVICE); \
		$(call LOG_INFO, Uso: make restart SERVICE=nombre); \
		exit 1; \
	fi
	@$(call LOG_STEP, Reiniciando servicio $(SERVICE)...);
	@$(MAKE) down-$(SERVICE) || { \
		$(call LOG_ERROR, Falló al detener $(SERVICE)); \
		exit 1; \
	}
	@$(MAKE) up-$(SERVICE) || { \
		$(call LOG_ERROR, Falló al iniciar $(SERVICE)); \
		exit 1; \
	}
	@$(call LOG_SUCCESS, "Servicio $(SERVICE) reiniciado correctamente");

clean: check-dependencies ## Limpieza completa (detiene contenedores, volúmenes y redes) [main]
	@if [ ! -f "$(COMMANDS_DIR)/clean.sh" ]; then \
		$(call LOG_ERROR, Script clean.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(COMMANDS_DIR)/clean.sh"

clean-volumes: check-dependencies ## Limpia solo volúmenes Docker [main]
	@if [ ! -f "$(COMMANDS_DIR)/clean-volumes.sh" ]; then \
		$(call LOG_ERROR, Script clean-volumes.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" VOLUMES="$(VOLUMES)" \
		bash "$(COMMANDS_DIR)/clean-volumes.sh" $(VOLUMES)

clean-images: check-dependencies ## Limpia solo imágenes Docker [main]
	@if [ ! -f "$(COMMANDS_DIR)/clean-images.sh" ]; then \
		$(call LOG_ERROR, Script clean-images.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(COMMANDS_DIR)/clean-images.sh" "$(CLEAN_DANGLING)"

clean-networks: check-dependencies ## Limpia solo redes Docker [main]
	@if [ ! -f "$(COMMANDS_DIR)/clean-networks.sh" ]; then \
		$(call LOG_ERROR, Script clean-networks.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(COMMANDS_DIR)/clean-networks.sh"

prune: check-dependencies ## Limpieza inteligente de recursos no usados [main]
	@if [ ! -f "$(COMMANDS_DIR)/prune.sh" ]; then \
		$(call LOG_ERROR, Script prune.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(COMMANDS_DIR)/prune.sh" "$(PRUNE_ALL)"

build: check-dependencies ## Construye imágenes Docker de servicios [main]
	@if [ ! -f "$(COMMANDS_DIR)/build.sh" ]; then \
		$(call LOG_ERROR, Script build.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" SERVICES="$(SERVICES)" \
		BUILD_ARGS="$(BUILD_ARGS)" bash "$(COMMANDS_DIR)/build.sh" $(SERVICES) $(SERVICE)

rebuild: check-dependencies ## Reconstruye y reinicia servicios [main]
	@if [ -z "$(SERVICE)" ] && [ -z "$(SERVICES)" ]; then \
		$(call LOG_ERROR, Debes especificar SERVICE o servicios); \
		$(call LOG_INFO, Uso: make rebuild SERVICE=nombre); \
		exit 1; \
	fi
	@if [ ! -f "$(COMMANDS_DIR)/rebuild.sh" ]; then \
		$(call LOG_ERROR, Script rebuild.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" SERVICE="$(SERVICE)" \
		SERVICES="$(SERVICES)" BUILD_ARGS="$(BUILD_ARGS)" \
		bash "$(COMMANDS_DIR)/rebuild.sh" $(SERVICES) $(SERVICE)
