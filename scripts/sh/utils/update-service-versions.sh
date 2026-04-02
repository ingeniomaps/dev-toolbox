#!/usr/bin/env bash
# ============================================================================
# Script: update-service-versions.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Actualiza variables *_VERSION en .env y opcionalmente en docker-compose.
# No fija servicios: deriva de las variables *_VERSION en .env o del nombre
# indicado. Modo interactivo si no se pasan los dos argumentos.
#
# Convención: FOO_VERSION en .env -> servicio "foo" (minúsculas, _ -> -).
# Rutas probadas para compose: containers/<servicio>/docker/docker-compose.yml,
# containers/<servicio>/docker-compose.yml.
#
# Uso:
#   make update-service-versions [SERVICE=postgres] [VERSION=17-alpine]
#   $0 [<servicio>] [<version>]
#
# Parámetros:
#   $1 - (opcional) Nombre del servicio. Sin esto, en .env se listan *_VERSION
#        y se elige por número o nombre.
#   $2 - (opcional) Nueva versión. Si falta, se pide de forma interactiva.
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (donde está .env). Make pasa $(CURDIR).
#
# Retorno:
#   0 si la actualización fue exitosa
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

readonly ENV_FILE="$PROJECT_ROOT/.env"
if [[ ! -f "$ENV_FILE" ]]; then
	echo "[ERROR] .env no encontrado en $PROJECT_ROOT. Ejecuta: make init-env" >&2
	exit 1
fi

if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/logging.sh"
else
	log_info() { echo "[INFO] $*"; }
	log_warn() { echo "[WARN] $*" >&2; }
	log_error() { echo "[ERROR] $*" >&2; }
	log_success() { echo "[SUCCESS] $*"; }
	log_step() { echo "[STEP] $*"; }
	[[ -f "$COMMON_SCRIPTS_DIR/colors.sh" ]] && source "$COMMON_SCRIPTS_DIR/colors.sh"
fi

# servicio -> FOO_VERSION (ej: postgres -> POSTGRES_VERSION, my-db -> MY_DB_VERSION)
service_to_version_var() { echo "$(echo "$1" | tr '[:lower:]' '[:upper:]' | tr '-' '_')_VERSION"; }
# normalizar nombre: minúsculas, _ -> -
normalize_service() { echo "$1" | tr '[:upper:]' '[:lower:]' | tr '_' '-'; }

SERVICE=""
NEW_VERSION="${2:-}"

if [[ -n "${1:-}" ]]; then
	SERVICE="$(normalize_service "${1}")"
fi

# --- Modo interactivo: pedir servicio y/o versión si faltan ---
if [[ -z "$SERVICE" ]]; then
	mapfile -t _lines < <(grep -E '^[A-Za-z0-9_]+_VERSION=' "$ENV_FILE" 2>/dev/null || true)
	if [[ ${#_lines[@]} -gt 0 ]]; then
		log_info "Variables *_VERSION en .env:"
		_services=()
		for i in "${!_lines[@]}"; do
			_key="${_lines[i]%%=*}"; _val="${_lines[i]#*=}"
			_svc="$(normalize_service "${_key%_VERSION}")"
			_services+=("$_svc")
			echo "  $((i+1))) $_svc: $_val"
		done
		printf '%b' "${COLOR_INFO:-}Servicio (número o nombre nuevo, Enter=salir): ${COLOR_RESET:-}"
		read -r _choice
		_choice="$(printf '%s' "$_choice" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
		if [[ -z "$_choice" ]]; then
			log_info "Salir."
			exit 0
		fi
		if [[ "$_choice" =~ ^[0-9]+$ ]] && (( _choice >= 1 && _choice <= ${#_services[@]} )); then
			SERVICE="${_services[_choice-1]}"
		else
			SERVICE="$(normalize_service "$_choice")"
		fi
		unset _lines _services _key _val _svc _choice
	else
		log_info "No hay variables *_VERSION en .env. Indica el nombre del servicio."
		printf '%b' "${COLOR_INFO:-}Servicio (Enter=salir): ${COLOR_RESET:-}"
		read -r SERVICE
		SERVICE="$(normalize_service "${SERVICE:-}")"
		if [[ -z "$SERVICE" ]]; then
			log_info "Salir."
			exit 0
		fi
	fi
fi

if [[ -z "$NEW_VERSION" ]]; then
	printf '%b' "${COLOR_INFO:-}Nueva versión: ${COLOR_RESET:-}"
	read -r NEW_VERSION
	NEW_VERSION="$(printf '%s' "$NEW_VERSION" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
	if [[ -z "$NEW_VERSION" ]]; then
		log_error "Se requiere la nueva versión."
		exit 1
	fi
fi

VERSION_VAR="$(service_to_version_var "$SERVICE")"

# Probar rutas habituales de docker-compose (la primera que exista)
COMPOSE_FILE=""
for _p in "containers/$SERVICE/docker/docker-compose.yml" "containers/$SERVICE/docker-compose.yml"; do
	if [[ -f "$PROJECT_ROOT/$_p" ]]; then
		COMPOSE_FILE="$PROJECT_ROOT/$_p"
		break
	fi
done
unset _p

log_step "Actualizando versión de $SERVICE a $NEW_VERSION..."

CURRENT_VERSION=$(grep "^${VERSION_VAR}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 || echo "")

if [[ -z "$CURRENT_VERSION" ]]; then
	log_warn "No se encontró $VERSION_VAR en .env. Se agregará."
else
	log_info "Versión actual: $CURRENT_VERSION"
	log_info "Nueva versión: $NEW_VERSION"
fi

# Validar compatibilidad con check-version-compatibility.sh (mismo utils)
if [[ -f "$SCRIPT_DIR/check-version-compatibility.sh" ]]; then
	log_info "Validando compatibilidad..."
	if ! bash "$SCRIPT_DIR/check-version-compatibility.sh" "$SERVICE" "$NEW_VERSION"; then
		log_warn "Advertencias de compatibilidad detectadas. Revisa los mensajes anteriores."
		printf '%b' "${COLOR_INFO:-}¿Continuar de todas formas? (s/N): ${COLOR_RESET:-}"
		read -r CONFIRM
		if [[ "$CONFIRM" != "s" && "$CONFIRM" != "S" ]]; then
			log_info "Operación cancelada"
			exit 0
		fi
	fi
fi

# Backup opcional si el target make existe
log_info "Comprobando backup opcional..."
if make -C "$PROJECT_ROOT" -n "backup-${SERVICE}" >/dev/null 2>&1; then
	make -C "$PROJECT_ROOT" "backup-${SERVICE}" || log_warn "No se pudo crear backup (continuando...)"
fi

# Actualizar .env
if [[ -n "$CURRENT_VERSION" ]]; then
	sed -i "s|^${VERSION_VAR}=.*|${VERSION_VAR}=${NEW_VERSION}|" "$ENV_FILE"
else
	echo "${VERSION_VAR}=${NEW_VERSION}" >> "$ENV_FILE"
fi

# Actualizar docker-compose si existe (rutas opcionales por proyecto)
if [[ -f "$COMPOSE_FILE" ]]; then
	log_info "Actualizando $COMPOSE_FILE..."
	if grep -q "image:" "$COMPOSE_FILE"; then
		sed -i "s|image:.*${SERVICE}.*|image: ${SERVICE}:${NEW_VERSION}|" "$COMPOSE_FILE" || true
	fi
fi

log_success "Versión actualizada en .env"
log_info "Próximos pasos:"
echo "  1. Revisa los cambios en .env y, si aplica, en docker-compose"
echo "  2. Actualiza la imagen (ej: make update-images)"
echo "  3. Reinicia el servicio (ej: make restart SERVICE=$SERVICE)"
