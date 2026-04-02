#!/usr/bin/env bats
# ============================================================================
# Test: test-validate-password-complexity.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests unitarios para validate-password-complexity.sh usando BATS.
#
# Uso:
#   bats tests/unit/test-validate-password-complexity.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'helpers'

@test "validate-password-complexity.sh existe" {
	assert_file_exists "$TEST_SCRIPTS_DIR/utils/validate-password-complexity.sh"
}

@test "validate-password-complexity.sh requiere contraseña" {
	run bash "$TEST_SCRIPTS_DIR/utils/validate-password-complexity.sh"

	assert_failure "$output" "$status" "Debería fallar sin contraseña"
	assert_contains "$output" "proporcionar\|requerido" "Debería indicar que se requiere contraseña"
}

@test "validate-password-complexity.sh valida contraseña segura" {
	local secure_password="MySecureP@ssw0rd123"

	run bash "$TEST_SCRIPTS_DIR/utils/validate-password-complexity.sh" "$secure_password"

	assert_success "$output" "$status" "Debería aceptar contraseña segura"
	assert_contains "$output" "cumple\|válida\|éxito" "Debería indicar que cumple requisitos"
}

@test "validate-password-complexity.sh rechaza contraseña corta" {
	run bash "$TEST_SCRIPTS_DIR/utils/validate-password-complexity.sh" "Short1!"

	assert_failure "$output" "$status" "Debería rechazar contraseña corta"
	assert_contains "$output" "12 caracteres\|longitud" "Debería indicar longitud mínima"
}

@test "validate-password-complexity.sh rechaza contraseña sin mayúsculas" {
	run bash "$TEST_SCRIPTS_DIR/utils/validate-password-complexity.sh" "mypassword123!"

	assert_failure "$output" "$status" "Debería rechazar contraseña sin mayúsculas"
	assert_contains "$output" "mayúscula" "Debería indicar falta de mayúsculas"
}

@test "validate-password-complexity.sh rechaza contraseña sin minúsculas" {
	run bash "$TEST_SCRIPTS_DIR/utils/validate-password-complexity.sh" "MYPASSWORD123!"

	assert_failure "$output" "$status" "Debería rechazar contraseña sin minúsculas"
	assert_contains "$output" "minúscula" "Debería indicar falta de minúsculas"
}

@test "validate-password-complexity.sh rechaza contraseña sin números" {
	run bash "$TEST_SCRIPTS_DIR/utils/validate-password-complexity.sh" "MyPassword!"

	assert_failure "$output" "$status" "Debería rechazar contraseña sin números"
	assert_contains "$output" "número" "Debería indicar falta de números"
}

@test "validate-password-complexity.sh rechaza contraseña sin caracteres especiales" {
	run bash "$TEST_SCRIPTS_DIR/utils/validate-password-complexity.sh" "MyPassword123"

	assert_failure "$output" "$status" "Debería rechazar contraseña sin caracteres especiales"
	assert_contains "$output" "especial" "Debería indicar falta de caracteres especiales"
}

@test "validate-password-complexity.sh rechaza contraseñas comunes débiles" {
	run bash "$TEST_SCRIPTS_DIR/utils/validate-password-complexity.sh" "password123!"

	assert_failure "$output" "$status" "Debería rechazar contraseña común débil"
	assert_contains "$output" "débil\|común\|patrón" "Debería indicar patrón débil"
}

@test "validate-password-complexity.sh rechaza múltiples problemas" {
	run bash "$TEST_SCRIPTS_DIR/utils/validate-password-complexity.sh" "short"

	assert_failure "$output" "$status" "Debería rechazar contraseña con múltiples problemas"
	# Puede mostrar múltiples errores
	[[ $status -eq 1 ]]
}
