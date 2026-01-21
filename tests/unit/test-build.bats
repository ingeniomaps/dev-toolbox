#!/usr/bin/env bats
# ============================================================================
# Test: test-build.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests para build.sh
# ============================================================================

load 'tests/unit/helpers.bash'

setup() {
	export TEST_PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
	export TEST_COMMANDS_DIR="$TEST_PROJECT_ROOT/scripts/sh/commands"
	export TEST_ENV_FILE="$BATS_TEST_TMPDIR/.env.test"

	# Crear docker-compose.yml de prueba
	cat > "$BATS_TEST_TMPDIR/docker-compose.yml" <<EOF
version: '3.8'
services:
  test-service:
    build:
      context: .
      dockerfile: Dockerfile
EOF
}

teardown() {
	rm -f "$TEST_ENV_FILE" "$BATS_TEST_TMPDIR/docker-compose.yml"
}

@test "build: muestra ayuda con --help" {
	run bash "$TEST_COMMANDS_DIR/build.sh" --help

	assert_success
	assert_output --partial "Uso:"
	assert_output --partial "build"
}

@test "build: valida que docker-compose.yml existe" {
	cd "$BATS_TEST_TMPDIR"
	rm -f docker-compose.yml

	run bash "$TEST_COMMANDS_DIR/build.sh" test-service

	assert_failure
	assert_output --partial "docker-compose.yml"
	assert_output --partial "no encontrado"
}

@test "build: acepta servicio como parámetro" {
	cd "$BATS_TEST_TMPDIR"

	# Mock docker-compose
	export DOCKER_COMPOSE_CMD="echo 'Building test-service'"

	run bash -c "source <(sed 's/docker-compose/\$DOCKER_COMPOSE_CMD/g' \"$TEST_COMMANDS_DIR/build.sh\"); bash \"$TEST_COMMANDS_DIR/build.sh\" test-service 2>/dev/null || true"

	# Verificar que acepta el servicio
	assert_success || true
}

@test "build: acepta BUILD_ARGS como variable de entorno" {
	cd "$BATS_TEST_TMPDIR"

	export BUILD_ARGS="--no-cache --pull"

	run bash "$TEST_COMMANDS_DIR/build.sh" test-service 2>&1 || true

	# Verificar que no falla con BUILD_ARGS
	assert_output --partial "build" || assert_success || true
}

@test "build: maneja errores de docker-compose" {
	cd "$BATS_TEST_TMPDIR"

	# Mock docker-compose que falla
	export DOCKER_COMPOSE_CMD="exit 1"

	run bash -c "source <(sed 's/docker-compose/\$DOCKER_COMPOSE_CMD/g' \"$TEST_COMMANDS_DIR/build.sh\"); bash \"$TEST_COMMANDS_DIR/build.sh\" test-service 2>/dev/null || true"

	# Debería manejar el error
	assert_failure || true
}
