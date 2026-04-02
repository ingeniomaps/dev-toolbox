# ============================================================================
# Monitoreo y Métricas
# ============================================================================
# Comandos para monitorear servicios, métricas, logs agregados y conectividad.
#
# Uso:
#   make metrics [SERVICES="servicio1 servicio2"]
#   make aggregate-logs [SERVICES="servicio1 servicio2"]
#   make alerts [SERVICES="servicio1 servicio2"]
#   make dashboard
#   make test-connectivity [SERVICES="servicio1 servicio2"]
#
# Variables:
#   SERVICES - Lista de servicios separados por espacios (opcional)
#   SERVICE_PREFIX - Prefijo para nombres de contenedores (opcional)
#   LOG_LEVEL_FILTER - Filtrar logs por nivel (opcional)
#   LOG_DATE_FILTER - Filtrar logs por fecha (opcional)
#   LOG_LINES_LIMIT - Límite de líneas por servicio (default: 100, max: 10000)
#   LOG_BUFFER_SIZE - Tamaño de buffer para procesamiento (default: 8192)
#   LOG_MAX_SERVICES - Máximo número de servicios a monitorear (default: 50)
#   FORMAT - Formato de exportación: json, prometheus [solo export-metrics]
#   OUTPUT - Archivo de salida [solo export-metrics]
#   AGGREGATE_LOGS_OPTS - Opciones adicionales: --limit=N, --buffer-size=N, --max-services=N, --tail-only, --no-color
# ============================================================================

_ROOT := $(or $(TOOLBOX_ROOT),$(PROJECT_ROOT))
COMMANDS_DIR := $(_ROOT)scripts/sh/commands

.PHONY: metrics aggregate-logs alerts dashboard test-connectivity export-metrics

metrics: check-dependencies ## Muestra métricas de servicios [monitoring]
	@if [ ! -f "$(COMMANDS_DIR)/metrics.sh" ]; then \
		$(call LOG_ERROR, Script metrics.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" SERVICES="$(SERVICES)" \
		bash "$(COMMANDS_DIR)/metrics.sh" $(SERVICES)

aggregate-logs: check-dependencies ## Muestra logs agregados de múltiples servicios [monitoring]
	@if [ ! -f "$(COMMANDS_DIR)/aggregate-logs.sh" ]; then \
		$(call LOG_ERROR, Script aggregate-logs.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" SERVICES="$(SERVICES)" \
		LOG_LEVEL_FILTER="$(LOG_LEVEL_FILTER)" LOG_DATE_FILTER="$(LOG_DATE_FILTER)" \
		LOG_LINES_LIMIT="$(LOG_LINES_LIMIT)" LOG_BUFFER_SIZE="$(LOG_BUFFER_SIZE)" \
		LOG_MAX_SERVICES="$(LOG_MAX_SERVICES)" \
		bash "$(COMMANDS_DIR)/aggregate-logs.sh" $(AGGREGATE_LOGS_OPTS) $(SERVICES)

alerts: check-dependencies ## Verifica estado de servicios y muestra alertas [monitoring]
	@if [ ! -f "$(COMMANDS_DIR)/alerts.sh" ]; then \
		$(call LOG_ERROR, Script alerts.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" SERVICES="$(SERVICES)" \
		bash "$(COMMANDS_DIR)/alerts.sh" $(SERVICES)

dashboard: check-dependencies ## Muestra dashboard simple del sistema [monitoring]
	@clear || true;
	@$(call LOG_TITLE, DASHBOARD DEL SISTEMA);
	@echo "";
	@$(call LOG_INFO, Estado de Servicios:);
	@$(MAKE) status 2>/dev/null || true;
	@echo "";
	@$(call LOG_INFO, Métricas:);
	@$(MAKE) metrics 2>/dev/null | head -20 || true;
	@echo "";
	@$(call LOG_INFO, Alertas:);
	@$(MAKE) alerts 2>/dev/null || true;

test-connectivity: check-dependencies ## Prueba conectividad entre servicios [monitoring]
	@if [ ! -f "$(COMMANDS_DIR)/test-connectivity.sh" ]; then \
		$(call LOG_ERROR, Script test-connectivity.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" SERVICES="$(SERVICES)" \
		bash "$(COMMANDS_DIR)/test-connectivity.sh" $(SERVICES)

export-metrics: check-dependencies ## Exporta métricas a archivo [monitoring]
	@if [ ! -f "$(COMMANDS_DIR)/export-metrics.sh" ]; then \
		$(call LOG_ERROR, Script export-metrics.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" FORMAT="$(FORMAT)" \
		OUTPUT="$(OUTPUT)" SERVICES="$(SERVICES)" \
		bash "$(COMMANDS_DIR)/export-metrics.sh" "$(FORMAT)" "$(OUTPUT)"
