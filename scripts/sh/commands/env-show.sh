#!/usr/bin/env bash
# ============================================================================
# Script: env-show.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Muestra variables de entorno de .env (sanitizadas, sin secretos).
#
# Uso:
#   ./scripts/sh/commands/env-show.sh [servicio]
#
# Parámetros:
#   $1 - (opcional) Nombre del servicio para filtrar variables relacionadas
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
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

# Cargar helpers comunes
if [[ -f "$COMMON_SCRIPTS_DIR/init.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/init.sh"
	init_script
else
	_pr="${PROJECT_ROOT:-$(pwd)}"
	readonly PROJECT_ROOT="${_pr%/}"
	unset _pr
	if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
		source "$COMMON_SCRIPTS_DIR/logging.sh"
	fi
fi

# Cargar validation.sh para validar prerrequisitos
if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

readonly SERVICE_FILTER="${1:-}"
readonly ENV_FILE="$PROJECT_ROOT/.env"

# Validar que .env existe
if ! validate_env_file "$ENV_FILE"; then
	exit 1
fi

# Patrones de variables que contienen secretos (a ocultar)
readonly SECRET_PATTERNS="PASSWORD|SECRET|TOKEN|KEY|PRIVATE|CREDENTIAL"

log_info "Variables de entorno${SERVICE_FILTER:+ (filtrado: $SERVICE_FILTER)}:"
echo ""

while IFS='=' read -r line; do
	# Saltar comentarios y líneas vacías
	[[ "$line" =~ ^[[:space:]]*# ]] && continue
	[[ -z "${line// }" ]] && continue

	# Extraer nombre y valor
	VAR_NAME=$(echo "$line" | cut -d'=' -f1)
	VAR_VALUE=$(echo "$line" | cut -d'=' -f2- | sed 's/^["'\'']//;s/["'\'']$//')

	# Filtrar por servicio si se especifica
	if [[ -n "$SERVICE_FILTER" ]]; then
		SERVICE_UPPER=$(echo "$SERVICE_FILTER" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
		if ! echo "$VAR_NAME" | grep -qiE "${SERVICE_UPPER}|${SERVICE_FILTER}"; then
			continue
		fi
	fi

	# Ocultar secretos
	if echo "$VAR_NAME" | grep -qiE "$SECRET_PATTERNS"; then
		VAR_VALUE="***OCULTO***"
	fi

	log_info "  $VAR_NAME=$VAR_VALUE"
done < "$ENV_FILE"

echo ""
