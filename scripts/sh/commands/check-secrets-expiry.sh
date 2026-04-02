#!/usr/bin/env bash
# ============================================================================
# Script: check-secrets-expiry.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Verifica y alerta sobre secretos próximos a expirar o que necesitan rotación.
# Soporta múltiples formatos de metadatos de expiración.
#
# Uso:
#   ./scripts/sh/commands/check-secrets-expiry.sh [--days=30] [--warn-only]
#   make check-secrets-expiry
#
# Parámetros:
#   --days=N        - Días antes de la expiración para alertar (default: 30)
#   --warn-only     - Solo mostrar warnings, no fallar (default: false)
#   --export=FILE   - Exportar reporte a JSON
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   SECRETS_EXPIRY_DAYS - Días antes de expiración (default: 30)
#   SECRETS_EXPIRY_WARN_ONLY - Solo warnings (default: false)
#
# Retorno:
#   0 si no hay secretos próximos a expirar
#   1 si hay secretos próximos a expirar (a menos que --warn-only esté activo)
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

# Parsear argumentos
EXPIRY_DAYS="${SECRETS_EXPIRY_DAYS:-30}"
WARN_ONLY=false
EXPORT_FILE=""

for arg in "$@"; do
	case "$arg" in
		--days=*)
			EXPIRY_DAYS="${arg#*=}"
			shift
			;;
		--warn-only)
			WARN_ONLY=true
			shift
			;;
		--export=*)
			EXPORT_FILE="${arg#*=}"
			shift
			;;
		*)
			;;
	esac
done

readonly ENV_FILE="$PROJECT_ROOT/.env"
_current_date=$(date +%s)
readonly CURRENT_DATE="$_current_date"
unset _current_date

EXPIRING_SECRETS=()
EXPIRED_SECRETS=()
EXIT_CODE=0

log_step "Verificando expiración de secretos..."

if [[ ! -f "$ENV_FILE" ]]; then
	log_warn "Archivo .env no encontrado"
	exit 0
fi

# Función para calcular días hasta expiración
days_until_expiry() {
	local expiry_date="$1"
	local expiry_ts
	expiry_ts=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$expiry_date" +%s 2>/dev/null || echo "0")

	if [[ $expiry_ts -eq 0 ]]; then
		return 1
	fi

	local diff=$((expiry_ts - CURRENT_DATE))
	local days=$((diff / 86400))
	echo "$days"
}

# Buscar secretos con información de expiración
# Formatos soportados:
# - SECRET_NAME_EXPIRES=2024-12-31
# - SECRET_NAME_EXPIRY=2024-12-31
# - SECRET_NAME_ROTATE_BEFORE=2024-12-31
# - Comentarios: # EXPIRES: 2024-12-31 o # ROTATE_BEFORE: 2024-12-31

SECRET_PATTERNS="PASSWORD|SECRET|TOKEN|KEY|PRIVATE|CREDENTIAL"

# Leer el archivo .env en una copia temporal para evitar leer y buscar en el mismo archivo
# dentro del pipeline (SC2094)
ENV_FILE_COPY=$(cat "$ENV_FILE")

while IFS='=' read -r line; do
	# Saltar comentarios y líneas vacías
	[[ "$line" =~ ^[[:space:]]*# ]] && continue
	[[ -z "${line// }" ]] && continue

	VAR_NAME=$(echo "$line" | cut -d'=' -f1 | tr -d '[:space:]')

	# Verificar si es un secreto
	if ! echo "$VAR_NAME" | grep -qiE "$SECRET_PATTERNS"; then
		continue
	fi

	# Buscar fecha de expiración en variable relacionada
	EXPIRY_VAR=""
	EXPIRY_DATE=""

	# Buscar variable de expiración relacionada
	for expiry_pattern in "_EXPIRES=" "_EXPIRY=" "_ROTATE_BEFORE="; do
		EXPIRY_VAR="${VAR_NAME}${expiry_pattern}"
		if echo "$ENV_FILE_COPY" | grep -q "^${EXPIRY_VAR}" 2>/dev/null; then
			EXPIRY_DATE=$(
				echo "$ENV_FILE_COPY" | grep "^${EXPIRY_VAR}" 2>/dev/null |
					cut -d'=' -f2 | tr -d '"' | tr -d "'" | tr -d '[:space:]'
			)
			break
		fi
	done

	# Si no se encontró, buscar en comentarios anteriores
	if [[ -z "$EXPIRY_DATE" ]]; then
		VAR_LINE=$(echo "$ENV_FILE_COPY" | grep -n "^${VAR_NAME}=" 2>/dev/null | head -1 | cut -d':' -f1)
		if [[ -n "$VAR_LINE" ]] && [[ $VAR_LINE -gt 1 ]]; then
			PREV_LINE=$((VAR_LINE - 1))
			PREV_CONTENT=$(echo "$ENV_FILE_COPY" | sed -n "${PREV_LINE}p" 2>/dev/null || echo "")

			if echo "$PREV_CONTENT" | grep -qiE "EXPIRES|EXPIRY|ROTATE_BEFORE"; then
				EXPIRY_DATE=$(echo "$PREV_CONTENT" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
			fi
		fi
	fi

	# Verificar expiración si se encontró fecha
	if [[ -n "$EXPIRY_DATE" ]]; then
		DAYS_UNTIL=$(days_until_expiry "$EXPIRY_DATE" 2>/dev/null || echo "")

		if [[ -z "$DAYS_UNTIL" ]]; then
			continue
		fi

		if [[ $DAYS_UNTIL -lt 0 ]]; then
			# Ya expirado
			EXPIRED_SECRETS+=("$VAR_NAME (expirado hace $((DAYS_UNTIL * -1)) días, fecha: $EXPIRY_DATE)")
			if [[ "$WARN_ONLY" != "true" ]]; then
				EXIT_CODE=1
			fi
		elif [[ $DAYS_UNTIL -le $EXPIRY_DAYS ]]; then
			# Próximo a expirar
			EXPIRING_SECRETS+=("$VAR_NAME (expira en $DAYS_UNTIL días, fecha: $EXPIRY_DATE)")
			if [[ "$WARN_ONLY" != "true" ]] && [[ $DAYS_UNTIL -le 7 ]]; then
				EXIT_CODE=1
			fi
		fi
	fi
done <<< "$ENV_FILE_COPY"

# Mostrar resultados
if [[ ${#EXPIRED_SECRETS[@]} -gt 0 ]]; then
	log_error "Secretos expirados:"
	for secret in "${EXPIRED_SECRETS[@]}"; do
		log_error "  - $secret"
	done
	echo ""
fi

if [[ ${#EXPIRING_SECRETS[@]} -gt 0 ]]; then
	log_warn "Secretos próximos a expirar (en los próximos $EXPIRY_DAYS días):"
	for secret in "${EXPIRING_SECRETS[@]}"; do
		log_warn "  - $secret"
	done
	echo ""

	log_info "💡 Ejecuta 'make rotate-secrets' para rotar secretos"
	echo ""
fi

if [[ ${#EXPIRED_SECRETS[@]} -eq 0 ]] && [[ ${#EXPIRING_SECRETS[@]} -eq 0 ]]; then
	log_success "No hay secretos próximos a expirar"
fi

# Exportar reporte si se solicita
if [[ -n "$EXPORT_FILE" ]]; then
	mkdir -p "$(dirname "$EXPORT_FILE")" 2>/dev/null || true

	cat > "$EXPORT_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "expiry_days_threshold": $EXPIRY_DAYS,
  "expired": $(printf '%s\n' "${EXPIRED_SECRETS[@]}" | jq -R . | jq -s .),
  "expiring": $(printf '%s\n' "${EXPIRING_SECRETS[@]}" | jq -R . | jq -s .),
  "total_expired": ${#EXPIRED_SECRETS[@]},
  "total_expiring": ${#EXPIRING_SECRETS[@]}
}
EOF
	log_info "Reporte exportado a: $EXPORT_FILE"
fi

exit $EXIT_CODE
