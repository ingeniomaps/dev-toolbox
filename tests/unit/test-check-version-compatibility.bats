#!/usr/bin/env bats
# ============================================================================
# Test: test-check-version-compatibility.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests unitarios para check-version-compatibility.sh usando BATS.
#
# Uso:
#   bats tests/unit/test-check-version-compatibility.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'helpers'

@test "check-version-compatibility.sh existe" {
	assert_file_exists "$TEST_SCRIPTS_DIR/commands/check-version-compatibility.sh"
}

@test "check-version-compatibility.sh requiere servicio y versión" {
	run bash "$TEST_SCRIPTS_DIR/commands/check-version-compatibility.sh"

	assert_failure "$output" "$status" "Debería fallar sin argumentos"
	assert_contains "$output" "Debes especificar" "Debería mostrar mensaje de error"
}

@test "check-version-compatibility.sh valida PostgreSQL >= 14 como compatible" {
	run bash "$TEST_SCRIPTS_DIR/commands/check-version-compatibility.sh" "postgres" "15.0"

	assert_success "$output" "$status" "PostgreSQL 15 debería ser compatible"
	assert_contains "$output" "compatible" "Debería indicar compatibilidad"
}

@test "check-version-compatibility.sh valida PostgreSQL < 14 como incompatible" {
	run bash "$TEST_SCRIPTS_DIR/commands/check-version-compatibility.sh" "postgres" "13.0"

	# Puede retornar warning pero no error fatal
	[[ $status -ge 0 ]]
	assert_contains "$output" "problemas\|recomienda" "Debería advertir sobre versión antigua"
}

@test "check-version-compatibility.sh valida MongoDB >= 6 como compatible" {
	run bash "$TEST_SCRIPTS_DIR/commands/check-version-compatibility.sh" "mongo" "7.0"

	assert_success "$output" "$status" "MongoDB 7 debería ser compatible"
	assert_contains "$output" "compatible" "Debería indicar compatibilidad"
}

@test "check-version-compatibility.sh valida MongoDB < 6 como incompatible" {
	run bash "$TEST_SCRIPTS_DIR/commands/check-version-compatibility.sh" "mongo" "5.0"

	# Puede retornar warning pero no error fatal
	[[ $status -ge 0 ]]
	assert_contains "$output" "problemas\|recomienda" "Debería advertir sobre versión antigua"
}

@test "check-version-compatibility.sh valida Redis >= 6 como compatible" {
	run bash "$TEST_SCRIPTS_DIR/commands/check-version-compatibility.sh" "redis" "7.0"

	assert_success "$output" "$status" "Redis 7 debería ser compatible"
	assert_contains "$output" "compatible" "Debería indicar compatibilidad"
}

@test "check-version-compatibility.sh valida Redis < 6 como incompatible" {
	run bash "$TEST_SCRIPTS_DIR/commands/check-version-compatibility.sh" "redis" "5.0"

	# Puede retornar warning pero no error fatal
	[[ $status -ge 0 ]]
	assert_contains "$output" "problemas\|recomienda" "Debería advertir sobre versión antigua"
}

@test "check-version-compatibility.sh acepta servicios sin validación específica" {
	run bash "$TEST_SCRIPTS_DIR/commands/check-version-compatibility.sh" "mysql" "8.0"

	assert_success "$output" "$status" "Servicios sin validación deberían ser aceptados"
	assert_contains "$output" "no hay validación específica\|asume.*compatible" "Debería indicar que no hay validación específica"
}

@test "check-version-compatibility.sh maneja versiones con sufijos" {
	run bash "$TEST_SCRIPTS_DIR/commands/check-version-compatibility.sh" "postgres" "16.1-alpine"

	assert_success "$output" "$status" "Debería manejar versiones con sufijos"
}
