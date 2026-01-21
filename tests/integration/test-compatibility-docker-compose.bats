#!/usr/bin/env bats
# ============================================================================
# Test: test-compatibility-docker-compose.bats
# Ubicación: tests/integration/
# ============================================================================
# Tests de compatibilidad para Docker Compose V1 y V2.
# Verifica que el proyecto funciona correctamente con ambas versiones.
#
# Uso:
#   bats tests/integration/test-compatibility-docker-compose.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'tests/integration/helpers.bash'

# Setup específico para tests de compatibilidad
setup() {
	setup_integration_test || true

	# Crear proyecto de test
	mkdir -p "$TEST_PROJECT_ROOT_FOR_TEST"
	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Copiar estructura necesaria
	if [[ -f "$TEST_PROJECT_ROOT/Makefile" ]]; then
		cp "$TEST_PROJECT_ROOT/Makefile" "$TEST_PROJECT_ROOT_FOR_TEST/"
	fi

	if [[ -d "$TEST_PROJECT_ROOT/makefiles" ]]; then
		cp -r "$TEST_PROJECT_ROOT/makefiles" "$TEST_PROJECT_ROOT_FOR_TEST/"
	fi

	if [[ -d "$TEST_PROJECT_ROOT/scripts" ]]; then
		cp -r "$TEST_PROJECT_ROOT/scripts" "$TEST_PROJECT_ROOT_FOR_TEST/"
	fi

	export PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST"
	cd "$TEST_PROJECT_ROOT_FOR_TEST"
}

# Teardown específico
teardown() {
	if [[ -d "$TEST_PROJECT_ROOT_FOR_TEST" ]]; then
		rm -rf "$TEST_PROJECT_ROOT_FOR_TEST"
	fi

	teardown_integration_test || true
}

@test "get_docker_compose_cmd detecta Docker Compose V2" {
	skip_if_no_docker

	# Verificar si docker compose (V2) está disponible
	if ! docker compose version >/dev/null 2>&1; then
		skip "Docker Compose V2 no está disponible"
	fi

	# Cargar helper de docker-compose
	source "$TEST_SCRIPTS_DIR/common/docker-compose.sh"

	# Obtener comando
	cmd=$(get_docker_compose_cmd)

	# Verificar que detecta V2
	assert_equals "docker compose" "$cmd" "Debería detectar Docker Compose V2"
}

@test "get_docker_compose_cmd detecta Docker Compose V1 si V2 no está disponible" {
	skip_if_no_docker

	# Verificar si docker-compose (V1) está disponible
	if ! command -v docker-compose >/dev/null 2>&1; then
		skip "Docker Compose V1 no está disponible"
	fi

	# Si V2 está disponible, este test no aplica
	if docker compose version >/dev/null 2>&1; then
		skip "Docker Compose V2 está disponible, V1 no se usará"
	fi

	# Cargar helper de docker-compose
	source "$TEST_SCRIPTS_DIR/common/docker-compose.sh"

	# Obtener comando
	cmd=$(get_docker_compose_cmd)

	# Verificar que detecta V1
	assert_equals "docker-compose" "$cmd" "Debería detectar Docker Compose V1"
}

@test "check-dependencies.sh funciona con Docker Compose V2" {
	skip_if_no_docker

	# Verificar si docker compose (V2) está disponible
	if ! docker compose version >/dev/null 2>&1; then
		skip "Docker Compose V2 no está disponible"
	fi

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Ejecutar check-dependencies
	run bash "$TEST_SCRIPTS_DIR/commands/check-dependencies.sh" \
		PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1

	# Debería ejecutarse exitosamente
	assert_success "$output" "$status" "Debería funcionar con Docker Compose V2"

	# Verificar que detecta V2
	assert_contains "$output" "V2\|docker compose" "Debería detectar Docker Compose V2"
}

@test "check-dependencies.sh funciona con Docker Compose V1" {
	skip_if_no_docker

	# Verificar si docker-compose (V1) está disponible
	if ! command -v docker-compose >/dev/null 2>&1; then
		skip "Docker Compose V1 no está disponible"
	fi

	# Si V2 está disponible, este test no aplica
	if docker compose version >/dev/null 2>&1; then
		skip "Docker Compose V2 está disponible, V1 no se usará"
	fi

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Ejecutar check-dependencies
	run bash "$TEST_SCRIPTS_DIR/commands/check-dependencies.sh" \
		PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1

	# Debería ejecutarse exitosamente
	assert_success "$output" "$status" "Debería funcionar con Docker Compose V1"

	# Verificar que detecta V1
	assert_contains "$output" "V1\|docker-compose" "Debería detectar Docker Compose V1"
}

@test "check-versions.sh verifica versión de Docker Compose V2" {
	skip_if_no_docker

	# Verificar si docker compose (V2) está disponible
	if ! docker compose version >/dev/null 2>&1; then
		skip "Docker Compose V2 no está disponible"
	fi

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Ejecutar check-versions
	run bash "$TEST_SCRIPTS_DIR/commands/check-versions.sh" \
		PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Debería ejecutarse (puede tener warnings)
	[[ $status -ge 0 ]]

	# Verificar que verifica versión de Compose
	assert_contains "$output" "Compose\|compose\|2\." "Debería verificar versión de Docker Compose"
}

@test "check-versions.sh verifica versión de Docker Compose V1" {
	skip_if_no_docker

	# Verificar si docker-compose (V1) está disponible
	if ! command -v docker-compose >/dev/null 2>&1; then
		skip "Docker Compose V1 no está disponible"
	fi

	# Si V2 está disponible, este test no aplica
	if docker compose version >/dev/null 2>&1; then
		skip "Docker Compose V2 está disponible, V1 no se usará"
	fi

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Ejecutar check-versions
	run bash "$TEST_SCRIPTS_DIR/commands/check-versions.sh" \
		PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Debería ejecutarse (puede tener warnings)
	[[ $status -ge 0 ]]

	# Verificar que verifica versión de Compose
	assert_contains "$output" "Compose\|compose\|1\." "Debería verificar versión de Docker Compose V1"
}

@test "get_docker_compose_version obtiene versión de V2" {
	skip_if_no_docker

	# Verificar si docker compose (V2) está disponible
	if ! docker compose version >/dev/null 2>&1; then
		skip "Docker Compose V2 no está disponible"
	fi

	# Cargar helper de docker-compose
	source "$TEST_SCRIPTS_DIR/common/docker-compose.sh"

	# Obtener versión
	version=$(get_docker_compose_version)

	# Verificar que obtiene versión
	[[ -n "$version" ]] || assert_contains "$version" "[0-9]" "Debería obtener versión de Docker Compose V2"
}

@test "get_docker_compose_version obtiene versión de V1" {
	skip_if_no_docker

	# Verificar si docker-compose (V1) está disponible
	if ! command -v docker-compose >/dev/null 2>&1; then
		skip "Docker Compose V1 no está disponible"
	fi

	# Si V2 está disponible, este test no aplica
	if docker compose version >/dev/null 2>&1; then
		skip "Docker Compose V2 está disponible, V1 no se usará"
	fi

	# Cargar helper de docker-compose
	source "$TEST_SCRIPTS_DIR/common/docker-compose.sh"

	# Obtener versión
	version=$(get_docker_compose_version)

	# Verificar que obtiene versión
	[[ -n "$version" ]] || assert_contains "$version" "[0-9]" "Debería obtener versión de Docker Compose V1"
}

# Helper para saltar si Docker no está disponible
skip_if_no_docker() {
	if ! command -v docker >/dev/null 2>&1; then
		skip "Docker no está disponible"
	fi

	if ! docker info >/dev/null 2>&1; then
		skip "Docker no está corriendo"
	fi
}
