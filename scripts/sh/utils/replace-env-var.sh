#!/usr/bin/env bash
# ============================================================================
# Script: replace-env-var.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Reemplaza o agrega una variable de entorno en un archivo .env.
# Si la variable existe, reemplaza su valor. Si no existe, la agrega al final.
#
# Uso:
#   ./scripts/sh/utils/replace-env-var.sh <archivo.env> <VARIABLE> <valor>
#   ./scripts/sh/utils/replace-env-var.sh .env POSTGRES_VERSION 17-alpine
#
# Parámetros:
#   $1 - Ruta al archivo .env
#   $2 - Nombre de la variable (sin espacios, sin =)
#   $3 - Valor de la variable
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (opcional, para logging)
#
# Retorno:
#   0 si la operación fue exitosa
#   1 si hay errores
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_script_dir"
unset _script_dir
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"
_pr="${PROJECT_ROOT:-$(pwd)}"
readonly PROJECT_ROOT="${_pr%/}"
unset _pr

if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/logging.sh"
else
	log_info() { echo "[INFO] $*"; }
	log_warn() { echo "[WARN] $*" >&2; }
	log_error() { echo "[ERROR] $*" >&2; }
	log_success() { echo "[SUCCESS] $*"; }
	[[ -f "$COMMON_SCRIPTS_DIR/colors.sh" ]] && source "$COMMON_SCRIPTS_DIR/colors.sh"
fi

if [[ $# -ne 3 ]]; then
	log_error "Se requieren 3 argumentos"
	log_info "Uso: $0 <archivo.env> <VARIABLE> <valor>"
	log_info "Ejemplo: $0 .env POSTGRES_VERSION 17-alpine"
	exit 1
fi

readonly ENV_FILE="$1"
readonly KEY="$2"
readonly VALUE="$3"

if [[ ! -f "$ENV_FILE" ]]; then
	log_error "Archivo no encontrado: $ENV_FILE"
	exit 1
fi

# Validar que KEY no contenga caracteres inválidos
if [[ ! "$KEY" =~ ^[A-Za-z0-9_]+$ ]]; then
	log_error "Nombre de variable inválido: $KEY (solo A-Z, a-z, 0-9, _)"
	exit 1
fi

# Escapar valor para sed (básico: barras y ampersand)
ESCAPED_VALUE=$(printf '%s\n' "$VALUE" | sed 's/[[\.*^$()+?{|]/\\&/g')

if grep -qE "^${KEY}=" "$ENV_FILE" 2>/dev/null; then
	sed -i "s|^${KEY}=.*|${KEY}=${ESCAPED_VALUE}|" "$ENV_FILE"
	log_success "Variable actualizada: $KEY=$VALUE"
else
	echo "${KEY}=${VALUE}" >> "$ENV_FILE"
	log_success "Variable agregada: $KEY=$VALUE"
fi
