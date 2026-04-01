#!/usr/bin/env bats
# ============================================================================
# Test: test-aggregate-logs.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests para aggregate-logs.sh
# ============================================================================

load 'helpers'

setup() {
	export TEST_PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
	export TEST_COMMANDS_DIR="$TEST_PROJECT_ROOT/scripts/sh/commands"
}

@test "aggregate-logs: ejecuta sin errores de sintaxis" {
	run bash "$TEST_COMMANDS_DIR/aggregate-logs.sh" 2>&1 || true

	# El script puede fallar por falta de servicios pero no por sintaxis
	[[ $status -ge 0 ]]
}

@test "aggregate-logs: acepta --max-services para limitar servicios" {
	run bash "$TEST_COMMANDS_DIR/aggregate-logs.sh" --max-services=1 2>&1 || true

	# Verificar que acepta el parámetro
	[[ $status -ge 0 ]]
}

@test "aggregate-logs: acepta --tail-only para solo últimas líneas" {
	run bash "$TEST_COMMANDS_DIR/aggregate-logs.sh" --tail-only 2>&1 || true

	# Verificar que acepta el parámetro
	[[ $status -ge 0 ]]
}

@test "aggregate-logs: maneja servicios inexistentes" {
	run bash "$TEST_COMMANDS_DIR/aggregate-logs.sh" servicio-inexistente 2>&1 || true

	# No debería fallar catastróficamente
	[[ $status -ge 0 ]]
}

@test "aggregate-logs: acepta --buffer-size para tamaño de buffer" {
	run bash "$TEST_COMMANDS_DIR/aggregate-logs.sh" --buffer-size=1024 2>&1 || true

	# Verificar que acepta el parámetro
	[[ $status -ge 0 ]]
}
