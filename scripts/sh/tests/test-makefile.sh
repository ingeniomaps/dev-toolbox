#!/usr/bin/env bash
# ============================================================================
# Script: test-makefile.sh
# Ubicación: scripts/sh/tests/
# ============================================================================
# Suite de tests para validar el Makefile y sus comandos.
#
# Uso:
#   ./scripts/sh/tests/test-makefile.sh
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#
# Retorno:
#   0 si todos los tests pasan
#   1 si algún test falla
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_script_dir"
unset _script_dir
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"
_pr="${PROJECT_ROOT:-$(pwd)}"
readonly PROJECT_ROOT="${_pr%/}"
unset _pr

if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/logging.sh"
else
	log_info() { echo "[INFO] $*"; }
	log_warn() { echo "[WARN] $*" >&2; }
	log_error() { echo "[ERROR] $*" >&2; }
	log_success() { echo "[SUCCESS] $*"; }
	[[ -f "$COMMON_SCRIPTS_DIR/colors.sh" ]] && source "$COMMON_SCRIPTS_DIR/colors.sh"
fi

# Contador de tests
TESTS_PASSED=0
TESTS_FAILED=0
EXIT_CODE=0

# Función helper para ejecutar tests
run_test() {
	local test_name="$1"
	shift
	log_info "Test: $test_name"
	if "$@"; then
		log_success "$test_name"
		((TESTS_PASSED++)) || true
		return 0
	else
		log_error "$test_name"
		((TESTS_FAILED++)) || true
		EXIT_CODE=1
		return 1
	fi
}

# Cambiar al directorio del proyecto
cd "$PROJECT_ROOT" || exit 1

log_title "Iniciando tests del Makefile..."
echo ""

# Test 1: Validar que el Makefile existe
run_test "Makefile existe" test -f "$PROJECT_ROOT/Makefile"

# Test 2: Validar sintaxis básica del Makefile
run_test "Sintaxis del Makefile es válida" \
	make -n help-toolbox >/dev/null 2>&1

# Test 3: Validar que los comandos .PHONY están declarados
log_info "Test: Comandos .PHONY están declarados"
PHONY_TARGETS=$(grep -E '^\.PHONY:' "$PROJECT_ROOT/Makefile" \
	| sed 's/^\.PHONY: //' | tr ' ' '\n' | grep -v '^$' | sort -u)
if [[ -n "$PHONY_TARGETS" ]]; then
	log_success "Se encontraron declaraciones .PHONY"
	((TESTS_PASSED++)) || true
else
	log_error "No se encontraron declaraciones .PHONY"
	((TESTS_FAILED++)) || true
	EXIT_CODE=1
fi

# Test 4: Validar que help-toolbox funciona
run_test "Comando help-toolbox funciona" \
	make help-toolbox >/dev/null 2>&1

# Test 5: Validar que check-dependencies funciona
run_test "Comando check-dependencies funciona" \
	make check-dependencies >/dev/null 2>&1

# Test 6: Validar que los scripts requeridos existen
log_info "Test: Scripts requeridos existen"
REQUIRED_SCRIPTS=("scripts/sh/utils/wait-for-service.sh" "scripts/sh/utils/ensure-network.sh")
MISSING_SCRIPTS=0
for script in "${REQUIRED_SCRIPTS[@]}"; do
	if [[ -f "$PROJECT_ROOT/$script" ]]; then
		log_success "$script existe"
	else
		log_error "$script no existe"
		((MISSING_SCRIPTS++)) || true
	fi
done
if [[ $MISSING_SCRIPTS -eq 0 ]]; then
	((TESTS_PASSED++)) || true
else
	((TESTS_FAILED++)) || true
	EXIT_CODE=1
fi

# Resumen
echo ""
log_title "Resumen de tests:"
log_success "Tests pasados: $TESTS_PASSED"
if [[ $TESTS_FAILED -gt 0 ]]; then
	log_error "Tests fallidos: $TESTS_FAILED"
else
	log_success "Tests fallidos: $TESTS_FAILED"
fi

if [[ $EXIT_CODE -eq 0 ]]; then
	log_success "Todos los tests pasaron"
	exit 0
else
	log_error "Algunos tests fallaron"
	exit 1
fi
