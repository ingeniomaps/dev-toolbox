#!/usr/bin/env bats
# ============================================================================
# Test: test-replace-env-var.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests unitarios para replace-env-var.sh usando BATS.
#
# Uso:
#   bats tests/unit/test-replace-env-var.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'tests/unit/helpers.bash'

@test "replace-env-var.sh existe" {
	assert_file_exists "$TEST_SCRIPTS_DIR/utils/replace-env-var.sh"
}

@test "replace-env-var.sh requiere 3 argumentos" {
	run bash "$TEST_SCRIPTS_DIR/utils/replace-env-var.sh"

	assert_failure "$output" "$status" "Debería fallar sin argumentos"
	assert_contains "$output" "3 argumentos\|Uso:" "Debería indicar que se requieren 3 argumentos"
}

@test "replace-env-var.sh agrega variable nueva a .env" {
	local env_file=$(create_test_env_file "NETWORK_NAME=test-network")

	run bash "$TEST_SCRIPTS_DIR/utils/replace-env-var.sh" "$env_file" "POSTGRES_VERSION" "15.0"

	assert_success "$output" "$status" "Debería agregar variable nueva"
	assert_contains "$output" "agregada\|agregado" "Debería indicar que se agregó"

	# Verificar que se agregó
	local env_content=$(cat "$env_file")
	assert_contains "$env_content" "POSTGRES_VERSION=15.0" "Debería contener la nueva variable"
}

@test "replace-env-var.sh reemplaza variable existente" {
	local env_file=$(create_test_env_file "POSTGRES_VERSION=14.0\nNETWORK_NAME=test")

	run bash "$TEST_SCRIPTS_DIR/utils/replace-env-var.sh" "$env_file" "POSTGRES_VERSION" "15.0"

	assert_success "$output" "$status" "Debería reemplazar variable existente"
	assert_contains "$output" "actualizada\|actualizado" "Debería indicar que se actualizó"

	# Verificar que se reemplazó
	local env_content=$(cat "$env_file")
	assert_contains "$env_content" "POSTGRES_VERSION=15.0" "Debería contener el nuevo valor"
	assert_not_contains "$env_content" "POSTGRES_VERSION=14.0" "No debería contener el valor antiguo"
}

@test "replace-env-var.sh falla si archivo no existe" {
	run bash "$TEST_SCRIPTS_DIR/utils/replace-env-var.sh" "/tmp/nonexistent.env" "VAR" "value"

	assert_failure "$output" "$status" "Debería fallar si archivo no existe"
	assert_contains "$output" "no encontrado\|no existe" "Debería indicar que el archivo no existe"
}

@test "replace-env-var.sh valida nombre de variable" {
	local env_file=$(create_test_env_file "NETWORK_NAME=test")

	run bash "$TEST_SCRIPTS_DIR/utils/replace-env-var.sh" "$env_file" "INVALID-VAR" "value"

	assert_failure "$output" "$status" "Debería fallar con nombre de variable inválido"
	assert_contains "$output" "inválido\|solo.*A-Z" "Debería indicar que el nombre es inválido"
}

@test "replace-env-var.sh maneja valores con caracteres especiales" {
	local env_file=$(create_test_env_file "NETWORK_NAME=test")

	run bash "$TEST_SCRIPTS_DIR/utils/replace-env-var.sh" "$env_file" "TEST_VAR" "value with spaces and @#$%"

	assert_success "$output" "$status" "Debería manejar valores con caracteres especiales"

	# Verificar que se guardó correctamente
	local env_content=$(cat "$env_file")
	assert_contains "$env_content" "TEST_VAR=" "Debería contener la variable"
}

@test "replace-env-var.sh preserva otras variables" {
	local env_file=$(create_test_env_file "NETWORK_NAME=test-network\nMONGO_VERSION=7.0")

	run bash "$TEST_SCRIPTS_DIR/utils/replace-env-var.sh" "$env_file" "POSTGRES_VERSION" "15.0"

	# Verificar que se preservaron otras variables
	local env_content=$(cat "$env_file")
	assert_contains "$env_content" "NETWORK_NAME=test-network" "Debería preservar NETWORK_NAME"
	assert_contains "$env_content" "MONGO_VERSION=7.0" "Debería preservar MONGO_VERSION"
}

@test "replace-env-var.sh maneja valores vacíos" {
	local env_file=$(create_test_env_file "NETWORK_NAME=test")

	run bash "$TEST_SCRIPTS_DIR/utils/replace-env-var.sh" "$env_file" "EMPTY_VAR" ""

	assert_success "$output" "$status" "Debería permitir valores vacíos"

	local env_content=$(cat "$env_file")
	assert_contains "$env_content" "EMPTY_VAR=" "Debería contener variable con valor vacío"
}
