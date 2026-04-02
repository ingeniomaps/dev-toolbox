#!/usr/bin/env bash
# ============================================================================
# Script: check-versions.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Verifica versiones mínimas de Docker, Docker Compose, Make y Bash.
#
# Uso:
#   ./scripts/sh/commands/check-versions.sh
#   make check-versions-main
#
# Versiones mínimas:
#   - Docker >= 20.10
#   - Docker Compose >= 2.0 (o v1 >= 1.0)
#   - Make >= 4.0
#   - Bash >= 4.0
#
# Retorno:
#   0 si todas cumplen los requisitos
#   1 si alguna no cumple (el sistema puede seguir funcionando)
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Determinar directorio del script
_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_script_dir"
unset _script_dir
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"

# Cargar helpers comunes
if [[ -f "$COMMON_SCRIPTS_DIR/init.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/init.sh"
	init_script
else
	readonly PROJECT_ROOT="${PROJECT_ROOT:-$SCRIPT_DIR/../../..}"
	if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
		source "$COMMON_SCRIPTS_DIR/logging.sh"
	fi
fi

if [[ -f "$COMMON_SCRIPTS_DIR/docker-compose.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/docker-compose.sh"
fi

EXIT_CODE=0

log_step "Verificando versiones mínimas..."
echo ""

# Verificar Docker
if command -v docker >/dev/null 2>&1; then
	DOCKER_VERSION=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
	DOCKER_MAJOR=$(echo "$DOCKER_VERSION" | cut -d. -f1)
	DOCKER_MINOR=$(echo "$DOCKER_VERSION" | cut -d. -f2)

	if [[ $DOCKER_MAJOR -gt 20 ]] || \
		{ [[ $DOCKER_MAJOR -eq 20 ]] && [[ $DOCKER_MINOR -ge 10 ]]; }; then
		log_success "Docker $DOCKER_VERSION >= 20.10"
	else
		log_warn "Docker $DOCKER_VERSION < 20.10 (recomendado: >= 20.10)"
		EXIT_CODE=1
	fi
else
	log_error "Docker no encontrado"
	EXIT_CODE=1
fi

# Verificar Docker Compose usando helper
if command -v get_docker_compose_cmd >/dev/null 2>&1; then
	DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
	if [[ "$DOCKER_COMPOSE_CMD" == "docker compose" ]]; then
		COMPOSE_VERSION=$(docker compose version --short 2>/dev/null | \
			grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "2.0")
		COMPOSE_MAJOR=$(echo "$COMPOSE_VERSION" | cut -d. -f1)

		if [[ $COMPOSE_MAJOR -ge 2 ]]; then
			log_success "Docker Compose $COMPOSE_VERSION >= 2.0"
		else
			log_warn "Docker Compose $COMPOSE_VERSION < 2.0 (recomendado: >= 2.0)"
			EXIT_CODE=1
		fi
	else
		# docker-compose v1
		COMPOSE_VERSION=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+' | \
			head -1)
		COMPOSE_MAJOR=$(echo "$COMPOSE_VERSION" | cut -d. -f1)

		if [[ $COMPOSE_MAJOR -ge 1 ]]; then
			log_success "Docker Compose $COMPOSE_VERSION (v1, considerar actualizar a v2)"
		else
			log_warn "Docker Compose $COMPOSE_VERSION < 1.0"
			EXIT_CODE=1
		fi
	fi
elif docker compose version >/dev/null 2>&1; then
	COMPOSE_VERSION=$(docker compose version --short 2>/dev/null | \
		grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "2.0")
	COMPOSE_MAJOR=$(echo "$COMPOSE_VERSION" | cut -d. -f1)

	if [[ $COMPOSE_MAJOR -ge 2 ]]; then
		log_success "Docker Compose $COMPOSE_VERSION >= 2.0"
	else
		log_warn "Docker Compose $COMPOSE_VERSION < 2.0 (recomendado: >= 2.0)"
		EXIT_CODE=1
	fi
elif command -v docker-compose >/dev/null 2>&1; then
	COMPOSE_VERSION=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+' | \
		head -1)
	COMPOSE_MAJOR=$(echo "$COMPOSE_VERSION" | cut -d. -f1)

	if [[ $COMPOSE_MAJOR -ge 1 ]]; then
		log_success "Docker Compose $COMPOSE_VERSION (v1, considerar actualizar a v2)"
	else
		log_warn "Docker Compose $COMPOSE_VERSION < 1.0"
		EXIT_CODE=1
	fi
else
	log_error "Docker Compose no encontrado"
	EXIT_CODE=1
fi

# Verificar Make
if command -v make >/dev/null 2>&1; then
	MAKE_VERSION=$(make --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
	MAKE_MAJOR=$(echo "$MAKE_VERSION" | cut -d. -f1)

	if [[ $MAKE_MAJOR -ge 4 ]]; then
		log_success "Make $MAKE_VERSION >= 4.0"
	else
		log_warn "Make $MAKE_VERSION < 4.0 (recomendado: >= 4.0)"
		EXIT_CODE=1
	fi
else
	log_error "Make no encontrado"
	EXIT_CODE=1
fi

# Verificar Bash
if command -v bash >/dev/null 2>&1; then
	BASH_VERSION=$(bash --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
	BASH_MAJOR=$(echo "$BASH_VERSION" | cut -d. -f1)

	if [[ $BASH_MAJOR -ge 4 ]]; then
		log_success "Bash $BASH_VERSION >= 4.0"
	else
		log_warn "Bash $BASH_VERSION < 4.0 (recomendado: >= 4.0)"
		EXIT_CODE=1
	fi
else
	log_error "Bash no encontrado"
	EXIT_CODE=1
fi

echo ""

if [[ $EXIT_CODE -eq 0 ]]; then
	log_success "Todas las versiones cumplen los requisitos mínimos"
	exit 0
else
	log_warn "Algunas versiones no cumplen los requisitos mínimos"
	log_info "El sistema puede funcionar, pero se recomienda actualizar"
	exit 1
fi
