#!/usr/bin/env bash
# ============================================================================
# Test Helpers
# Ubicación: tests/unit/
# ============================================================================
# Helpers comunes para tests unitarios con BATS.
#
# Uso:
#   load 'helpers'
#
# Funciones disponibles:
#   setup_test_environment - Configura entorno de test
#   teardown_test_environment - Limpia entorno de test
#   create_temp_file - Crea archivo temporal
#   create_temp_dir - Crea directorio temporal
#   assert_file_exists - Verifica que archivo existe
#   assert_file_not_exists - Verifica que archivo no existe
#   assert_dir_exists - Verifica que directorio existe
#   assert_contains - Verifica que string contiene substring
#   assert_not_contains - Verifica que string no contiene substring
#   assert_equals - Verifica que dos valores son iguales
#   assert_not_equals - Verifica que dos valores no son iguales
#   assert_success - Verifica que comando exitó con éxito
#   assert_failure - Verifica que comando falló
# ============================================================================

# Setup común para todos los tests
setup() {
	# Directorio del proyecto
	export TEST_PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
	export TEST_COMMON_DIR="$TEST_PROJECT_ROOT/scripts/sh/common"
	export TEST_SCRIPTS_DIR="$TEST_PROJECT_ROOT/scripts/sh"

	# Directorio temporal para tests
	export TEST_TMP_DIR=$(mktemp -d)
	export TEST_TMP_FILE=$(mktemp)

	# Variables de entorno para tests
	export TEST_ENV_FILE="$TEST_TMP_DIR/.env"
	export TEST_PROJECT_ROOT_FOR_TEST="$TEST_TMP_DIR/test-project"

	# Crear estructura de directorios de test
	mkdir -p "$TEST_PROJECT_ROOT_FOR_TEST"

	# Limpiar variables que puedan interferir
	unset PROJECT_ROOT
	unset SCRIPT_DIR
	unset NETWORK_NAME
	unset NETWORK_IP
}

# Teardown común para todos los tests
teardown() {
	# Limpiar archivos temporales
	if [[ -n "${TEST_TMP_DIR:-}" ]] && [[ -d "$TEST_TMP_DIR" ]]; then
		rm -rf "$TEST_TMP_DIR"
	fi

	if [[ -n "${TEST_TMP_FILE:-}" ]] && [[ -f "$TEST_TMP_FILE" ]]; then
		rm -f "$TEST_TMP_FILE"
	fi

	# Limpiar variables de entorno de test
	unset TEST_PROJECT_ROOT
	unset TEST_COMMON_DIR
	unset TEST_SCRIPTS_DIR
	unset TEST_TMP_DIR
	unset TEST_TMP_FILE
	unset TEST_ENV_FILE
	unset TEST_PROJECT_ROOT_FOR_TEST
}

# ============================================================================
# Funciones Helper para Tests
# ============================================================================

# Crea un archivo temporal con contenido
# Uso: create_temp_file "contenido" -> retorna ruta del archivo
create_temp_file() {
	local content="${1:-}"
	local file=$(mktemp)

	if [[ -n "$content" ]]; then
		echo "$content" > "$file"
	fi

	echo "$file"
}

# Crea un directorio temporal
# Uso: create_temp_dir -> retorna ruta del directorio
create_temp_dir() {
	mktemp -d
}

# Crea un archivo .env de prueba
# Uso: create_test_env_file "NETWORK_NAME=test\nNETWORK_IP=101.80.0.0"
create_test_env_file() {
	local content="${1:-}"
	local env_file="$TEST_TMP_DIR/.env"

	if [[ -n "$content" ]]; then
		echo -e "$content" > "$env_file"
	else
		cat > "$env_file" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=101.80.0.0
POSTGRES_VERSION=15.0
MONGO_VERSION=7.0
EOF
	fi

	echo "$env_file"
}

# ============================================================================
# Funciones de Aserción
# ============================================================================

# Verifica que un archivo existe
assert_file_exists() {
	local file="$1"
	local message="${2:-Archivo debería existir: $file}"

	if [[ ! -f "$file" ]]; then
		echo "❌ FAIL: $message"
		return 1
	fi
	return 0
}

# Verifica que un archivo no existe
assert_file_not_exists() {
	local file="$1"
	local message="${2:-Archivo no debería existir: $file}"

	if [[ -f "$file" ]]; then
		echo "❌ FAIL: $message"
		return 1
	fi
	return 0
}

# Verifica que un directorio existe
assert_dir_exists() {
	local dir="$1"
	local message="${2:-Directorio debería existir: $dir}"

	if [[ ! -d "$dir" ]]; then
		echo "❌ FAIL: $message"
		return 1
	fi
	return 0
}

# Verifica que un string contiene un substring
assert_contains() {
	local haystack="$1"
	local needle="$2"
	local message="${3:-String debería contener: $needle}"

	if [[ "$haystack" != *"$needle"* ]]; then
		echo "❌ FAIL: $message"
		echo "   Haystack: $haystack"
		echo "   Needle: $needle"
		return 1
	fi
	return 0
}

# Verifica que un string no contiene un substring
assert_not_contains() {
	local haystack="$1"
	local needle="$2"
	local message="${3:-String no debería contener: $needle}"

	if [[ "$haystack" == *"$needle"* ]]; then
		echo "❌ FAIL: $message"
		echo "   Haystack: $haystack"
		echo "   Needle: $needle"
		return 1
	fi
	return 0
}

# Verifica que dos valores son iguales
assert_equals() {
	local expected="$1"
	local actual="$2"
	local message="${3:-Valores deberían ser iguales}"

	if [[ "$expected" != "$actual" ]]; then
		echo "❌ FAIL: $message"
		echo "   Expected: $expected"
		echo "   Actual: $actual"
		return 1
	fi
	return 0
}

# Verifica que dos valores no son iguales
assert_not_equals() {
	local expected="$1"
	local actual="$2"
	local message="${3:-Valores no deberían ser iguales}"

	if [[ "$expected" == "$actual" ]]; then
		echo "❌ FAIL: $message"
		echo "   Expected: $expected"
		echo "   Actual: $actual"
		return 1
	fi
	return 0
}

# Verifica que un comando exitó con éxito
assert_success() {
	local command_output="$1"
	local exit_code="${2:-0}"
	local message="${3:-Comando debería exitir con éxito}"

	if [[ $exit_code -ne 0 ]]; then
		echo "❌ FAIL: $message"
		echo "   Exit code: $exit_code"
		echo "   Output: $command_output"
		return 1
	fi
	return 0
}

# Verifica que un comando falló
assert_failure() {
	local command_output="$1"
	local exit_code="${2:-0}"
	local message="${3:-Comando debería fallar}"

	if [[ $exit_code -eq 0 ]]; then
		echo "❌ FAIL: $message"
		echo "   Exit code: $exit_code"
		echo "   Output: $command_output"
		return 1
	fi
	return 0
}
