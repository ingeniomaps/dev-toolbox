#!/usr/bin/env bash
# ============================================================================
# Test: test-services.sh
# Ubicación: scripts/sh/tests/
# ============================================================================
# Tests para el helper services.sh
#
# Uso:
#   bash scripts/sh/tests/test-services.sh
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

_test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR="$_test_dir"
unset _test_dir
readonly COMMON_DIR="$TEST_DIR/../common"
# PROJECT_ROOT no se usa en este archivo de test
# _project_root="$(cd "$TEST_DIR/../../.." && pwd)"
# readonly PROJECT_ROOT="$_project_root"
# unset _project_root

# Colores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Función para ejecutar un test
run_test() {
	local test_name="$1"
	local test_func="$2"

	printf "${YELLOW}Testing:${NC} $test_name... "

	if $test_func; then
		printf "${GREEN}✓ PASSED${NC}\n"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		return 0
	else
		printf "${RED}✗ FAILED${NC}\n"
		TESTS_FAILED=$((TESTS_FAILED + 1))
		return 1
	fi
}

# Test 1: Verificar que services.sh existe
test_services_file_exists() {
	[[ -f "$COMMON_DIR/services.sh" ]]
}

# Test 2: Verificar que se puede cargar services.sh
test_services_can_load() {
	local temp_script
	temp_script=$(mktemp)

	cat > "$temp_script" <<'EOF'
source "$1/init.sh"
init_script
source "$1/services.sh"
command -v detect_services_from_env >/dev/null && \
command -v get_container_name >/dev/null && \
command -v is_container_running >/dev/null && \
command -v get_service_version >/dev/null
EOF

	if bash "$temp_script" "$COMMON_DIR" >/dev/null 2>&1; then
		rm -f "$temp_script"
		return 0
	else
		rm -f "$temp_script"
		return 1
	fi
}

# Test 3: Verificar detect_services_from_env con archivo .env válido
test_detect_services_from_env() {
	local temp_env
	temp_env=$(mktemp)
	local temp_script
	temp_script=$(mktemp)

	cat > "$temp_env" <<'EOF'
POSTGRES_VERSION=15.0
MONGO_VERSION=7.0
REDIS_VERSION=7.0
EOF

	cat > "$temp_script" <<'EOF'
source "$1/init.sh"
init_script
source "$1/services.sh"
SERVICES=$(detect_services_from_env "$2")
echo "$SERVICES" | grep -q "postgres" && \
echo "$SERVICES" | grep -q "mongo" && \
echo "$SERVICES" | grep -q "redis"
EOF

	if bash "$temp_script" "$COMMON_DIR" "$temp_env" >/dev/null 2>&1; then
		rm -f "$temp_script" "$temp_env"
		return 0
	else
		rm -f "$temp_script" "$temp_env"
		return 1
	fi
}

# Test 4: Verificar get_container_name sin prefijo
test_get_container_name_no_prefix() {
	local temp_script
	temp_script=$(mktemp)

	cat > "$temp_script" <<'EOF'
source "$1/init.sh"
init_script
source "$1/services.sh"
NAME=$(get_container_name "postgres")
[[ "$NAME" == "postgres" ]]
EOF

	if bash "$temp_script" "$COMMON_DIR" >/dev/null 2>&1; then
		rm -f "$temp_script"
		return 0
	else
		rm -f "$temp_script"
		return 1
	fi
}

# Test 5: Verificar get_container_name con prefijo
test_get_container_name_with_prefix() {
	local temp_script
	temp_script=$(mktemp)

	cat > "$temp_script" <<'EOF'
source "$1/init.sh"
init_script
source "$1/services.sh"
export SERVICE_PREFIX="myapp"
NAME=$(get_container_name "postgres")
[[ "$NAME" == "myapp-postgres" ]]
EOF

	if bash "$temp_script" "$COMMON_DIR" >/dev/null 2>&1; then
		rm -f "$temp_script"
		return 0
	else
		rm -f "$temp_script"
		return 1
	fi
}

# Test 6: Verificar get_service_version
test_get_service_version() {
	local temp_env
	temp_env=$(mktemp)
	local temp_script
	temp_script=$(mktemp)

	cat > "$temp_env" <<'EOF'
POSTGRES_VERSION=15.0
EOF

	cat > "$temp_script" <<'EOF'
source "$1/init.sh"
init_script
source "$1/services.sh"
VERSION=$(get_service_version "postgres" "$2")
[[ "$VERSION" == "15.0" ]]
EOF

	if bash "$temp_script" "$COMMON_DIR" "$temp_env" >/dev/null 2>&1; then
		rm -f "$temp_script" "$temp_env"
		return 0
	else
		rm -f "$temp_script" "$temp_env"
		return 1
	fi
}

# Test 7: Verificar detect_services_from_env con archivo inexistente
test_detect_services_no_file() {
	local temp_script
	temp_script=$(mktemp)

	cat > "$temp_script" <<'EOF'
source "$1/init.sh"
init_script
source "$1/services.sh"
SERVICES=$(detect_services_from_env "/tmp/nonexistent.env")
[[ -z "$SERVICES" ]]
EOF

	if bash "$temp_script" "$COMMON_DIR" >/dev/null 2>&1; then
		rm -f "$temp_script"
		return 0
	else
		rm -f "$temp_script"
		return 1
	fi
}

# Ejecutar todos los tests
echo "=========================================="
echo "Tests para services.sh"
echo "=========================================="
echo ""

run_test "services.sh existe" test_services_file_exists
run_test "services.sh se puede cargar" test_services_can_load
run_test "detect_services_from_env funciona" test_detect_services_from_env
run_test "get_container_name sin prefijo" test_get_container_name_no_prefix
run_test "get_container_name con prefijo" test_get_container_name_with_prefix
run_test "get_service_version funciona" test_get_service_version
run_test "detect_services_from_env con archivo inexistente" test_detect_services_no_file

echo ""
echo "=========================================="
echo "Resumen:"
echo "  Tests pasados: $TESTS_PASSED"
echo "  Tests fallidos: $TESTS_FAILED"
echo "=========================================="

if [[ $TESTS_FAILED -eq 0 ]]; then
	exit 0
else
	exit 1
fi
