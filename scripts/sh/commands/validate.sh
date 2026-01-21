#!/usr/bin/env bash
# ============================================================================
# Script: validate.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Valida la configuración completa: .env, variables, scripts, IPs, puertos,
# versiones de servicios y prerrequisitos (Docker, Compose).
#
# Uso:
#   ./scripts/sh/commands/validate.sh [variables_extra] [--only-env] [--only-ips]
#   [--only-ports] [--only-versions] [--skip-cache] [--parallel]
#   make validate
#   make validate VALIDATE_EXTRA_VARS="SERVICE_PREFIX,DB_PASSWORD"
#   make validate PORTS="5432 80"
#   make validate --only-env
#   make validate --skip-cache
#
# Parámetros:
#   $1 - Opcional. Variables adicionales a comprobar en .env, separadas por
#        comas. Cada módulo o proyecto puede pasar las que necesite.
#        Ej.: SERVICE_PREFIX,POSTGRES_PASSWORD
#
# Opciones:
#   --only-env        - Solo valida .env y variables
#   --only-ips        - Solo valida IPs
#   --only-ports      - Solo valida puertos
#   --only-versions   - Solo valida versiones
#   --skip-cache      - Ignora caché y valida todo
#   --parallel        - Ejecuta checks independientes en paralelo
#   --cache-ttl=N     - TTL del caché en segundos (default: 300 = 5 minutos)
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (donde está .env). Make la pasa como $(CURDIR).
#                  Si no se define, se usa $(pwd). Misma regla que init-env.
#   PORTS - Opcional. Puertos a comprobar (espacios o comas). Si no se define,
#           no se ejecuta check-ports. Ej.: PORTS="5432 80" o PORTS="5432,80"
#   VALIDATE_CACHE_TTL - TTL del caché en segundos (default: 300)
#   VALIDATE_SKIP_CACHE - true: ignora caché (equivalente a --skip-cache)
#   VALIDATE_PARALLEL - true: ejecuta en paralelo (equivalente a --parallel)
#
# Requisitos:
#   - .env en la raíz (recomendado: make init-env)
#   - En .env (obligatorias): NETWORK_NAME, NETWORK_IP
#   - En utils: ensure-network.sh, wait-for-service.sh, validate-ips.sh,
#     check-ports.sh, check-version-compatibility.sh
#   - validate-ips: solo se ejecuta si .env tiene variables _HOST, _IP o NETWORK_IP
#   - check-ports: solo se ejecuta si PORTS está definido
#   - make check-dependencies (Docker, docker-compose)
#
# Retorno:
#   0 si la validación es exitosa
#   1 si hay problemas
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Determinar directorio del script
_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_script_dir"
unset _script_dir
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"
readonly COMMANDS_DIR="$SCRIPT_DIR"
readonly UTILS_SCRIPTS_DIR="$SCRIPT_DIR/../utils"

# Cargar helpers comunes
if [[ -f "$COMMON_SCRIPTS_DIR/init.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/init.sh"
	init_script
else
	# Raíz del proyecto: la que origina el comando (Make pasa PROJECT_ROOT=$(CURDIR)) o pwd si se ejecuta directo.
	# Se normaliza sin slash final para construir rutas.
	_pr="${PROJECT_ROOT:-$(pwd)}"
	readonly PROJECT_ROOT="${_pr%/}"
	unset _pr
	if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
		source "$COMMON_SCRIPTS_DIR/logging.sh"
	fi
fi

if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

# Cargar módulos de validación
source "$COMMANDS_DIR/validate-cache.sh"
source "$COMMANDS_DIR/validate-checks.sh"

# Parsear argumentos y opciones
EXTRA_VARS=""
ONLY_ENV=false
ONLY_IPS=false
ONLY_PORTS=false
ONLY_VERSIONS=false
SKIP_CACHE=false
PARALLEL=false
CACHE_TTL="${VALIDATE_CACHE_TTL:-300}"

# Separar argumentos posicionales de opciones
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
	case "$1" in
		--only-env)
			ONLY_ENV=true
			shift
			;;
		--only-ips)
			ONLY_IPS=true
			shift
			;;
		--only-ports)
			ONLY_PORTS=true
			shift
			;;
		--only-versions)
			ONLY_VERSIONS=true
			shift
			;;
		--skip-cache)
			SKIP_CACHE=true
			shift
			;;
		--parallel)
			PARALLEL=true
			shift
			;;
		--cache-ttl=*)
			CACHE_TTL="${1#*=}"
			shift
			;;
		-*)
			log_warn "Opción desconocida: $1"
			shift
			;;
		*)
			POSITIONAL_ARGS+=("$1")
			shift
			;;
	esac
done

# Restaurar argumentos posicionales
set -- "${POSITIONAL_ARGS[@]}"
EXTRA_VARS="${1:-}"

# Verificar variables de entorno para opciones
if [[ "${VALIDATE_SKIP_CACHE:-}" == "true" ]]; then
	SKIP_CACHE=true
fi

if [[ "${VALIDATE_PARALLEL:-}" == "true" ]]; then
	PARALLEL=true
fi

# Si solo se especifica una opción --only-*, solo esa se ejecuta
if [[ "$ONLY_ENV" == "true" ]] || [[ "$ONLY_IPS" == "true" ]] || \
	[[ "$ONLY_PORTS" == "true" ]] || [[ "$ONLY_VERSIONS" == "true" ]]; then
	# Deshabilitar las otras validaciones
	DO_ENV="$ONLY_ENV"
	DO_IPS="$ONLY_IPS"
	DO_PORTS="$ONLY_PORTS"
	DO_VERSIONS="$ONLY_VERSIONS"
	DO_SCRIPTS=false
	DO_DEPS=false
else
	# Validación completa por defecto
	DO_ENV=true
	DO_IPS=true
	DO_PORTS=true
	DO_VERSIONS=true
	DO_SCRIPTS=true
	DO_DEPS=true
fi

# Configurar directorio de caché
readonly CACHE_DIR="$PROJECT_ROOT/.validation-cache"
readonly ENV_FILE="$PROJECT_ROOT/.env"

EXIT_CODE=0

log_step "Validando configuracion del proyecto..."
log_info "Archivo .env: $ENV_FILE"

# Ejecutar validaciones según opciones
if [[ "$DO_ENV" == "true" ]]; then
	validate_env_and_vars \
		"$ENV_FILE" \
		"$EXTRA_VARS" \
		"$CACHE_DIR" \
		"$SKIP_CACHE" \
		"$CACHE_TTL" \
		"EXIT_CODE"
fi

if [[ "$DO_SCRIPTS" == "true" ]]; then
	validate_scripts \
		"$UTILS_SCRIPTS_DIR" \
		"$CACHE_DIR" \
		"$SKIP_CACHE" \
		"$CACHE_TTL" \
		"EXIT_CODE"
fi

if [[ "$DO_DEPS" == "true" ]]; then
	validate_dependencies \
		"$PROJECT_ROOT" \
		"$CACHE_DIR" \
		"$SKIP_CACHE" \
		"$CACHE_TTL" \
		"EXIT_CODE"
fi

if [[ "$DO_IPS" == "true" ]] && [[ -f "$ENV_FILE" ]]; then
	validate_ips \
		"$ENV_FILE" \
		"$COMMANDS_DIR" \
		"$CACHE_DIR" \
		"$SKIP_CACHE" \
		"$CACHE_TTL"
fi

if [[ "$DO_PORTS" == "true" ]] && [[ -n "${PORTS:-}" ]]; then
	validate_ports \
		"${PORTS:-}" \
		"$COMMANDS_DIR" \
		"$CACHE_DIR" \
		"$SKIP_CACHE" \
		"$CACHE_TTL"
fi

if [[ "$DO_VERSIONS" == "true" ]] && [[ -f "$ENV_FILE" ]]; then
	validate_versions \
		"$ENV_FILE" \
		"$COMMANDS_DIR" \
		"$CACHE_DIR" \
		"$SKIP_CACHE" \
		"$CACHE_TTL" \
		"$PARALLEL"
fi

exit $EXIT_CODE
