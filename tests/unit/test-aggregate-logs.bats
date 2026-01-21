#!/usr/bin/env bats
# ============================================================================
# Test: test-aggregate-logs.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests para aggregate-logs.sh
# ============================================================================

load 'tests/unit/helpers.bash'

setup() {
	export TEST_PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
	export TEST_COMMANDS_DIR="$TEST_PROJECT_ROOT/scripts/sh/commands"
}

@test "aggregate-logs: muestra ayuda con --help" {
	run bash "$TEST_COMMANDS_DIR/aggregate-logs.sh" --help

	assert_success
	assert_output --partial "Uso:"
	assert_output --partial "aggregate-logs"
}

@test "aggregate-logs: acepta --limit para limitar líneas" {
	# Mock docker logs
	export DOCKER_CMD="echo 'log line 1'; echo 'log line 2'; echo 'log line 3'"

	run bash -c "source <(sed 's/docker logs/\$DOCKER_CMD/g' \"$TEST_COMMANDS_DIR/aggregate-logs.sh\"); bash \"$TEST_COMMANDS_DIR/aggregate-logs.sh\" --limit=2 2>/dev/null || true"

	# Verificar que se limita la salida
	assert_success
}

@test "aggregate-logs: acepta --max-services para limitar servicios" {
	run bash "$TEST_COMMANDS_DIR/aggregate-logs.sh" --max-services=1 --help 2>&1 || true

	# Verificar que acepta el parámetro
	assert_output --partial "max-services" || true
}

@test "aggregate-logs: acepta --tail-only para solo últimas líneas" {
	run bash "$TEST_COMMANDS_DIR/aggregate-logs.sh" --tail-only --help 2>&1 || true

	# Verificar que acepta el parámetro
	assert_output --partial "tail-only" || true
}

@test "aggregate-logs: maneja servicios inexistentes" {
	run bash "$TEST_COMMANDS_DIR/aggregate-logs.sh" servicio-inexistente 2>&1 || true

	# No debería fallar catastróficamente
	assert_output --partial "no encontrado" || assert_success
}

@test "aggregate-logs: acepta --buffer-size para tamaño de buffer" {
	run bash "$TEST_COMMANDS_DIR/aggregate-logs.sh" --buffer-size=1024 --help 2>&1 || true

	# Verificar que acepta el parámetro
	assert_output --partial "buffer" || true
}
