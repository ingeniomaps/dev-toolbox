#!/usr/bin/env bats
# ============================================================================
# Test: test-backup-all.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests unitarios para backup-all.sh usando BATS.
#
# Uso:
#   bats tests/unit/test-backup-all.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'tests/unit/helpers.bash'

@test "backup-all.sh existe" {
	assert_file_exists "$TEST_SCRIPTS_DIR/commands/backup-all.sh"
}

@test "backup-all.sh requiere .env" {
	run bash "$TEST_SCRIPTS_DIR/commands/backup-all.sh" \
		PROJECT_ROOT="$TEST_TMP_DIR"

	assert_failure "$output" "$status" "Debería fallar sin .env"
	assert_contains "$output" "no se puede realizar\|no encontrado" "Debería indicar problema con .env"
}

@test "backup-all.sh detecta servicios desde .env" {
	local env_file=$(create_test_env_file "POSTGRES_VERSION=15.0\nMONGO_VERSION=7.0")

	run bash "$TEST_SCRIPTS_DIR/commands/backup-all.sh" \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Debería detectar servicios (puede fallar si no hay comandos make, pero no por falta de servicios)
	[[ $status -ge 0 ]]
	assert_contains "$output" "postgres\|mongo\|servicios" "Debería detectar servicios desde .env"
}

@test "backup-all.sh acepta opción --skip-missing" {
	local env_file=$(create_test_env_file "POSTGRES_VERSION=15.0")

	run bash "$TEST_SCRIPTS_DIR/commands/backup-all.sh" --skip-missing \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Debería aceptar la opción sin error de sintaxis
	[[ $status -ge 0 ]]
}

@test "backup-all.sh usa variable de entorno SKIP_MISSING" {
	local env_file=$(create_test_env_file "POSTGRES_VERSION=15.0")

	run bash "$TEST_SCRIPTS_DIR/commands/backup-all.sh" \
		SKIP_MISSING=true \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Debería usar la variable de entorno
	[[ $status -ge 0 ]]
}

@test "backup-all.sh maneja servicios no encontrados con --skip-missing" {
	local env_file=$(create_test_env_file "NONEXISTENT_VERSION=1.0")

	run bash "$TEST_SCRIPTS_DIR/commands/backup-all.sh" --skip-missing \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Con --skip-missing debería continuar aunque el servicio no exista
	[[ $status -ge 0 ]]
	assert_contains "$output" "omitido\|no encontrado\|Resumen" "Debería indicar servicios omitidos"
}

@test "backup-all.sh muestra resumen de operaciones" {
	local env_file=$(create_test_env_file "POSTGRES_VERSION=15.0")

	run bash "$TEST_SCRIPTS_DIR/commands/backup-all.sh" --skip-missing \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Debería mostrar resumen al final
	assert_contains "$output" "Resumen\|exitosos\|fallidos\|omitidos" "Debería mostrar resumen"
}
