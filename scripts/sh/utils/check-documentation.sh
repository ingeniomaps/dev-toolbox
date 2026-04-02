#!/usr/bin/env bash
# ============================================================================
# Script: check-documentation.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Verifica que todos los scripts tengan headers completos y documentación
# adecuada de funciones complejas.
#
# Uso:
#   ./scripts/sh/utils/check-documentation.sh
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

log_title "VERIFICACIÓN DE DOCUMENTACIÓN"

# Elementos requeridos en headers
REQUIRED_HEADER_ELEMENTS=(
	"Script:"
	"Ubicación:"
	"Uso:"
	"Retorno:"
)

# Contadores
TOTAL_SCRIPTS=0
SCRIPTS_WITH_HEADERS=0
SCRIPTS_MISSING_ELEMENTS=0

log_step "1. Verificando headers completos..."

while IFS= read -r file; do
	TOTAL_SCRIPTS=$((TOTAL_SCRIPTS + 1))

	# Leer primeras 30 líneas para verificar header
	header=$(head -n 30 "$file" 2>/dev/null || echo "")

	# Verificar que tiene shebang
	if ! echo "$header" | grep -q "^#!/usr/bin/env bash"; then
		log_warn "  $file: falta shebang"
		SCRIPTS_MISSING_ELEMENTS=$((SCRIPTS_MISSING_ELEMENTS + 1))
		EXIT_CODE=1
		continue
	fi

	# Verificar elementos requeridos
	missing_elements=()
	for element in "${REQUIRED_HEADER_ELEMENTS[@]}"; do
		if ! echo "$header" | grep -q "$element"; then
			missing_elements+=("$element")
		fi
	done

	if [[ ${#missing_elements[@]} -gt 0 ]]; then
		log_warn "  $file: faltan elementos en header: ${missing_elements[*]}"
		SCRIPTS_MISSING_ELEMENTS=$((SCRIPTS_MISSING_ELEMENTS + 1))
		EXIT_CODE=1
	else
		SCRIPTS_WITH_HEADERS=$((SCRIPTS_WITH_HEADERS + 1))
	fi
done < <(find "$PROJECT_ROOT/scripts/sh" -name "*.sh" -type f \
	! -path "*/tests/*" ! -path "*/.bats/*")

echo ""

if [[ $SCRIPTS_MISSING_ELEMENTS -eq 0 ]]; then
	log_success "  Todos los scripts ($SCRIPTS_WITH_HEADERS/$TOTAL_SCRIPTS) tienen headers completos"
else
	log_error "  $SCRIPTS_MISSING_ELEMENTS scripts con headers incompletos de $TOTAL_SCRIPTS"
fi

echo ""

# Verificar documentación de funciones complejas
log_step "2. Verificando documentación de funciones complejas..."

FUNCTIONS_WITHOUT_DOC=0

while IFS= read -r file; do
	# Buscar funciones que no tienen comentarios antes
	# Una función compleja es aquella con más de 10 líneas o con lógica condicional compleja
	while IFS= read -r line_num; do
		# Obtener líneas antes de la función
		context=$(sed -n "$((line_num - 3)),$((line_num - 1))p" "$file" 2>/dev/null || echo "")

		# Verificar si tiene documentación antes
		if ! echo "$context" | grep -qE "^#|^[[:space:]]*#"; then
			func_name=$(sed -n "${line_num}p" "$file" | grep -oE '[a-zA-Z_][a-zA-Z0-9_]*' | head -1)
			if [[ -n "$func_name" ]]; then
				# Verificar si la función es compleja (más de 10 líneas)
				func_end=$(awk -v start="$line_num" '
					NR >= start && /^[[:space:]]*}/ {print NR; exit}
					NR >= start && /^[^[:space:]#]/ && !/^[[:space:]]*function/ && !/^[[:space:]]*[a-zA-Z_]/ {next}
				' "$file" | head -1)

				if [[ -n "$func_end" ]]; then
					func_lines=$((func_end - line_num))
					if [[ $func_lines -gt 10 ]]; then
						log_warn "  $file:$line_num: función '$func_name' sin documentación ($func_lines líneas)"
						FUNCTIONS_WITHOUT_DOC=$((FUNCTIONS_WITHOUT_DOC + 1))
						EXIT_CODE=1
					fi
				fi
			fi
		fi
	done < <(grep -n "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*()" "$file" 2>/dev/null | cut -d: -f1 || true)
done < <(find "$PROJECT_ROOT/scripts/sh/common" -name "*.sh" -type f)

if [[ $FUNCTIONS_WITHOUT_DOC -eq 0 ]]; then
	log_success "  Todas las funciones complejas tienen documentación"
else
	log_warn "  $FUNCTIONS_WITHOUT_DOC funciones complejas sin documentación"
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
