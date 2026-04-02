#!/usr/bin/env bash
# ============================================================================
# Script: improved-secrets-check.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Valida que los secretos y contraseñas en archivos .env no sean inseguros.
# Verifica patrones inseguros, contraseñas débiles y complejidad.
#
# Uso:
#   ./scripts/sh/commands/improved-secrets-check.sh [archivo]
#   make secrets-check
#
# Parámetros:
#   $1 - Archivo .env a verificar (opcional, default: .env)
#
# Retorno:
#   0 si no se encontraron secretos inseguros
#   1 si se encontraron secretos inseguros
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Determinar directorio del script
_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_script_dir"
unset _script_dir
readonly PROJECT_ROOT="$SCRIPT_DIR/../../.."

# Cargar sistema de logging
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"
if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/logging.sh"
fi

ENV_FILE="${1:-$PROJECT_ROOT/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
	log_warn "Archivo $ENV_FILE no encontrado"
	exit 0
fi

log_step "Verificando secretos en $ENV_FILE..."

EXIT_CODE=0
ISSUES_FOUND=0

# Patrones de contraseñas inseguras
readonly INSECURE_PATTERNS=(
	"=admin"
	"=root"
	"=123"
	"=password"
	"=clave"
	"=admin123"
	"=admin12345"
	"=password123"
	"=qwerty"
	"=letmein"
	"=welcome"
	"=12345678"
	"=123456789"
)

# Nota: La validación de contraseñas débiles se delega a
# validate-password-complexity.sh para evitar redundancia

# Variables que deberían tener contraseñas seguras.
# Solo se matchean como sufijo o palabra completa para evitar
# falsos positivos (ej: KEYCLOAK_URL contiene KEY pero no es password).
readonly PASSWORD_VARS=(
	"_PASSWORD"
	"_PWD"
	"_PASS"
	"_SECRET"
	"_TOKEN"
	"_API_KEY"
)

# Verificar patrones inseguros
for pattern in "${INSECURE_PATTERNS[@]}"; do
	if grep -qi "$pattern" "$ENV_FILE" 2>/dev/null; then
		log_error "Se encontró patrón inseguro: $pattern"
		grep -i "$pattern" "$ENV_FILE" | sed 's/^/  /'
		ISSUES_FOUND=$((ISSUES_FOUND + 1))
		EXIT_CODE=1
	fi
done

# Verificar contraseñas débiles en variables de contraseña
while IFS='=' read -r var value || [[ -n "$var" ]]; do
	# Saltar comentarios y líneas vacías
	[[ "$var" =~ ^#.*$ ]] && continue
	[[ -z "${var// }" ]] && continue

	var_upper=$(echo "$var" | tr '[:lower:]' '[:upper:]')

	# Verificar si es una variable de contraseña
	is_password_var=false
	for pwd_var in "${PASSWORD_VARS[@]}"; do
		if [[ "$var_upper" == *"$pwd_var"* ]]; then
			is_password_var=true
			break
		fi
	done

	if [[ "$is_password_var" == "true" ]] && [[ -n "$value" ]]; then
		# Validar complejidad usando validate-password-complexity.sh
		# Este script ya valida: longitud, mayúsculas, minúsculas, números,
		# caracteres especiales y contraseñas débiles comunes
		if [[ -f "$SCRIPT_DIR/validate-password-complexity.sh" ]]; then
			if ! bash "$SCRIPT_DIR/validate-password-complexity.sh" "$value" \
				>/dev/null 2>&1; then
				log_error "Contraseña en $var no cumple requisitos de complejidad"
				log_warn "Valor: $value"
				ISSUES_FOUND=$((ISSUES_FOUND + 1))
				EXIT_CODE=1
			fi
		fi
	fi
done < <(grep -v '^#' "$ENV_FILE" | grep '=' || true)

if [[ $EXIT_CODE -eq 0 ]]; then
	log_success "No se encontraron secretos inseguros"
	exit 0
else
	log_error "Se encontraron $ISSUES_FOUND problema(s) de seguridad"
	log_info "Recomendación: Usa 'bash scripts/sh/utils/generate-password.sh [longitud]'" \
		"para generar contraseñas seguras"
	exit 1
fi
