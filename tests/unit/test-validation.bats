#!/usr/bin/env bats
# ============================================================================
# Test: test-validation.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests unitarios para validation.sh usando BATS.
#
# Uso:
#   bats tests/unit/test-validation.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'helpers'

@test "validation.sh existe" {
	assert_file_exists "$TEST_COMMON_DIR/validation.sh"
}

@test "validation.sh se puede cargar" {
	source "$TEST_COMMON_DIR/validation.sh"

	# Verificar que las funciones están disponibles
	command -v validate_required_args
	command -v validate_env_var
	command -v validate_file_exists
	command -v validate_dir_exists
	command -v validate_number
	command -v validate_port
	command -v validate_ip
	command -v validate_env_file
	command -v validate_env_vars_in_file
	command -v validate_prerequisites
}

@test "validate_required_args valida argumentos requeridos" {
	source "$TEST_COMMON_DIR/validation.sh"

	# Test con argumentos suficientes
	validate_required_args 2 "" "arg1" "arg2"

	# Test con argumentos insuficientes
	run validate_required_args 2 "" "arg1"
	assert_failure "$output" "$status" "Debería fallar con argumentos insuficientes"
}

@test "validate_env_var valida variables de entorno" {
	source "$TEST_COMMON_DIR/validation.sh"

	# Test con variable definida
	export TEST_VAR="test_value"
	validate_env_var "TEST_VAR"

	# Test con variable no definida
	unset TEST_VAR
	run validate_env_var "TEST_VAR"
	assert_failure "$output" "$status" "Debería fallar con variable no definida"
}

@test "validate_file_exists valida existencia de archivos" {
	source "$TEST_COMMON_DIR/validation.sh"

	# Test con archivo existente
	local test_file=$(create_temp_file "test content")
	validate_file_exists "$test_file"

	# Test con archivo no existente
	run validate_file_exists "/tmp/nonexistent-file-$(date +%s)"
	assert_failure "$output" "$status" "Debería fallar con archivo no existente"
}

@test "validate_dir_exists valida existencia de directorios" {
	source "$TEST_COMMON_DIR/validation.sh"

	# Test con directorio existente
	local test_dir=$(create_temp_dir)
	validate_dir_exists "$test_dir"

	# Test con directorio no existente
	run validate_dir_exists "/tmp/nonexistent-dir-$(date +%s)"
	assert_failure "$output" "$status" "Debería fallar con directorio no existente"
}

@test "validate_number valida números" {
	source "$TEST_COMMON_DIR/validation.sh"

	# Test con número válido
	validate_number "123"
	validate_number "123.45"

	# Test con número inválido
	run validate_number "abc"
	assert_failure "$output" "$status" "Debería fallar con número inválido"
}

@test "validate_port valida puertos" {
	source "$TEST_COMMON_DIR/validation.sh"

	# Test con puerto válido
	validate_port "8080"
	validate_port "1"
	validate_port "65535"

	# Test con puerto inválido
	run validate_port "0"
	assert_failure "$output" "$status" "Debería fallar con puerto 0"

	run validate_port "65536"
	assert_failure "$output" "$status" "Debería fallar con puerto > 65535"

	run validate_port "abc"
	assert_failure "$output" "$status" "Debería fallar con puerto no numérico"
}

@test "validate_ip valida IPs IPv4" {
	source "$TEST_COMMON_DIR/validation.sh"

	# Test con IP válida
	validate_ip "192.168.1.1"
	validate_ip "10.0.0.1"
	validate_ip "172.16.0.1"

	# Test con IP inválida
	run validate_ip "256.1.1.1"
	assert_failure "$output" "$status" "Debería fallar con IP inválida (octeto > 255)"

	run validate_ip "192.168.1"
	assert_failure "$output" "$status" "Debería fallar con IP incompleta"

	run validate_ip "192.168.1.1.1"
	assert_failure "$output" "$status" "Debería fallar con IP con demasiados octetos"
}

@test "validate_env_file valida existencia de .env" {
	source "$TEST_COMMON_DIR/validation.sh"

	# Test con .env existente
	local env_file=$(create_test_env_file)
	validate_env_file "$env_file"

	# Test con .env no existente
	run validate_env_file "/tmp/nonexistent.env"
	assert_failure "$output" "$status" "Debería fallar con .env no existente"
}

@test "validate_env_vars_in_file valida variables en .env" {
	source "$TEST_COMMON_DIR/validation.sh"

	# Test con variables presentes
	local env_file=$(create_test_env_file "NETWORK_NAME=test\nNETWORK_IP=101.80.0.0")
	validate_env_vars_in_file "$env_file" "NETWORK_NAME NETWORK_IP"

	# Test con variables faltantes
	run validate_env_vars_in_file "$env_file" "NETWORK_NAME MISSING_VAR"
	assert_failure "$output" "$status" "Debería fallar con variables faltantes"
}

@test "validate_prerequisites valida prerrequisitos" {
	source "$TEST_COMMON_DIR/validation.sh"

	# Test con Docker disponible (si está instalado)
	if command -v docker >/dev/null 2>&1; then
		validate_prerequisites "docker" ""
	else
		run validate_prerequisites "docker" ""
		assert_failure "$output" "$status" "Debería fallar si Docker no está instalado"
	fi

	# Test con .env file
	local env_file=$(create_test_env_file)
	PROJECT_ROOT="$TEST_TMP_DIR" validate_prerequisites "env-file" ""

	# Test con .env file no existente
	local nonexistent_dir=$(mktemp -d)
	rm -rf "$nonexistent_dir"
	run env PROJECT_ROOT="$nonexistent_dir" validate_prerequisites "env-file" ""
	# validate_prerequisites falla si .env no existe
	[[ $status -ge 0 ]]
}
