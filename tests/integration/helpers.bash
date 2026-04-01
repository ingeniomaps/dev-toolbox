#!/usr/bin/env bash
# ============================================================================
# Integration Test Helpers
# Ubicación: tests/integration/
# ============================================================================
# Helpers comunes para tests de integración con BATS.
#
# Uso:
#   load 'helpers'
#
# Funciones disponibles:
#   setup_integration_test - Configura entorno de integración
#   teardown_integration_test - Limpia entorno de integración
#   start_test_service - Inicia servicio Docker para test
#   stop_test_service - Detiene servicio Docker de test
#   wait_for_service - Espera a que servicio esté listo
#   cleanup_test_containers - Limpia contenedores de test
#   cleanup_test_networks - Limpia redes de test
# ============================================================================

# Cargar funciones de aserción del helpers de unit tests
_integration_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_integration_dir/../unit/helpers.bash"
unset _integration_dir

# Función helper para setup de integración (puede ser llamada desde tests E2E)
setup_integration_test() {
	# Directorio del proyecto
	export TEST_PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
	export TEST_COMMON_DIR="$TEST_PROJECT_ROOT/scripts/sh/common"
	export TEST_SCRIPTS_DIR="$TEST_PROJECT_ROOT/scripts/sh"

	# Directorio temporal para tests
	export TEST_TMP_DIR=$(mktemp -d)
	export TEST_PROJECT_ROOT_FOR_TEST="$TEST_TMP_DIR/test-project"

	# Crear estructura de directorios de test
	mkdir -p "$TEST_PROJECT_ROOT_FOR_TEST"

	# Variables de entorno para tests de integración
	export TEST_NETWORK_NAME="test-network-$(date +%s)"
	export TEST_NETWORK_IP="172.99.0.0"
	export TEST_SERVICE_PREFIX="test"

	# Limpiar variables que puedan interferir
	unset PROJECT_ROOT
	unset SCRIPT_DIR

	# Verificar que Docker está disponible
	if ! command -v docker >/dev/null 2>&1; then
		return 1
	fi

	if ! docker info >/dev/null 2>&1; then
		return 1
	fi

	return 0
}

# Setup común para tests de integración
setup() {
	if ! setup_integration_test; then
		skip "Docker no está disponible o no está corriendo"
	fi
}

# Función helper para teardown de integración (puede ser llamada desde tests E2E)
teardown_integration_test() {
	# Limpiar contenedores de test
	cleanup_test_containers

	# Limpiar redes de test
	cleanup_test_networks

	# Limpiar archivos temporales
	if [[ -n "${TEST_TMP_DIR:-}" ]] && [[ -d "$TEST_TMP_DIR" ]]; then
		rm -rf "$TEST_TMP_DIR"
	fi

	# Limpiar variables de entorno de test
	unset TEST_PROJECT_ROOT
	unset TEST_COMMON_DIR
	unset TEST_SCRIPTS_DIR
	unset TEST_TMP_DIR
	unset TEST_PROJECT_ROOT_FOR_TEST
	unset TEST_NETWORK_NAME
	unset TEST_NETWORK_IP
	unset TEST_SERVICE_PREFIX
}

# Teardown común para tests de integración
teardown() {
	teardown_integration_test
}

# ============================================================================
# Funciones Helper para Tests de Integración
# ============================================================================

# Limpia contenedores de test
cleanup_test_containers() {
	if command -v docker >/dev/null 2>&1; then
		# Detener y eliminar contenedores de test
		docker ps -a --filter "name=${TEST_SERVICE_PREFIX:-test}-" \
			--format "{{.Names}}" 2>/dev/null | \
			while read -r container; do
				if [[ -n "$container" ]]; then
					docker stop "$container" >/dev/null 2>&1 || true
					docker rm "$container" >/dev/null 2>&1 || true
				fi
			done
	fi
}

# Limpia redes de test
cleanup_test_networks() {
	if command -v docker >/dev/null 2>&1; then
		# Eliminar redes de test
		docker network ls --filter "name=${TEST_NETWORK_NAME:-test-network}" \
			--format "{{.Name}}" 2>/dev/null | \
			while read -r network; do
				if [[ -n "$network" ]]; then
					docker network rm "$network" >/dev/null 2>&1 || true
				fi
			done
	fi
}

# Inicia un servicio Docker para test
start_test_service() {
	local service_name="$1"
	local image="${2:-alpine:latest}"
	local command="${3:-sleep 3600}"

	local container_name="${TEST_SERVICE_PREFIX:-test}-${service_name}"

	# Crear red si no existe
	if ! docker network ls --format "{{.Name}}" | grep -q "^${TEST_NETWORK_NAME}$"; then
		docker network create --subnet="${TEST_NETWORK_IP}/16" \
			"${TEST_NETWORK_NAME}" >/dev/null 2>&1 || true
	fi

	# Iniciar contenedor
	docker run -d \
		--name "$container_name" \
		--network "${TEST_NETWORK_NAME}" \
		"$image" \
		sh -c "$command" >/dev/null 2>&1

	echo "$container_name"
}

# Detiene un servicio Docker de test
stop_test_service() {
	local container_name="$1"

	if [[ -z "$container_name" ]]; then
		return 1
	fi

	docker stop "$container_name" >/dev/null 2>&1 || true
	docker rm "$container_name" >/dev/null 2>&1 || true
}

# Espera a que un servicio esté listo
wait_for_service() {
	local container_name="$1"
	local max_wait="${2:-30}"
	local wait_time=0

	while [[ $wait_time -lt $max_wait ]]; do
		if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
			local status=$(docker inspect --format='{{.State.Status}}' \
				"$container_name" 2>/dev/null || echo "none")

			if [[ "$status" == "running" ]]; then
				return 0
			fi
		fi

		sleep 1
		wait_time=$((wait_time + 1))
	done

	return 1
}
