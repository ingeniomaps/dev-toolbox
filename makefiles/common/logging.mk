# ============================================================================
# Sistema de Logging para Makefiles
# ============================================================================
# Sistema completo de logging con niveles, marcas de tiempo, colores y control
# de verbosidad para Makefiles.
#
# NOTAS DE USO:
#   - Requiere colors.mk para funcionar correctamente
#   - Usar `:=` para asignación inmediata (más eficiente)
#   - Las macros deben ser llamadas con $(call LOG_INFO, "mensaje")
#   - Las marcas de tiempo opcionales se generan con comandos shell
# ============================================================================

# ============================================================================
# Configuración del Sistema de Logging
# ============================================================================

# Nivel de logging (DEBUG, INFO, WARN, ERROR, SUCCESS)
# Puede ser sobrescrito desde línea de comandos: make LOG_LEVEL=DEBUG target
LOG_LEVEL ?= INFO

# Control de verbosidad general (true/false)
# Sobrescribe el nivel de logging si es false
VERBOSE ?= true

# Habilitar marcas de tiempo en los logs (true/false)
LOG_TIMESTAMP ?= false

# Prefijo para cada nivel de log
LOG_PREFIX_DEBUG   := [DEBUG]
LOG_PREFIX_INFO    := [INFO]
LOG_PREFIX_WARN    := [WARN]
LOG_PREFIX_ERROR   := [ERROR]
LOG_PREFIX_SUCCESS := [SUCCESS]
LOG_PREFIX_NOTE    := [NOTE]
LOG_PREFIX_STEP    := [STEP]

# Indentación base (vacía, puede ser modificada para anidación)
LOG_INDENT :=

# ============================================================================
# Orden de Prioridad de Niveles
# ============================================================================
# DEBUG < INFO < SUCCESS < WARN < ERROR
# Un nivel solo muestra mensajes de su nivel y superiores

LOG_PRIORITY_DEBUG   := 0
LOG_PRIORITY_INFO    := 1
LOG_PRIORITY_SUCCESS := 2
LOG_PRIORITY_WARN    := 3
LOG_PRIORITY_ERROR   := 4

# Determinar el nivel de prioridad actual basado en LOG_LEVEL
LOG_CURRENT_PRIORITY := $(LOG_PRIORITY_$(LOG_LEVEL))

ifeq ($(LOG_CURRENT_PRIORITY),)
  # Si el nivel no es reconocido, usar INFO por defecto
  LOG_CURRENT_PRIORITY := $(LOG_PRIORITY_INFO)
endif

# ============================================================================
# Función para obtener marca de tiempo (si está habilitado)
# ============================================================================
# Genera marca de tiempo en formato: [YYYY-MM-DD HH:MM:SS]
define get_timestamp
$(if $(filter true,$(LOG_TIMESTAMP)),$(shell date '+[%Y-%m-%d %H:%M:%S]'),)
endef

# ============================================================================
# Función auxiliar para verificar nivel de log
# ============================================================================
# Verifica si un nivel de log debe mostrarse según el nivel actual.
# Uso interno: verifica si el nivel solicitado debe mostrarse.
# Parámetro: nivel (DEBUG, INFO, SUCCESS, WARN, ERROR).
# Lógica: mostrar si VERBOSE=true y el nivel tiene prioridad suficiente.
# DEBUG(0) solo se muestra si LOG_CURRENT_PRIORITY=0
# INFO(1) se muestra si LOG_CURRENT_PRIORITY=0 o 1
# SUCCESS(2) se muestra si LOG_CURRENT_PRIORITY=0, 1, o 2
# WARN(3) se muestra si LOG_CURRENT_PRIORITY=0, 1, 2, o 3
# ERROR(4) siempre se muestra si VERBOSE=true
define should_log
$(if $(filter true,$(VERBOSE)),\
  $(if $(filter DEBUG,$(1)),\
    $(if $(filter 0,$(LOG_CURRENT_PRIORITY)),true,false),\
    $(if $(filter INFO,$(1)),\
      $(if $(filter 0 1,$(LOG_CURRENT_PRIORITY)),true,false),\
      $(if $(filter SUCCESS,$(1)),\
        $(if $(filter 0 1 2,$(LOG_CURRENT_PRIORITY)),true,false),\
        $(if $(filter WARN,$(1)),\
          $(if $(filter 0 1 2 3,$(LOG_CURRENT_PRIORITY)),true,false),\
          $(if $(filter ERROR,$(1)),true,false)\
        )\
      )\
    )\
  ),\
  false\
)
endef

# ============================================================================
# Logging - Nivel DEBUG
# ============================================================================
# Mensajes detallados para depuración
# Uso: $(call LOG_DEBUG, "mensaje de depuración")
define LOG_DEBUG
$(if $(filter true,$(call should_log,DEBUG)),\
  echo "$(LOG_INDENT)$(call get_timestamp)$(COLOR_BRIGHT_BLACK)$(LOG_PREFIX_DEBUG)$(COLOR_RESET) "\
       "$(COLOR_BLUE)$(1)$(COLOR_RESET)",\
)
endef

# ============================================================================
# Logging - Nivel INFO
# ============================================================================
# Mensajes informativos generales
# Uso: $(call LOG_INFO, "mensaje informativo")
define LOG_INFO
$(if $(filter true,$(call should_log,INFO)),\
  echo "$(LOG_INDENT)$(call get_timestamp)$(COLOR_BRIGHT_BLUE)$(LOG_PREFIX_INFO)$(COLOR_RESET) "\
       "$(COLOR_BRIGHT_WHITE)$(1)$(COLOR_RESET)",\
)
endef

# ============================================================================
# Logging - Nivel SUCCESS
# ============================================================================
# Mensajes de éxito y operaciones completadas
# Uso: $(call LOG_SUCCESS, "operación completada")
define LOG_SUCCESS
$(if $(filter true,$(call should_log,SUCCESS)),\
  echo "$(LOG_INDENT)$(call get_timestamp)$(COLOR_BRIGHT_GREEN)$(LOG_PREFIX_SUCCESS)$(COLOR_RESET) "\
       "$(COLOR_GREEN)$(1)$(COLOR_RESET)",\
)
endef

# ============================================================================
# Logging - Nivel WARN
# ============================================================================
# Mensajes de advertencia (siempre se muestran si VERBOSE=true)
# Uso: $(call LOG_WARN, "advertencia")
define LOG_WARN
$(if $(filter true,$(VERBOSE)),\
  echo "$(LOG_INDENT)$(call get_timestamp)$(COLOR_BRIGHT_YELLOW)$(LOG_PREFIX_WARN)$(COLOR_RESET) "\
       "$(COLOR_YELLOW)$(1)$(COLOR_RESET)" >&2,\
)
endef

# ============================================================================
# Logging - Nivel ERROR
# ============================================================================
# Mensajes de error (siempre se muestran si VERBOSE=true)
# Uso: $(call LOG_ERROR, "error")
define LOG_ERROR
echo "$(LOG_INDENT)$(call get_timestamp)$(COLOR_BRIGHT_RED)$(LOG_PREFIX_ERROR)$(COLOR_RESET) "\
     "$(COLOR_RED)$(1)$(COLOR_RESET)" >&2
endef

# ============================================================================
# Logging - Nivel NOTE
# ============================================================================
# Notas y mensajes neutrales
# Uso: $(call LOG_NOTE, "nota")
define LOG_NOTE
$(if $(filter true,$(VERBOSE)),\
  echo "$(LOG_INDENT)$(call get_timestamp)$(COLOR_BRIGHT_WHITE)$(LOG_PREFIX_NOTE)$(COLOR_RESET) "\
       "$(COLOR_WHITE)$(1)$(COLOR_RESET)",\
)
endef

# ============================================================================
# Logging - Nivel STEP
# ============================================================================
# Pasos y secciones (formato especial para comandos)
# Uso: $(call LOG_STEP, "Paso 1: Configurando...")
define LOG_STEP
$(if $(filter true,$(VERBOSE)),\
  echo "$(LOG_INDENT)$(call get_timestamp)$(COLOR_BRIGHT_CYAN)$(LOG_PREFIX_STEP)$(COLOR_RESET) "\
       "$(COLOR_CYAN)$(1)$(COLOR_RESET)",\
)
endef

# ============================================================================
# Funciones de Formato Especial
# ============================================================================

# Separador visual para secciones
# Uso: $(call LOG_SEPARATOR)
define LOG_SEPARATOR
$(if $(filter true,$(VERBOSE)),\
  echo "$(COLOR_BRIGHT_BLACK)$(shell printf '=%.0s' {1..80})$(COLOR_RESET)",\
)
endef

# Título de sección
# Uso: $(call LOG_TITLE, "Título de Sección")
define LOG_TITLE
$(if $(filter true,$(VERBOSE)),\
  echo ""; \
  echo "$(COLOR_BRIGHT_CYAN)$(shell printf '=%.0s' {1..80})$(COLOR_RESET)"; \
  echo "$(COLOR_BRIGHT_CYAN)$(LOG_PREFIX_STEP) $(COLOR_BRIGHT_WHITE)$(1)$(COLOR_RESET)"; \
  echo "$(COLOR_BRIGHT_CYAN)$(shell printf '=%.0s' {1..80})$(COLOR_RESET)"; \
  echo "",\
)
endef

# Mensaje con formato de comando ejecutándose
# Uso: $(call LOG_CMD, "comando a ejecutar")
define LOG_CMD
$(if $(filter true,$(VERBOSE)),\
  echo "$(LOG_INDENT)$(COLOR_BRIGHT_BLACK)$>$ $(COLOR_CYAN)$(1)$(COLOR_RESET)",\
)
endef

# Mensaje vacío (línea en blanco para formato)
# Uso: $(call LOG_BLANK)
define LOG_BLANK
$(if $(filter true,$(VERBOSE)),\
  echo "",\
)
endef

# ============================================================================
# Funciones de Indentación (para Logs Anidados)
# ============================================================================

# Incrementar indentación (agrega 2 espacios)
# Uso: LOG_INDENT := $(LOG_INDENT)$(INDENT_SPACE)
INDENT_SPACE := "  "

# Log con indentación personalizada
# Uso: $(call LOG_INFO_INDENT, "  ", "mensaje")
define LOG_INFO_INDENT
$(if $(filter true,$(call should_log,INFO)),\
  echo "$(2)$(COLOR_BRIGHT_BLUE)$(LOG_PREFIX_INFO)$(COLOR_RESET) $(COLOR_BRIGHT_WHITE)$(1)$(COLOR_RESET)",\
)
endef

# ============================================================================
# Funciones de Verificación y Estado
# ============================================================================

# Mostrar estado de configuración del logger
# Uso: $(call LOG_SHOW_CONFIG)
define LOG_SHOW_CONFIG
echo "$(COLOR_BRIGHT_CYAN)=== Configuración del Sistema de Logging ===$(COLOR_RESET)"
echo "  Nivel de Log:    $(COLOR_BRIGHT_WHITE)$(LOG_LEVEL)$(COLOR_RESET)"
echo "  Verboso:         $(COLOR_BRIGHT_WHITE)$(VERBOSE)$(COLOR_RESET)"
echo "  Marcas de tiempo: $(COLOR_BRIGHT_WHITE)$(LOG_TIMESTAMP)$(COLOR_RESET)"
echo "  Prioridad Actual: $(COLOR_BRIGHT_WHITE)$(LOG_CURRENT_PRIORITY)$(COLOR_RESET)"
endef

# ============================================================================
# Aliases y Compatibilidad hacia atrás
# ============================================================================
# Mantener compatibilidad con el sistema anterior (messages.mk)
# Estas macros tienen la misma interfaz que las originales MSG_*

# MSG_INFO - Información general (compatible con sistema anterior)
define MSG_INFO
$(if $(filter true,$(VERBOSE)),\
  echo "$(COLOR_BRIGHT_BLUE)[INFO]$(COLOR_RESET) $(COLOR_BRIGHT_WHITE)$(1)$(COLOR_RESET)",\
)
endef

# MSG_OK - Mensaje de éxito (compatible con sistema anterior)
define MSG_OK
$(if $(filter true,$(VERBOSE)),\
  echo "$(COLOR_BRIGHT_GREEN)[SUCCESS]$(COLOR_RESET) $(COLOR_GREEN)$(1)$(COLOR_RESET)",\
)
endef

# MSG_WARN - Advertencia (compatible con sistema anterior)
define MSG_WARN
$(if $(filter true,$(VERBOSE)),\
  echo "$(COLOR_BRIGHT_YELLOW)[WARN]$(COLOR_RESET) $(COLOR_YELLOW)$(1)$(COLOR_RESET)" >&2,\
)
endef

# MSG_ERR - Error (compatible con sistema anterior)
define MSG_ERR
echo "$(COLOR_BRIGHT_RED)[ERROR]$(COLOR_RESET) $(COLOR_RED)$(1)$(COLOR_RESET)" >&2
endef

# MSG_NOTE - Nota neutral (compatible con sistema anterior)
define MSG_NOTE
$(if $(filter true,$(VERBOSE)),\
  echo "$(COLOR_BRIGHT_WHITE)[NOTE]$(COLOR_RESET) $(COLOR_WHITE)$(1)$(COLOR_RESET)",\
)
endef

# ============================================================================
# Ejemplos de Uso
# ============================================================================
#
# # Ejemplo básico:
# $(call LOG_INFO, "Iniciando proceso de construcción")
# $(call LOG_SUCCESS, "Construcción completada")
# $(call LOG_WARN, "Esta operación puede tardar varios minutos")
# $(call LOG_ERROR, "Error al procesar archivo")
# $(call LOG_DEBUG, "Variable DEBUG_VAR = $(DEBUG_VAR)")
#
# # Ejemplo con marcas de tiempo (LOG_TIMESTAMP=true):
# LOG_TIMESTAMP := true
# $(call LOG_INFO, "Mensaje con marca de tiempo")
#
# # Ejemplo con secciones:
# $(call LOG_TITLE, "Configuración del Entorno")
# $(call LOG_STEP, "Cargando variables de entorno...")
# $(call LOG_SEPARATOR)
#
# # Ejemplo con comandos:
# $(call LOG_CMD, "docker build -t myapp .")
#
# # Ejemplo con nivel de log (desde línea de comandos):
# # make LOG_LEVEL=DEBUG target
#
# # Ejemplo deshabilitando verbosidad:
# # make VERBOSE=false target
#
# ============================================================================
