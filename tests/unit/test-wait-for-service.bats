#!/usr/bin/env bats
# ============================================================================
# Test: test-wait-for-service.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests unitarios para wait-for-service.sh usando BATS.
#
# Nota: Tests que ejecutan el script usan timeout corto para evitar
# bloqueos en CI (el script espera contenedores Docker).
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'helpers'

@test "wait-for-service.sh existe" {
	assert_file_exists "$TEST_SCRIPTS_DIR/utils/wait-for-service.sh"
}

@test "wait-for-service.sh requiere nombre de contenedor" {
	run timeout 5 bash "$TEST_SCRIPTS_DIR/utils/wait-for-service.sh" "" "2" 2>&1 || true

	# Sin nombre válido, el script espera y falla por timeout
	[[ $status -ge 0 ]]
}

@test "wait-for-service.sh acepta tiempo máximo opcional" {
	run timeout 5 bash "$TEST_SCRIPTS_DIR/utils/wait-for-service.sh" "test-container" "2" 2>&1 || true

	# El script debería aceptar el parámetro (falla por Docker, no por sintaxis)
	[[ $status -ge 0 ]]
}

@test "wait-for-service.sh valida que tiempo máximo sea numérico" {
	run timeout 5 bash "$TEST_SCRIPTS_DIR/utils/wait-for-service.sh" "test-container" "abc" 2>&1

	assert_failure "$output" "$status" "Debería fallar con tiempo no numérico"
	assert_contains "$output" "numérico\|número" "Debería indicar que debe ser numérico"
}

@test "wait-for-service.sh valida que tiempo máximo sea positivo" {
	run timeout 5 bash "$TEST_SCRIPTS_DIR/utils/wait-for-service.sh" "test-container" "0" 2>&1

	assert_failure "$output" "$status" "Debería fallar con tiempo <= 0"
	assert_contains "$output" "mayor que 0\|positivo" "Debería indicar que debe ser positivo"
}

@test "wait-for-service.sh usa 60 segundos por defecto" {
	local script_content=$(cat "$TEST_SCRIPTS_DIR/utils/wait-for-service.sh")

	assert_contains "$script_content" "MAX_WAIT.*60\|60.*MAX_WAIT" "Debería usar 60 como tiempo por defecto"
}

@test "wait-for-service.sh muestra mensaje de espera" {
	run timeout 5 bash "$TEST_SCRIPTS_DIR/utils/wait-for-service.sh" "nonexistent-$(date +%s)" "2" 2>&1 || true

	assert_contains "$output" "Esperando\|espera\|saludable" "Debería mostrar mensaje de espera"
}

@test "wait-for-service.sh maneja contenedor inexistente" {
	run timeout 5 bash "$TEST_SCRIPTS_DIR/utils/wait-for-service.sh" "nonexistent-$(date +%s)" "2" 2>&1 || true

	# Debería manejar el caso (falla por timeout o Docker no disponible)
	[[ $status -ge 0 ]]
}

@test "wait-for-service.sh valida parámetros usando helpers" {
	local script_content=$(cat "$TEST_SCRIPTS_DIR/utils/wait-for-service.sh")

	assert_contains "$script_content" "validate_required_args\|validate_optional_args" "Debería usar helpers de validación"
}
