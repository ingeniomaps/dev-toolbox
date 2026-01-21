#!/usr/bin/env bash
# ============================================================================
# Script: rotate-secrets.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Rota secretos automáticamente (genera nuevos valores y actualiza .env).
#
# Uso:
#   ./scripts/sh/commands/rotate-secrets.sh [servicio]
#
# Parámetros:
#   $1 - (opcional) Nombre del servicio para rotar secretos específicos
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   SECRET_VARS - Variables a rotar (separadas por espacios, opcional)
#
# Retorno:
#   0 si la rotación fue exitosa
#   1 si hay errores
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_script_dir"
unset _script_dir
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"
readonly UTILS_DIR="$SCRIPT_DIR/../utils"

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

readonly SERVICE="${1:-}"
readonly ENV_FILE="$PROJECT_ROOT/.env"

# Validar que .env existe
if ! validate_env_file "$ENV_FILE"; then
	exit 1
fi

# Cargar script de generación de contraseñas si está disponible
if [[ -f "$UTILS_DIR/generate-password.sh" ]]; then
	source "$UTILS_DIR/generate-password.sh"
fi

log_warn "ADVERTENCIA: Esto generará nuevos secretos y actualizará .env"
log_info "Se recomienda hacer backup del .env antes de continuar"

printf '%b' "${COLOR_INFO:-}¿Continuar? (s/N): ${COLOR_RESET:-}"
read -r CONFIRM

if [[ "$CONFIRM" != "s" ]] && [[ "$CONFIRM" != "S" ]]; then
	log_info "Operación cancelada"
	exit 0
fi

log_step "Rotando secretos..."

# Detectar variables de secretos
SECRET_PATTERNS="PASSWORD|SECRET|TOKEN|KEY|PRIVATE|CREDENTIAL"
ROTATED_COUNT=0

while IFS='=' read -r line; do
	# Saltar comentarios y líneas vacías
	[[ "$line" =~ ^[[:space:]]*# ]] && continue
	[[ -z "${line// }" ]] && continue

	VAR_NAME=$(echo "$line" | cut -d'=' -f1)

	# Filtrar por servicio si se especifica
	if [[ -n "$SERVICE" ]]; then
		SERVICE_UPPER=$(echo "$SERVICE" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
		if ! echo "$VAR_NAME" | grep -qiE "${SERVICE_UPPER}|${SERVICE}"; then
			continue
		fi
	fi

	# Verificar si es un secreto
	if echo "$VAR_NAME" | grep -qiE "$SECRET_PATTERNS"; then
		log_info "Rotando $VAR_NAME..."

		# Generar nuevo secreto
		if command -v generate_password >/dev/null 2>&1; then
			NEW_SECRET=$(generate_password 32)
		elif [[ -f "$UTILS_DIR/generate-password.sh" ]]; then
			NEW_SECRET=$(bash "$UTILS_DIR/generate-password.sh" 32)
		else
			# Fallback: usar openssl
			NEW_SECRET=$(openssl rand -base64 32 2>/dev/null || \
				openssl rand -hex 16 2>/dev/null || echo "")
		fi

		if [[ -z "$NEW_SECRET" ]]; then
			log_error "No se pudo generar nuevo secreto para $VAR_NAME"
			continue
		fi

		# Actualizar en .env usando replace-env-var.sh si está disponible
		if [[ -f "$UTILS_DIR/replace-env-var.sh" ]]; then
			if bash "$UTILS_DIR/replace-env-var.sh" "$VAR_NAME" "$NEW_SECRET" \
				"$ENV_FILE" >/dev/null 2>&1; then
				log_success "$VAR_NAME rotado correctamente"
				ROTATED_COUNT=$((ROTATED_COUNT + 1))
			else
				log_error "Falló al actualizar $VAR_NAME"
			fi
		else
			# Fallback: usar sed
			if sed -i "s|^${VAR_NAME}=.*|${VAR_NAME}=${NEW_SECRET}|" "$ENV_FILE" \
				2>/dev/null; then
				log_success "$VAR_NAME rotado correctamente"
				ROTATED_COUNT=$((ROTATED_COUNT + 1))
			else
				log_error "Falló al actualizar $VAR_NAME"
			fi
		fi
	fi
done < "$ENV_FILE"

if [[ $ROTATED_COUNT -gt 0 ]]; then
	log_success "Rotación completada: $ROTATED_COUNT secretos rotados"
	log_info "Revisa el archivo .env y actualiza los servicios que usan estos secretos"
	exit 0
else
	log_warn "No se rotaron secretos (puede que no haya secretos o no coincidan con el filtro)"
	exit 0
fi
