#!/usr/bin/env bash
# ============================================================================
# Script: check-ports.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Verifica si los puertos necesarios están disponibles (netstat, ss o lsof).
#
# Uso:
#   make check-ports [PORTS="1 2 3"]
#   ./scripts/sh/commands/check-ports.sh [puerto1] [puerto2] ...
#
# Parámetros:
#   $@ - Puertos a verificar (opcional, si no se especifican usa puertos
#        por defecto: 5432 27017 6379 80 8081 5540)
#
# Retorno:
#   0 si todos los puertos están disponibles
#   1 si algún puerto está en uso
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Determinar directorio del script para cargar dependencias
_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_script_dir"
unset _script_dir

# Cargar sistema de logging
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"
if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/logging.sh"
fi

# Puertos por defecto si no se especifican
readonly DEFAULT_PORTS="5432 27017 6379 80 8081 5540"
PORTS_TO_CHECK="${*:-$DEFAULT_PORTS}"

EXIT_CODE=0

log_info "Verificando disponibilidad de puertos..."

# Función para verificar si un puerto está en uso
check_port_available() {
	local port="$1"

	# Intentar usar netstat (más común en sistemas antiguos)
	if command -v netstat >/dev/null 2>&1; then
		if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
			return 1  # Puerto en uso
		fi
		return 0  # Puerto disponible
	# Intentar usar ss (más moderno, reemplazo de netstat)
	elif command -v ss >/dev/null 2>&1; then
		if ss -tuln 2>/dev/null | grep -q ":${port} "; then
			return 1  # Puerto en uso
		fi
		return 0  # Puerto disponible
	# Intentar usar lsof (disponible en macOS y algunos Linux)
	elif command -v lsof >/dev/null 2>&1; then
		if lsof -i ":${port}" >/dev/null 2>&1; then
			return 1  # Puerto en uso
		fi
		return 0  # Puerto disponible
	else
		log_warn "No se encontró herramienta para verificar puertos" \
			"(netstat, ss, o lsof)"
		return 2  # Error: no hay herramienta disponible
	fi
}

# Verificar cada puerto
for port in $PORTS_TO_CHECK; do
	# Validar que el puerto sea un número válido
	if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || \
		[[ "$port" -gt 65535 ]]; then
		log_warn "Puerto inválido ignorado: $port (debe estar entre 1-65535)"
		continue
	fi

	if check_port_available "$port"; then
		log_success "Puerto $port está disponible"
	else
		exit_code_check=$?
		if [[ $exit_code_check -eq 2 ]]; then
			# Error: no hay herramienta disponible, salir
			exit 1
		else
			# Puerto en uso
			log_error "Puerto $port está en uso"
			EXIT_CODE=1
		fi
	fi
done

if [[ $EXIT_CODE -eq 0 ]]; then
	log_success "Todos los puertos están disponibles"
	exit 0
else
	log_error "Algunos puertos están en uso"
	exit 1
fi
