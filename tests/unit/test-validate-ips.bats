#!/usr/bin/env bats
# ============================================================================
# Test: test-validate-ips.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests unitarios para validate-ips.sh usando BATS.
#
# Uso:
#   bats tests/unit/test-validate-ips.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'tests/unit/helpers.bash'

@test "validate-ips.sh existe" {
	assert_file_exists "$TEST_SCRIPTS_DIR/commands/validate-ips.sh"
}

@test "validate-ips.sh valida IPs válidas" {
	local env_file=$(create_test_env_file "NETWORK_IP=192.168.1.0\nPOSTGRES_HOST=10.0.0.1\nMONGO_IP=172.16.0.1")

	run bash "$TEST_SCRIPTS_DIR/commands/validate-ips.sh" "$env_file"

	assert_success "$output" "$status" "Debería validar IPs válidas exitosamente"
	assert_contains "$output" "válida\|válidas" "Debería indicar que las IPs son válidas"
}

@test "validate-ips.sh detecta IPs inválidas" {
	local env_file=$(create_test_env_file "NETWORK_IP=256.1.1.1\nPOSTGRES_HOST=192.168.1")

	run bash "$TEST_SCRIPTS_DIR/commands/validate-ips.sh" "$env_file"

	assert_failure "$output" "$status" "Debería fallar con IPs inválidas"
	assert_contains "$output" "inválida\|inválidas" "Debería indicar que hay IPs inválidas"
}

@test "validate-ips.sh maneja archivo .env inexistente" {
	run bash "$TEST_SCRIPTS_DIR/commands/validate-ips.sh" "/tmp/nonexistent.env"

	# Debería salir con éxito (no es error si no existe)
	[[ $status -eq 0 ]]
	assert_contains "$output" "no encontrado" "Debería indicar que el archivo no existe"
}

@test "validate-ips.sh ignora comentarios" {
	local env_file=$(create_test_env_file "# NETWORK_IP=192.168.1.0\nNETWORK_IP=10.0.0.1")

	run bash "$TEST_SCRIPTS_DIR/commands/validate-ips.sh" "$env_file"

	assert_success "$output" "$status" "Debería ignorar líneas comentadas"
}

@test "validate-ips.sh maneja IPs con comillas" {
	local env_file=$(create_test_env_file "NETWORK_IP=\"192.168.1.0\"\nPOSTGRES_HOST='10.0.0.1'")

	run bash "$TEST_SCRIPTS_DIR/commands/validate-ips.sh" "$env_file"

	assert_success "$output" "$status" "Debería manejar IPs con comillas"
}

@test "validate-ips.sh detecta variables _HOST, _IP y NETWORK_IP" {
	local env_file=$(create_test_env_file "NETWORK_IP=192.168.1.0\nPOSTGRES_HOST=10.0.0.1\nMONGO_IP=172.16.0.1")

	run bash "$TEST_SCRIPTS_DIR/commands/validate-ips.sh" "$env_file"

	assert_success "$output" "$status" "Debería detectar todas las variables de IP"
	assert_contains "$output" "192.168.1.0\|10.0.0.1\|172.16.0.1" "Debería validar todas las IPs encontradas"
}

@test "validate-ips.sh maneja archivo sin variables de IP" {
	local env_file=$(create_test_env_file "POSTGRES_VERSION=15.0\nMONGO_VERSION=7.0")

	run bash "$TEST_SCRIPTS_DIR/commands/validate-ips.sh" "$env_file"

	# Debería salir con éxito (no es error si no hay IPs)
	[[ $status -eq 0 ]]
	assert_contains "$output" "No se encontraron\|no encontrado" "Debería indicar que no hay IPs para validar"
}

@test "validate-ips.sh valida octetos fuera de rango" {
	local env_file=$(create_test_env_file "NETWORK_IP=999.1.1.1\nPOSTGRES_HOST=192.256.1.1")

	run bash "$TEST_SCRIPTS_DIR/commands/validate-ips.sh" "$env_file"

	assert_failure "$output" "$status" "Debería fallar con octetos fuera de rango"
}
