#!/usr/bin/env bash
# ============================================================================
# Test: test-init.sh
# Ubicación: scripts/sh/tests/
# ============================================================================
# Tests para el helper init.sh
#
# Uso:
#   bash scripts/sh/tests/test-init.sh
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

# Test 1: Verificar que init.sh existe
test_init_file_exists() {
	[[ -f "$COMMON_DIR/init.sh" ]]
}

# Test 2: Verificar que se puede cargar init.sh
test_init_can_load() {
	local temp_script
	temp_script=$(mktemp)

	cat > "$temp_script" <<'EOF'
source "$1/init.sh"
init_script
[[ -n "${PROJECT_ROOT:-}" ]] && [[ -n "${SCRIPT_DIR:-}" ]]
EOF

	if bash "$temp_script" "$COMMON_DIR" >/dev/null 2>&1; then
		rm -f "$temp_script"
		return 0
	else
		rm -f "$temp_script"
		return 1
	fi
}

# Test 3: Verificar que PROJECT_ROOT se establece correctamente
test_project_root_set() {
	local temp_script
	temp_script=$(mktemp)
	local test_dir="/tmp/test-project"

	mkdir -p "$test_dir"

	cat > "$temp_script" <<'EOF'
cd "$1"
source "$2/init.sh"
init_script
[[ "$PROJECT_ROOT" == "$1" ]]
EOF

	if bash "$temp_script" "$test_dir" "$COMMON_DIR" >/dev/null 2>&1; then
		rm -f "$temp_script"
		rm -rf "$test_dir"
		return 0
	else
		rm -f "$temp_script"
		rm -rf "$test_dir"
		return 1
	fi
}

# Test 4: Verificar que las funciones de logging están disponibles
test_logging_functions() {
	local temp_script
	temp_script=$(mktemp)

	cat > "$temp_script" <<'EOF'
source "$1/init.sh"
init_script
command -v log_info >/dev/null && \
command -v log_error >/dev/null && \
command -v log_warn >/dev/null && \
command -v log_success >/dev/null
EOF

	if bash "$temp_script" "$COMMON_DIR" >/dev/null 2>&1; then
		rm -f "$temp_script"
		return 0
	else
		rm -f "$temp_script"
		return 1
	fi
}

# Test 5: Verificar que get_project_root funciona
test_get_project_root() {
	local temp_script
	temp_script=$(mktemp)
	local test_dir="/tmp/test-project-2"

	mkdir -p "$test_dir"

	cat > "$temp_script" <<'EOF'
cd "$1"
source "$2/init.sh"
init_script
ROOT=$(get_project_root)
[[ "$ROOT" == "$1" ]]
EOF

	if bash "$temp_script" "$test_dir" "$COMMON_DIR" >/dev/null 2>&1; then
		rm -f "$temp_script"
		rm -rf "$test_dir"
		return 0
	else
		rm -f "$temp_script"
		rm -rf "$test_dir"
		return 1
	fi
}

# Ejecutar todos los tests
echo "=========================================="
echo "Tests para init.sh"
echo "=========================================="
echo ""

run_test "init.sh existe" test_init_file_exists
run_test "init.sh se puede cargar" test_init_can_load
run_test "PROJECT_ROOT se establece correctamente" test_project_root_set
run_test "Funciones de logging disponibles" test_logging_functions
run_test "get_project_root funciona" test_get_project_root

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
