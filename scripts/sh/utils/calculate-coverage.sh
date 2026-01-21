#!/usr/bin/env bash
# ============================================================================
# Script: calculate-coverage.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Calcula la cobertura de tests del proyecto.
# Analiza qué scripts tienen tests y genera métricas de cobertura.
#
# Uso:
#   ./scripts/sh/utils/calculate-coverage.sh [--format=text|json|html] [--output=FILE]
#
# Opciones:
#   --format=text  - Salida en texto (default)
#   --format=json  - Salida en JSON
#   --format=html  - Salida en HTML
#   --output=FILE  - Archivo de salida (default: stdout)
#   --min=PERCENT  - Falla si cobertura < PERCENT (default: 80)
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   COVERAGE_MIN - Cobertura mínima requerida (default: 80)
#
# Retorno:
#   0 si cobertura >= mínimo
#   1 si cobertura < mínimo
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_script_dir"
unset _script_dir
readonly PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../../.." 2>/dev/null && pwd || pwd)}"

# Cargar módulos de cobertura
source "$SCRIPT_DIR/coverage-finder.sh"
source "$SCRIPT_DIR/coverage-stats.sh"
source "$SCRIPT_DIR/coverage-output.sh"

# Parsear argumentos
OUTPUT_FORMAT="text"
OUTPUT_FILE=""
MIN_COVERAGE="${COVERAGE_MIN:-80}"

for arg in "$@"; do
	case "$arg" in
		--format=*)
			OUTPUT_FORMAT="${arg#*=}"
			;;
		--output=*)
			OUTPUT_FILE="${arg#*=}"
			;;
		--min=*)
			MIN_COVERAGE="${arg#*=}"
			;;
		*)
			;;
	esac
done

# Directorios
readonly COMMANDS_DIR="$PROJECT_ROOT/scripts/sh/commands"
readonly UTILS_DIR="$PROJECT_ROOT/scripts/sh/utils"
readonly SETUP_DIR="$PROJECT_ROOT/scripts/sh/setup"
readonly BACKUP_DIR="$PROJECT_ROOT/scripts/sh/backup"
readonly COMMON_DIR="$PROJECT_ROOT/scripts/sh/common"
readonly TESTS_UNIT_DIR="$PROJECT_ROOT/tests/unit"
readonly TESTS_INTEGRATION_DIR="$PROJECT_ROOT/tests/integration"

# Arrays para almacenar resultados
declare -a ALL_SCRIPTS=()
declare -a TESTED_SCRIPTS=()
declare -a UNTESTED_SCRIPTS=()
# shellcheck disable=SC2034
# SCRIPT_TO_TEST se usa indirectamente a través de funciones que reciben el nombre de la variable
declare -A SCRIPT_TO_TEST=()

# Ejecutar análisis
analyze_coverage \
	"$COMMANDS_DIR" \
	"$UTILS_DIR" \
	"$SETUP_DIR" \
	"$BACKUP_DIR" \
	"$COMMON_DIR" \
	"$TESTS_UNIT_DIR" \
	"$TESTS_INTEGRATION_DIR" \
	"ALL_SCRIPTS" \
	"TESTED_SCRIPTS" \
	"UNTESTED_SCRIPTS" \
	"SCRIPT_TO_TEST"

# Calcular estadísticas
total=${#ALL_SCRIPTS[@]}
tested=${#TESTED_SCRIPTS[@]}
untested=${#UNTESTED_SCRIPTS[@]}
_coverage=$(calculate_stats "$total" "$tested")
coverage="$_coverage"
unset _coverage

# Generar salida según formato
case "$OUTPUT_FORMAT" in
	json)
		output_json \
			"$total" \
			"$tested" \
			"$untested" \
			"$coverage" \
			"$MIN_COVERAGE" \
			"$PROJECT_ROOT" \
			"UNTESTED_SCRIPTS" \
			"TESTED_SCRIPTS" \
			"SCRIPT_TO_TEST" \
			"$OUTPUT_FILE"
		;;
	html)
		output_html \
			"$total" \
			"$tested" \
			"$untested" \
			"$coverage" \
			"$MIN_COVERAGE" \
			"$PROJECT_ROOT" \
			"UNTESTED_SCRIPTS" \
			"TESTED_SCRIPTS" \
			"SCRIPT_TO_TEST" \
			"$OUTPUT_FILE"
		;;
	text|*)
		output_text \
			"$total" \
			"$tested" \
			"$untested" \
			"$coverage" \
			"$MIN_COVERAGE" \
			"$PROJECT_ROOT" \
			"UNTESTED_SCRIPTS" \
			"TESTED_SCRIPTS" \
			"SCRIPT_TO_TEST" \
			"$OUTPUT_FILE"
		;;
esac

# Retornar código de salida según cobertura
if [[ $coverage -ge $MIN_COVERAGE ]]; then
	exit 0
else
	exit 1
fi
