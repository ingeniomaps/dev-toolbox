#!/usr/bin/env bash
# ============================================================================
# Script: config-show.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Muestra configuración actual del proyecto (sin secretos).
#
# Uso:
#   ./scripts/sh/commands/config-show.sh
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
_pr="${PROJECT_ROOT:-$(pwd)}"
readonly PROJECT_ROOT="${_pr%/}"
unset _pr

if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/logging.sh"
else
	log_info() { echo "[INFO] $*"; }
	log_title() { echo "=== $* ==="; }
	[[ -f "$COMMON_SCRIPTS_DIR/colors.sh" ]] && source "$COMMON_SCRIPTS_DIR/colors.sh"
fi

# Cargar validation.sh para validar prerrequisitos
if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

readonly ENV_FILE="$PROJECT_ROOT/.env"

# Patrones de variables que contienen secretos (a ocultar)
readonly SECRET_PATTERNS="PASSWORD|SECRET|TOKEN|KEY|PRIVATE|CREDENTIAL"

log_title "CONFIGURACIÓN DEL PROYECTO"
echo ""

# Validar que .env existe (opcional para este comando, solo muestra warning)
if ! validate_env_file "$ENV_FILE" 2>/dev/null; then
	log_warn ".env no encontrado, no se puede mostrar configuración"
	exit 0
fi

log_info "Variables de configuración (secretos ocultos):"
echo ""

while IFS='=' read -r line; do
	# Saltar comentarios y líneas vacías
	[[ "$line" =~ ^[[:space:]]*# ]] && continue
	[[ -z "${line// }" ]] && continue

	# Extraer nombre y valor
	VAR_NAME=$(echo "$line" | cut -d'=' -f1)
	VAR_VALUE=$(echo "$line" | cut -d'=' -f2- | sed 's/^["'\'']//;s/["'\'']$//')

	# Ocultar secretos
	if echo "$VAR_NAME" | grep -qiE "$SECRET_PATTERNS"; then
		VAR_VALUE="***OCULTO***"
	fi

	log_info "  $VAR_NAME=$VAR_VALUE"
done < "$ENV_FILE"

echo ""
