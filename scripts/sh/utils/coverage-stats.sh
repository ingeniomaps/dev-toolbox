#!/usr/bin/env bash
# ============================================================================
# Script: coverage-stats.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Funciones para calcular estadísticas de cobertura.
#
# Uso:
#   source scripts/sh/utils/coverage-stats.sh
#
# Retorno:
#   N/A (librería para source)
# ============================================================================

# Función: Contar tests en archivo BATS
count_tests_in_file() {
	local test_file="$1"
	if [[ ! -f "$test_file" ]]; then
		echo "0"
		return
	fi

	# Contar @test
	local count
	count=$(grep -c "^@test" "$test_file" 2>/dev/null || echo "0")
	echo "${count:-0}"
}

# Función: Calcular estadísticas
calculate_stats() {
	local total="$1"
	local tested="$2"

	if [[ $total -eq 0 ]]; then
		echo "0"
		return
	fi

	local coverage=$((tested * 100 / total))
	echo "$coverage"
}

# Función: Analizar cobertura
analyze_coverage() {
	local commands_dir="$1"
	local utils_dir="$2"
	local setup_dir="$3"
	local backup_dir="$4"
	local common_dir="$5"
	local tests_unit_dir="$6"
	local tests_integration_dir="$7"
	local all_scripts_var="$8"
	local tested_scripts_var="$9"
	local untested_scripts_var="${10}"
	local script_to_test_var="${11}"

	# Encontrar todos los scripts
	find_all_scripts "$commands_dir" "$utils_dir" "$setup_dir" "$backup_dir" "$common_dir" "$all_scripts_var"

	# Inicializar arrays de salida
	eval "declare -a $tested_scripts_var=()"
	eval "declare -a $untested_scripts_var=()"
	eval "declare -A $script_to_test_var=()"

	# Obtener referencias a los arrays
	# shellcheck disable=SC2154
	# Las referencias dinámicas (local -n) se crean aquí y se usan en el loop
	local -n all_scripts_ref=$all_scripts_var
	local -n tested_scripts_ref=$tested_scripts_var
	local -n untested_scripts_ref=$untested_scripts_var
	# shellcheck disable=SC2034,SC2154
	# script_to_test_ref se usa indirectamente a través de asignaciones en el loop
	local -n script_to_test_ref=$script_to_test_var

	# Analizar cada script
	for script in "${all_scripts_ref[@]}"; do
		local test_file
		if test_file=$(find_test_for_script "$script" "$tests_unit_dir" "$tests_integration_dir"); then
			tested_scripts_ref+=("$script")
			# shellcheck disable=SC2034
			# script_to_test_ref se usa para mapear scripts a sus archivos de test
			script_to_test_ref["$script"]="$test_file"
		else
			untested_scripts_ref+=("$script")
			# shellcheck disable=SC2034
			# script_to_test_ref se usa para marcar scripts sin tests
			script_to_test_ref["$script"]=""
		fi
	done
}
