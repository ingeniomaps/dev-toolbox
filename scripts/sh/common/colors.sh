#!/usr/bin/env bash
# ============================================================================
# colors.sh
# Ubicación: scripts/sh/common/
# ============================================================================
# Define variables de color ANSI para scripts Bash. Se desactivan si no hay
# terminal (stdout o stderr).
#
# Uso:
#   source "$COMMON_SCRIPTS_DIR/colors.sh"
#   # Donde COMMON_SCRIPTS_DIR apunta a scripts/sh/common (ej. SCRIPT_DIR/../common)
#
# Variables exportadas (grupos):
#   - Semánticos: COLOR_RESET, COLOR_ERROR, COLOR_INFO, COLOR_OK, COLOR_WARN
#   - Básicos: COLOR_BLACK, COLOR_RED, COLOR_GREEN, COLOR_YELLOW, COLOR_BLUE,
#     COLOR_PURPLE, COLOR_CYAN, COLOR_WHITE
#   - Brillantes: COLOR_BRIGHT_* (mismo sufijo)
#   - Especiales: COLOR_TITLE, COLOR_CMD, COLOR_DEPRECATED
#
# NOTAS:
#   - Cerrar siempre con COLOR_RESET. Usar echo -e para secuencias de escape.
#   - Carga segura múltiples veces (COLORS_LOADED).
#   - FORCE_COLOR=1: activar colores aunque stdout/stderr no sean TTY (p. ej. al llamar desde make).
# ============================================================================

# Evitar cargar múltiples veces si las variables ya están definidas
if [[ -n "${COLORS_LOADED:-}" ]]; then
	return 0
fi

# Verificar si hay terminal disponible (stdout O stderr) o si se pide forzar color.
# FORCE_COLOR=1 se usa cuando make (u otro) invoca scripts en subprocesos donde -t puede ser falso.
if [[ -t 1 ]] || [[ -t 2 ]] || [[ "${FORCE_COLOR:-0}" == "1" ]]; then
	# ============================================================================
	# Control y Reset
	# ============================================================================
	export COLOR_RESET='\033[0m'

	# ============================================================================
	# Colores Semánticos (Recomendados para uso general)
	# ============================================================================
	export COLOR_ERROR='\033[1;31m'  # Rojo brillante para errores
	export COLOR_INFO='\033[1;34m'   # Azul brillante para información
	export COLOR_OK='\033[1;32m'     # Verde brillante para éxito
	export COLOR_WARN='\033[1;33m'   # Amarillo brillante para advertencias

	# ============================================================================
	# Colores Básicos (Intensidad Normal)
	# ============================================================================
	export COLOR_BLACK='\033[0;30m'
	export COLOR_RED='\033[0;31m'
	export COLOR_GREEN='\033[0;32m'
	export COLOR_YELLOW='\033[0;33m'
	export COLOR_BLUE='\033[0;34m'
	export COLOR_PURPLE='\033[0;35m'
	export COLOR_CYAN='\033[0;36m'
	export COLOR_WHITE='\033[0;37m'

	# ============================================================================
	# Colores Brillantes (Intensidad Alta)
	# ============================================================================
	export COLOR_BRIGHT_BLACK='\033[1;30m'
	export COLOR_BRIGHT_RED='\033[1;31m'
	export COLOR_BRIGHT_GREEN='\033[1;32m'
	export COLOR_BRIGHT_YELLOW='\033[1;33m'
	export COLOR_BRIGHT_BLUE='\033[1;34m'
	export COLOR_BRIGHT_PURPLE='\033[1;35m'
	export COLOR_BRIGHT_CYAN='\033[1;36m'
	export COLOR_BRIGHT_WHITE='\033[1;37m'

	# ============================================================================
	# Colores Especiales para Sistema de Ayuda y Logging
	# ============================================================================
	export COLOR_TITLE='\033[1m'      # Negrita (sin color específico)
	export COLOR_CMD='\033[36m'       # Cyan (alias de COLOR_CYAN)
	export COLOR_DEPRECATED='\033[1;33m'  # Amarillo brillante (alias de COLOR_WARN)

	# Hacer todas las variables readonly después de exportarlas
	readonly COLOR_RESET
	readonly COLOR_ERROR COLOR_INFO COLOR_OK COLOR_WARN
	readonly COLOR_BLACK COLOR_RED COLOR_GREEN COLOR_YELLOW
	readonly COLOR_BLUE COLOR_PURPLE COLOR_CYAN COLOR_WHITE
	readonly COLOR_BRIGHT_BLACK COLOR_BRIGHT_RED COLOR_BRIGHT_GREEN
	readonly COLOR_BRIGHT_YELLOW COLOR_BRIGHT_BLUE COLOR_BRIGHT_PURPLE
	readonly COLOR_BRIGHT_CYAN COLOR_BRIGHT_WHITE
	readonly COLOR_TITLE COLOR_CMD COLOR_DEPRECATED
else
	# Desactivar todos los colores si no hay terminal (para redirecciones y pipes)
	export COLOR_RESET=''

	# Colores semánticos
	export COLOR_ERROR=''
	export COLOR_INFO=''
	export COLOR_OK=''
	export COLOR_WARN=''

	# Colores básicos
	export COLOR_BLACK=''
	export COLOR_RED=''
	export COLOR_GREEN=''
	export COLOR_YELLOW=''
	export COLOR_BLUE=''
	export COLOR_PURPLE=''
	export COLOR_CYAN=''
	export COLOR_WHITE=''

	# Colores brillantes
	export COLOR_BRIGHT_BLACK=''
	export COLOR_BRIGHT_RED=''
	export COLOR_BRIGHT_GREEN=''
	export COLOR_BRIGHT_YELLOW=''
	export COLOR_BRIGHT_BLUE=''
	export COLOR_BRIGHT_PURPLE=''
	export COLOR_BRIGHT_CYAN=''
	export COLOR_BRIGHT_WHITE=''

	# Colores especiales
	export COLOR_TITLE=''
	export COLOR_CMD=''
	export COLOR_DEPRECATED=''

	# Hacer todas las variables readonly
	readonly COLOR_RESET
	readonly COLOR_ERROR COLOR_INFO COLOR_OK COLOR_WARN
	readonly COLOR_BLACK COLOR_RED COLOR_GREEN COLOR_YELLOW
	readonly COLOR_BLUE COLOR_PURPLE COLOR_CYAN COLOR_WHITE
	readonly COLOR_BRIGHT_BLACK COLOR_BRIGHT_RED COLOR_BRIGHT_GREEN
	readonly COLOR_BRIGHT_YELLOW COLOR_BRIGHT_BLUE COLOR_BRIGHT_PURPLE
	readonly COLOR_BRIGHT_CYAN COLOR_BRIGHT_WHITE
	readonly COLOR_TITLE COLOR_CMD COLOR_DEPRECATED
fi

# Marcar como cargado (no exportar: los hijos deben cargar de nuevo para tener las variables)
COLORS_LOADED=1
readonly COLORS_LOADED
