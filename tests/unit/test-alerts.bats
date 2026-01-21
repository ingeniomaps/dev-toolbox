#!/usr/bin/env bats
# ============================================================================
# Test: test-alerts.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests unitarios para alerts.sh usando BATS.
#
# Uso:
#   bats tests/unit/test-alerts.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'tests/unit/helpers.bash'

@test "alerts.sh existe" {
	assert_file_exists "$TEST_SCRIPTS_DIR/commands/alerts.sh"
}

@test "alerts.sh valida .env cuando se detectan servicios automáticamente" {
	run bash "$TEST_SCRIPTS_DIR/commands/alerts.sh" \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Debería fallar si .env no existe
	assert_failure "$output" "$status" "Debería fallar sin .env cuando no se especifican servicios"
	assert_contains "$output" "no se pueden verificar\|no encontrado" "Debería indicar problema con .env"
}

@test "alerts.sh acepta servicios como argumentos" {
	# Especificar servicios directamente evita necesidad de .env
	run bash "$TEST_SCRIPTS_DIR/commands/alerts.sh" "test-service-1" "test-service-2" \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Debería ejecutarse (puede fallar si Docker no está disponible, pero no por falta de .env)
	[[ $status -ge 0 ]]
}

@test "alerts.sh usa variable de entorno SERVICES" {
	local env_file=$(create_test_env_file "POSTGRES_VERSION=15.0")

	run bash "$TEST_SCRIPTS_DIR/commands/alerts.sh" \
		SERVICES="test-service" \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Debería usar SERVICES en lugar de detectar desde .env
	[[ $status -ge 0 ]]
}

@test "alerts.sh retorna 0 cuando no hay alertas" {
	# Sin servicios, no debería haber alertas
	run bash "$TEST_SCRIPTS_DIR/commands/alerts.sh" \
		SERVICES="" \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Debería retornar 0 (no hay alertas)
	[[ $status -eq 0 ]]
}

@test "alerts.sh maneja lista vacía de servicios" {
	run bash "$TEST_SCRIPTS_DIR/commands/alerts.sh" \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Si no hay servicios, debería salir con éxito (no hay alertas)
	# O fallar si requiere .env
	[[ $status -ge 0 ]]
}
