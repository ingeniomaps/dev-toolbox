#!/usr/bin/env bash
# ============================================================================
# Script: validate-ips.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Valida que las IPs en .env tengan formato IPv4. Busca _HOST, _IP, NETWORK_IP.
#
# Uso:
#   ./scripts/sh/commands/validate-ips.sh [archivo_env]
#   make validate-ips
#
# Parámetros:
#   $1 - Archivo .env a validar (opcional). Por defecto: PROJECT_ROOT/.env o $(pwd)/.env
#        Make y validate.sh pasan la ruta desde el directorio que origina el comando (CURDIR).
#
# Retorno:
#   0 si todas las IPs son válidas
#   1 si alguna IP es inválida
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Determinar directorio del script para cargar dependencias
_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_script_dir"
unset _script_dir

# Cargar sistema de logging (ruta absoluta para evitar fallos al invocarse desde otros scripts)
_common_scripts_dir="$(cd "$SCRIPT_DIR/../common" && pwd)"
readonly COMMON_SCRIPTS_DIR="$_common_scripts_dir"
unset _common_scripts_dir
if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
	# shellcheck source=../common/logging.sh
	source "$COMMON_SCRIPTS_DIR/logging.sh"
fi
# Fallback si logging no se cargó (p. ej. ruta distinta al invocar desde commands/)
if ! type log_info &>/dev/null; then
	log_info() { echo "[INFO] $*" >&2; }
	log_warn() { echo "[WARN] $*" >&2; }
	log_error() { echo "[ERROR] $*" >&2; }
	log_success() { echo "[SUCCESS] $*" >&2; }
fi

# .env: $1 si se pasa; si no, directorio que origina el comando (PROJECT_ROOT o pwd). Misma regla que init-env.
ENV_FILE="${1:-${PROJECT_ROOT:-$(pwd)}/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
	log_warn "Archivo $ENV_FILE no encontrado"
	exit 0
fi

log_info "Validando formato de IPs en $ENV_FILE..."

EXIT_CODE=0

# Extraer valores de IP de variables que terminan en _HOST, _IP o NETWORK_IP
# Ignorar comentarios y líneas vacías
IP_VARS=$(grep -E ".*_HOST=|.*_IP=|NETWORK_IP=" "$ENV_FILE" 2>/dev/null | \
	grep -v '^[[:space:]]*#' | cut -d'=' -f2- | tr -d ' ' || true)

if [[ -z "$IP_VARS" ]]; then
	log_warn "No se encontraron variables de IP para validar"
	exit 0
fi

# Función para validar formato de IP IPv4
validate_ip() {
	local ip="$1"
	# Regex para validar IPv4 (formato: xxx.xxx.xxx.xxx)
	if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
		# Verificar que cada octeto esté entre 0-255
		IFS='.' read -ra ADDR <<< "$ip"
		for i in "${ADDR[@]}"; do
			# Validar que es un número válido y está en rango
			if ! [[ "$i" =~ ^[0-9]+$ ]] || [[ "$i" -gt 255 ]] || [[ "$i" -lt 0 ]]; then
				return 1
			fi
		done
		return 0
	else
		return 1
	fi
}

# Validar cada IP encontrada
for ip in $IP_VARS; do
	# Ignorar valores vacíos
	if [[ -z "$ip" ]]; then
		continue
	fi

	# Eliminar comillas si están presentes
	ip="${ip%\"}"
	ip="${ip#\"}"
	ip="${ip%\'}"
	ip="${ip#\'}"

	if validate_ip "$ip"; then
		log_success "IP válida: $ip"
	else
		log_error "IP inválida: $ip"
		EXIT_CODE=1
	fi
done

if [[ $EXIT_CODE -eq 0 ]]; then
	log_success "Todas las IPs son válidas"
	exit 0
else
	log_error "Algunas IPs son inválidas"
	exit 1
fi
