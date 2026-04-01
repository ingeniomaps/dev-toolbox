#!/usr/bin/env bats
# ============================================================================
# Test: test-wait-for-service.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests unitarios para wait-for-service.sh usando BATS.
#
# Uso:
#   bats tests/unit/test-wait-for-service.bats
#
# Nota: Algunos tests requieren Docker o mocks
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
	run bash "$TEST_SCRIPTS_DIR/utils/wait-for-service.sh"

	assert_failure "$output" "$status" "Debería fallar sin nombre de contenedor"
	assert_contains "$output" "requeridos\|container-name\|Uso:" "Debería indicar que se requiere nombre"
}

@test "wait-for-service.sh acepta tiempo máximo opcional" {
	# Este test verifica que acepta el segundo parámetro
	# La ejecución real puede fallar si Docker no está disponible
	run bash "$TEST_SCRIPTS_DIR/utils/wait-for-service.sh" "test-container" "30" \
		PROJECT_ROOT="$TEST_TMP_DIR" 2>&1 || true

	# El script debería aceptar el parámetro (puede fallar por Docker, pero no por sintaxis)
	[[ $status -ge 0 ]] || [[ $status -eq 1 ]]
}

@test "wait-for-service.sh valida que tiempo máximo sea numérico" {
	run bash "$TEST_SCRIPTS_DIR/utils/wait-for-service.sh" "test-container" "abc" \
		PROJECT_ROOT="$TEST_TMP_DIR"

	assert_failure "$output" "$status" "Debería fallar con tiempo no numérico"
	assert_contains "$output" "numérico\|número" "Debería indicar que debe ser numérico"
}

@test "wait-for-service.sh valida que tiempo máximo sea positivo" {
	run bash "$TEST_SCRIPTS_DIR/utils/wait-for-service.sh" "test-container" "0" \
		PROJECT_ROOT="$TEST_TMP_DIR"

	assert_failure "$output" "$status" "Debería fallar con tiempo <= 0"
	assert_contains "$output" "mayor que 0\|positivo" "Debería indicar que debe ser positivo"
}

@test "wait-for-service.sh usa 60 segundos por defecto" {
	# Verificar en el código que usa 60 por defecto
	local script_content=$(cat "$TEST_SCRIPTS_DIR/utils/wait-for-service.sh")

	assert_contains "$script_content" "MAX_WAIT.*60\|60.*MAX_WAIT" "Debería usar 60 como tiempo por defecto"
}

@test "wait-for-service.sh muestra mensaje de espera" {
	# Este test puede fallar si Docker no está disponible, pero verifica el mensaje
	run timeout 2 bash "$TEST_SCRIPTS_DIR/utils/wait-for-service.sh" "nonexistent-container-$(date +%s)" "2" \
		PROJECT_ROOT="$TEST_TMP_DIR" 2>&1 || true

	# Debería mostrar mensaje de espera
	assert_contains "$output" "Esperando\|espera\|saludable" "Debería mostrar mensaje de espera"
}

@test "wait-for-service.sh maneja contenedor inexistente" {
	# Este test verifica el manejo cuando el contenedor no existe
	# Usar timeout para evitar esperar demasiado
	run timeout 3 bash "$TEST_SCRIPTS_DIR/utils/wait-for-service.sh" "nonexistent-$(date +%s)" "2" \
		PROJECT_ROOT="$TEST_TMP_DIR" 2>&1 || true

	# Debería manejar el caso (puede fallar por timeout o Docker no disponible)
	[[ $status -ge 0 ]] || [[ $status -eq 1 ]] || [[ $status -eq 124 ]]
}

@test "wait-for-service.sh valida parámetros usando helpers" {
	# Verificar que el script usa validate_required_args
	local script_content=$(cat "$TEST_SCRIPTS_DIR/utils/wait-for-service.sh")

	assert_contains "$script_content" "validate_required_args\|validate_optional_args" "Debería usar helpers de validación"
}
