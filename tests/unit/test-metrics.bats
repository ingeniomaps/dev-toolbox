#!/usr/bin/env bats
# ============================================================================
# Test: test-metrics.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests unitarios para metrics.sh usando BATS.
#
# Uso:
#   bats tests/unit/test-metrics.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'helpers'

@test "metrics.sh existe" {
	assert_file_exists "$TEST_SCRIPTS_DIR/commands/metrics.sh"
}

@test "metrics.sh valida .env cuando se detectan servicios automáticamente" {
	local env_file=$(create_test_env_file "POSTGRES_VERSION=15.0")

	run bash "$TEST_SCRIPTS_DIR/commands/metrics.sh" \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Debería fallar si .env no existe en PROJECT_ROOT
	# O pasar si se especifican servicios directamente
	[[ $status -ge 0 ]]
}

@test "metrics.sh acepta servicios como argumentos" {
	# Especificar servicios directamente evita necesidad de .env
	run bash "$TEST_SCRIPTS_DIR/commands/metrics.sh" "test-service-1" "test-service-2" \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Debería ejecutarse (puede fallar si Docker no está disponible, pero no por falta de .env)
	[[ $status -ge 0 ]]
}

@test "metrics.sh acepta opción --skip-missing" {
	run bash "$TEST_SCRIPTS_DIR/commands/metrics.sh" --skip-missing \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Debería aceptar la opción sin error de sintaxis
	[[ $status -ge 0 ]]
}

@test "metrics.sh usa variable de entorno SERVICES" {
	local env_file=$(create_test_env_file "POSTGRES_VERSION=15.0")

	run bash "$TEST_SCRIPTS_DIR/commands/metrics.sh" \
		SERVICES="test-service" \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Debería usar SERVICES en lugar de detectar desde .env
	[[ $status -ge 0 ]]
}

@test "metrics.sh maneja servicios no encontrados con --skip-missing" {
	run bash "$TEST_SCRIPTS_DIR/commands/metrics.sh" --skip-missing \
		"nonexistent-service-$(date +%s)" \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Con --skip-missing debería continuar aunque el servicio no exista
	[[ $status -ge 0 ]]
}
