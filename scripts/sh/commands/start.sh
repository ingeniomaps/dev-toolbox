#!/usr/bin/env bash
# ============================================================================
# Script: start.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Inicia uno o más servicios Docker.
#
# Uso:
#   ./scripts/sh/commands/start.sh [servicio1 servicio2 ...]
#
# Parámetros:
#   $@ - (opcional) Lista de servicios a iniciar. Si no se especifica,
#        inicia todos los servicios detectados desde .env
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   SERVICES - Lista de servicios separados por espacios (opcional)
#   SERVICE_PREFIX - Prefijo para nombres de contenedores (opcional)
#
# Retorno:
#   0 si todos los servicios se iniciaron exitosamente
#   1 si algún servicio falló al iniciar
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
	# Fallback si init.sh no está disponible
	_pr="${PROJECT_ROOT:-$(pwd)}"
	readonly PROJECT_ROOT="${_pr%/}"
	unset _pr
	if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
		source "$COMMON_SCRIPTS_DIR/logging.sh"
	fi
fi

if [[ -f "$COMMON_SCRIPTS_DIR/services.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/services.sh"
fi

# Cargar validation.sh para validar prerrequisitos
if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

readonly ENV_FILE="$PROJECT_ROOT/.env"

# Validar que .env existe si vamos a detectar servicios desde él
if [[ $# -eq 0 ]] && [[ -z "${SERVICES:-}" ]]; then
	if ! validate_env_file "$ENV_FILE"; then
		log_error "No se puede detectar servicios sin archivo .env"
		log_info "💡 Solución: Ejecuta 'make init-env' o especifica servicios con:"
		log_info "   make start SERVICES=\"servicio1 servicio2\""
		exit 1
	fi
fi

# Determinar servicios: parámetros > SERVICES env > detectar desde .env
if [[ $# -gt 0 ]]; then
	SERVICES_LIST="$*"
elif [[ -n "${SERVICES:-}" ]]; then
	SERVICES_LIST="$SERVICES"
else
	# Usar helper común para detectar servicios
	SERVICES_LIST=$(detect_services_from_env "$ENV_FILE")

	if [[ -z "$SERVICES_LIST" ]]; then
		log_warn "No hay servicios disponibles para iniciar"
		log_info "💡 Sugerencia: Agrega variables *_VERSION en $ENV_FILE"
		log_info "   Ejemplo: POSTGRES_VERSION=18"
		log_info "   O especifica servicios: make start SERVICES=\"servicio1 servicio2\""
		exit 0
	fi
fi

if [[ -z "$SERVICES_LIST" ]]; then
	log_warn "No hay servicios disponibles para iniciar"
	exit 0
fi

log_step "Iniciando servicios..."

EXIT_CODE=0
for service in $SERVICES_LIST; do
	if make -C "$PROJECT_ROOT" -n "up-${service}" >/dev/null 2>&1; then
		log_info "Iniciando $service..."
		if make -C "$PROJECT_ROOT" "up-${service}" >/dev/null 2>&1; then
			log_success "$service iniciado correctamente"
		else
			log_error "Falló al iniciar $service"
			EXIT_CODE=1
		fi
	else
		log_warn "Comando up-${service} no disponible (puede que el servicio no esté configurado)"
	fi
done

if [[ $EXIT_CODE -eq 0 ]]; then
	log_success "Todos los servicios iniciados correctamente"
	exit 0
else
	log_error "Algunos servicios fallaron al iniciar"
	exit 1
fi
