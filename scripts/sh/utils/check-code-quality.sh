#!/usr/bin/env bash
# ============================================================================
# Script: check-code-quality.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Verifica calidad del código: líneas largas, uso de helpers, código duplicado.
#
# Uso:
#   ./scripts/sh/utils/check-code-quality.sh
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
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

EXIT_CODE=0

log_info "Verificando calidad del código..."
echo ""

# 1. Verificar líneas > 120 caracteres
log_info "1. Verificando líneas > 120 caracteres..."
LONG_LINES=0

while IFS= read -r file; do
	LINES=$(awk 'length > 120 {print FILENAME":"NR}' "$file" 2>/dev/null | wc -l)
	if [[ $LINES -gt 0 ]]; then
		log_warn "  $file: $LINES líneas > 120 caracteres"
		LONG_LINES=$((LONG_LINES + LINES))
		EXIT_CODE=1
	fi
done < <(find "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/makefiles" \
	\( -name "*.sh" -o -name "*.mk" \) -type f)

if [[ $LONG_LINES -eq 0 ]]; then
	log_success "  Todas las líneas tienen ≤ 120 caracteres"
else
	log_error "  Total: $LONG_LINES líneas > 120 caracteres"
fi
echo ""

# 2. Verificar uso de helpers comunes
log_info "2. Verificando uso de helpers comunes..."
SCRIPTS_WITHOUT_INIT=0

while IFS= read -r file; do
	# Saltar scripts en common/ y init.sh mismo
	[[ "$file" == *"/common/"* ]] && continue
	[[ "$file" == *"/init.sh" ]] && continue

	# Verificar si usa init.sh
	if ! grep -q "init.sh\|init_script" "$file" 2>/dev/null; then
		# Verificar si tiene inicialización manual (debe migrar a init.sh)
		if grep -q "SCRIPT_DIR.*dirname.*BASH_SOURCE" "$file" 2>/dev/null; then
			SCRIPTS_WITHOUT_INIT=$((SCRIPTS_WITHOUT_INIT + 1))
			log_warn "  $file: no usa init.sh (debería migrar)"
		fi
	fi
done < <(find "$PROJECT_ROOT/scripts" -name "*.sh" -type f)

if [[ $SCRIPTS_WITHOUT_INIT -eq 0 ]]; then
	log_success "  Todos los scripts usan helpers comunes correctamente"
else
	log_warn "  $SCRIPTS_WITHOUT_INIT scripts deberían usar init.sh"
fi
echo ""

# 3. Verificar código duplicado (detección de servicios)
log_info "3. Verificando código duplicado..."
DUPLICATE_PATTERNS=0

# Buscar patrones de detección de servicios duplicados
PATTERN="grep -E.*VERSION.*env"
COUNT=$(grep -r "$PATTERN" "$PROJECT_ROOT/scripts" 2>/dev/null | \
	grep -v "services.sh\|init.sh" | wc -l || echo "0")

if [[ $COUNT -gt 5 ]]; then
	log_warn "  Encontrados $COUNT patrones de detección de servicios"
	log_info "  Considera usar detect_services_from_env() de services.sh"
	DUPLICATE_PATTERNS=$((DUPLICATE_PATTERNS + COUNT))
fi

if [[ $DUPLICATE_PATTERNS -eq 0 ]]; then
	log_success "  No se encontraron patrones duplicados significativos"
fi
echo ""

# Resumen
if [[ $EXIT_CODE -eq 0 ]]; then
	log_success "Verificación completada - Todo correcto"
	exit 0
else
	log_error "Verificación completada - Se encontraron problemas"
	exit 1
fi
