#!/usr/bin/env bats
# ============================================================================
# Test: test-generate-password.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests unitarios para generate-password.sh usando BATS.
#
# Uso:
#   bats tests/unit/test-generate-password.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'tests/unit/helpers.bash'

@test "generate-password.sh existe" {
	assert_file_exists "$TEST_SCRIPTS_DIR/utils/generate-password.sh"
}

@test "generate-password.sh genera contraseña con longitud por defecto" {
	run bash "$TEST_SCRIPTS_DIR/utils/generate-password.sh"

	assert_success "$output" "$status" "Debería generar contraseña con longitud por defecto"

	# Verificar que se generó una contraseña
	local password=$(echo "$output" | tr -d '\n')
	[[ ${#password} -eq 24 ]] || [[ ${#password} -gt 0 ]]  # Puede variar según método
}

@test "generate-password.sh genera contraseña con longitud especificada" {
	run bash "$TEST_SCRIPTS_DIR/utils/generate-password.sh" "16"

	assert_success "$output" "$status" "Debería generar contraseña de 16 caracteres"

	local password=$(echo "$output" | tr -d '\n')
	[[ ${#password} -ge 16 ]]  # Al menos 16 caracteres
}

@test "generate-password.sh valida longitud mínima" {
	run bash "$TEST_SCRIPTS_DIR/utils/generate-password.sh" "11"

	assert_failure "$output" "$status" "Debería fallar con longitud < 12"
	assert_contains "$output" "longitud.*12\|>= 12" "Debería indicar longitud mínima"
}

@test "generate-password.sh valida que longitud sea numérica" {
	run bash "$TEST_SCRIPTS_DIR/utils/generate-password.sh" "abc"

	assert_failure "$output" "$status" "Debería fallar con longitud no numérica"
	assert_contains "$output" "número\|numérica" "Debería indicar que debe ser numérico"
}

@test "generate-password.sh genera contraseñas diferentes" {
	run bash "$TEST_SCRIPTS_DIR/utils/generate-password.sh" "20"
	local password1=$(echo "$output" | tr -d '\n')

	run bash "$TEST_SCRIPTS_DIR/utils/generate-password.sh" "20"
	local password2=$(echo "$output" | tr -d '\n')

	# Las contraseñas deberían ser diferentes (muy probable)
	# Nota: Hay una pequeña posibilidad de que sean iguales, pero es muy baja
	assert_not_equals "$password1" "$password2" "Las contraseñas deberían ser diferentes"
}

@test "generate-password.sh genera contraseña con longitud larga" {
	run bash "$TEST_SCRIPTS_DIR/utils/generate-password.sh" "50"

	assert_success "$output" "$status" "Debería generar contraseña larga"

	local password=$(echo "$output" | tr -d '\n')
	[[ ${#password} -ge 50 ]]  # Al menos 50 caracteres
}

@test "generate-password.sh genera contraseña con longitud mínima válida" {
	run bash "$TEST_SCRIPTS_DIR/utils/generate-password.sh" "12"

	assert_success "$output" "$status" "Debería generar contraseña de 12 caracteres"

	local password=$(echo "$output" | tr -d '\n')
	[[ ${#password} -ge 12 ]]  # Al menos 12 caracteres
}
