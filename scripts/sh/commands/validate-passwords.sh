#!/usr/bin/env bash
# ============================================================================
# Script: validate-passwords.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Detecta variables de contraseña en .env (_PASSWORD, _PWD, _PASS, _SECRET,
# _TOKEN, _API_KEY) y valida complejidad con validate-password-complexity.sh.
#
# Uso:
#   ./scripts/sh/commands/validate-passwords.sh
#   make validate-passwords
#
# Requisitos:
#   - .env en la raíz (si no existe, sale 0 sin error)
#   - scripts/sh/utils/validate-password-complexity.sh
#
# Retorno:
#   0 si todas las contraseñas son válidas o .env no existe
#   1 si alguna contraseña no cumple los requisitos
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Determinar directorio del script
_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_script_dir"
unset _script_dir
# Raíz del proyecto: la que origina el comando (Make pasa PROJECT_ROOT=$(CURDIR)) o pwd. Misma regla que init-env.
_pr="${PROJECT_ROOT:-$(pwd)}"
readonly PROJECT_ROOT="${_pr%/}"
unset _pr

# Cargar sistema de logging
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"
readonly UTILS_SCRIPTS_DIR="$SCRIPT_DIR/../utils"
if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/logging.sh"
fi

readonly ENV_FILE="$PROJECT_ROOT/.env"

# Verificar que .env existe
if [[ ! -f "$ENV_FILE" ]]; then
	log_warn ".env no encontrado"
	exit 0
fi

# Verificar que validate-password-complexity.sh existe
if [[ ! -f "$UTILS_SCRIPTS_DIR/validate-password-complexity.sh" ]]; then
	log_error "Script validate-password-complexity.sh no encontrado"
	exit 1
fi

log_step "Validando complejidad de contraseñas..."

EXIT_CODE=0

# Patrones para detectar variables de contraseña automaticamente.
# Usan sufijo (_PASSWORD) en vez de subcadena (PASSWORD) para evitar
# falsos positivos (ej: KEYCLOAK_URL contiene KEY pero no es password).
readonly PASSWORD_PATTERNS=(
	"_PASSWORD"
	"_PWD"
	"_PASS"
	"_SECRET"
	"_TOKEN"
	"_API_KEY"
)

# Buscar y validar todas las variables de contraseña en .env
while IFS='=' read -r var value || [[ -n "$var" ]]; do
	# Saltar comentarios y líneas vacías
	[[ "$var" =~ ^#.*$ ]] && continue
	[[ -z "${var// }" ]] && continue

	var_upper=$(echo "$var" | tr '[:lower:]' '[:upper:]')

	# Verificar si es una variable de contraseña
	is_password_var=false
	for pattern in "${PASSWORD_PATTERNS[@]}"; do
		if [[ "$var_upper" == *"$pattern"* ]]; then
			is_password_var=true
			break
		fi
	done

	if [[ "$is_password_var" == "true" ]] && [[ -n "$value" ]]; then
		if bash "$UTILS_SCRIPTS_DIR/validate-password-complexity.sh" "$value" \
			>/dev/null 2>&1; then
			log_success "$var: válida"
		else
			log_error "$var: no cumple requisitos"
			EXIT_CODE=1
		fi
	fi
done < <(grep -v '^#' "$ENV_FILE" | grep '=' || true)

if [[ $EXIT_CODE -eq 1 ]]; then
	log_warn "Algunas contraseñas no cumplen los requisitos"
	log_info "Usa: bash scripts/sh/utils/generate-password.sh [longitud] para generar contraseñas"
	exit 1
fi

exit 0
