#!/usr/bin/env bash
# ============================================================================
# Script: lint.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Ejecuta linters (shellcheck y shfmt) en todos los scripts del proyecto.
#
# Uso:
#   ./scripts/sh/utils/lint.sh [--fix] [--check-only]
#
# Opciones:
#   --fix        - Aplica correcciones automáticas (shfmt)
#   --check-only - Solo verifica sin aplicar correcciones
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   SHELLCHECK_OPTS - Opciones adicionales para shellcheck
#   SHFMT_OPTS - Opciones adicionales para shfmt
#
# Retorno:
#   0 si todo está correcto
#   1 si hay problemas
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
fi

# Parsear argumentos
FIX=false
CHECK_ONLY=false
for arg in "$@"; do
	case "$arg" in
		--fix)
			FIX=true
			;;
		--check-only)
			CHECK_ONLY=true
			;;
		*)
			log_warn "Argumento desconocido: $arg"
			;;
	esac
done

EXIT_CODE=0

log_title "LINTING DE SCRIPTS"

# Verificar que shellcheck está instalado
if ! command -v shellcheck >/dev/null 2>&1; then
	log_error "shellcheck no está instalado"
	log_info "Instala con:"
	log_info "  Ubuntu/Debian: sudo apt-get install shellcheck"
	log_info "  macOS: brew install shellcheck"
	log_info "  O desde: https://github.com/koalaman/shellcheck#installing"
	EXIT_CODE=1
fi

# Verificar que shfmt está instalado
if ! command -v shfmt >/dev/null 2>&1; then
	log_error "shfmt no está instalado"
	log_info "Instala con:"
	log_info "  go install mvdan.cc/sh/v3/cmd/shfmt@latest"
	log_info "  O desde: https://github.com/mvdan/sh#shfmt"
	EXIT_CODE=1
fi

if [[ $EXIT_CODE -ne 0 ]]; then
	exit 1
fi

echo ""

# 1. ShellCheck
log_step "1. Ejecutando ShellCheck..."

SHELLCHECK_OPTS="${SHELLCHECK_OPTS:-}"
SHELLCHECK_CONFIG="${PROJECT_ROOT}/.shellcheckrc"

SHELLCHECK_ERRORS=0
SHELLCHECK_FILES=0

while IFS= read -r file; do
	SHELLCHECK_FILES=$((SHELLCHECK_FILES + 1))

	# Ejecutar shellcheck
	if [[ -f "$SHELLCHECK_CONFIG" ]]; then
		if ! shellcheck -f gcc "$SHELLCHECK_OPTS" "$file" 2>&1; then
			SHELLCHECK_ERRORS=$((SHELLCHECK_ERRORS + 1))
			EXIT_CODE=1
		fi
	else
		if ! shellcheck -f gcc -s bash "$SHELLCHECK_OPTS" "$file" 2>&1; then
			SHELLCHECK_ERRORS=$((SHELLCHECK_ERRORS + 1))
			EXIT_CODE=1
		fi
	fi
done < <(find "$PROJECT_ROOT/scripts/sh" -name "*.sh" -type f \
	! -path "*/tests/*" ! -path "*/.bats/*")

if [[ $SHELLCHECK_ERRORS -eq 0 ]]; then
	log_success "  ShellCheck: $SHELLCHECK_FILES archivos verificados, sin errores"
else
	log_error "  ShellCheck: $SHELLCHECK_ERRORS archivos con errores de $SHELLCHECK_FILES"
fi

echo ""

# 2. shfmt
log_step "2. Ejecutando shfmt..."

SHFMT_OPTS="${SHFMT_OPTS:-}"
SHFMT_CONFIG="${PROJECT_ROOT}/.shfmt.yaml"

SHFMT_ERRORS=0
SHFMT_FILES=0

while IFS= read -r file; do
	SHFMT_FILES=$((SHFMT_FILES + 1))

	# Verificar formato
	if [[ -f "$SHFMT_CONFIG" ]]; then
		if ! shfmt -d -f "$file" >/dev/null 2>&1; then
			SHFMT_ERRORS=$((SHFMT_ERRORS + 1))
			EXIT_CODE=1

			if [[ "$FIX" == "true" ]] && [[ "$CHECK_ONLY" != "true" ]]; then
				log_info "  Corrigiendo formato: $file"
				shfmt -w "$file" 2>/dev/null || true
			fi
		fi
	else
		# Usar opciones por defecto
		if ! shfmt -d -i 2 -bn -ci -sr "$file" >/dev/null 2>&1; then
			SHFMT_ERRORS=$((SHFMT_ERRORS + 1))
			EXIT_CODE=1

			if [[ "$FIX" == "true" ]] && [[ "$CHECK_ONLY" != "true" ]]; then
				log_info "  Corrigiendo formato: $file"
				shfmt -w -i 2 -bn -ci -sr "$file" 2>/dev/null || true
			fi
		fi
	fi
done < <(find "$PROJECT_ROOT/scripts/sh" -name "*.sh" -type f \
	! -path "*/tests/*" ! -path "*/.bats/*")

if [[ $SHFMT_ERRORS -eq 0 ]]; then
	log_success "  shfmt: $SHFMT_FILES archivos verificados, formato correcto"
else
	if [[ "$FIX" == "true" ]] && [[ "$CHECK_ONLY" != "true" ]]; then
		log_success "  shfmt: $SHFMT_ERRORS archivos corregidos de $SHFMT_FILES"
	else
		log_error "  shfmt: $SHFMT_ERRORS archivos con formato incorrecto de $SHFMT_FILES"
		log_info "  Ejecuta con --fix para corregir automáticamente"
	fi
fi

echo ""

# Resumen
if [[ $EXIT_CODE -eq 0 ]]; then
	log_success "Linting completado - Todo correcto"
	exit 0
else
	log_error "Linting completado - Se encontraron problemas"
	exit 1
fi
