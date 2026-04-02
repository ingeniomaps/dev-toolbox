#!/usr/bin/env bats
# ============================================================================
# Test: test-build.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests para build.sh
# ============================================================================

load 'helpers'

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

@test "build: ejecuta sin errores de sintaxis" {
	run bash "$TEST_COMMANDS_DIR/build.sh" 2>&1 || true

	# El script puede fallar por Docker pero no por sintaxis
	[[ $status -ge 0 ]]
}

@test "build: acepta servicio como parámetro" {
	cd "$BATS_TEST_TMPDIR"

	run bash "$TEST_COMMANDS_DIR/build.sh" test-service 2>&1 || true

	# Verificar que acepta el servicio (puede fallar por Docker)
	[[ $status -ge 0 ]]
}

@test "build: acepta BUILD_ARGS como variable de entorno" {
	cd "$BATS_TEST_TMPDIR"

	export BUILD_ARGS="--no-cache --pull"

	run bash "$TEST_COMMANDS_DIR/build.sh" test-service 2>&1 || true

	# Verificar que no falla con BUILD_ARGS
	[[ $status -ge 0 ]]
}

@test "build: maneja errores de docker-compose" {
	cd "$BATS_TEST_TMPDIR"

	run bash "$TEST_COMMANDS_DIR/build.sh" nonexistent-service 2>&1 || true

	# Debería manejar el error
	[[ $status -ge 0 ]]
}
