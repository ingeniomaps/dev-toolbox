#!/usr/bin/env bash
# ============================================================================
# Funciones: coverage-finder.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Funciones para encontrar scripts y sus tests correspondientes.
# ============================================================================

# Directorios (deben ser definidos antes de usar estas funciones)
# readonly COMMANDS_DIR="$PROJECT_ROOT/scripts/sh/commands"
# readonly UTILS_DIR="$PROJECT_ROOT/scripts/sh/utils"
# readonly SETUP_DIR="$PROJECT_ROOT/scripts/sh/setup"
# readonly BACKUP_DIR="$PROJECT_ROOT/scripts/sh/backup"
# readonly COMMON_DIR="$PROJECT_ROOT/scripts/sh/common"
# readonly TESTS_UNIT_DIR="$PROJECT_ROOT/tests/unit"
# readonly TESTS_INTEGRATION_DIR="$PROJECT_ROOT/tests/integration"

# Función: Encontrar todos los scripts
find_all_scripts() {
	local commands_dir="$1"
	local utils_dir="$2"
	local setup_dir="$3"
	local backup_dir="$4"
	local common_dir="$5"
	local all_scripts_var="$6"

	# Inicializar array
	eval "declare -a $all_scripts_var=()"

	# Scripts de comandos
	while IFS= read -r script; do
		eval "$all_scripts_var+=(\"$script\")"
	done < <(find "$commands_dir" -name "*.sh" -type f 2>/dev/null | sort)

	# Scripts de utils
	while IFS= read -r script; do
		eval "$all_scripts_var+=(\"$script\")"
	done < <(find "$utils_dir" -name "*.sh" -type f 2>/dev/null | sort)

	# Scripts de setup
	while IFS= read -r script; do
		eval "$all_scripts_var+=(\"$script\")"
	done < <(find "$setup_dir" -name "*.sh" -type f 2>/dev/null | sort)

	# Scripts de backup
	while IFS= read -r script; do
		eval "$all_scripts_var+=(\"$script\")"
	done < <(find "$backup_dir" -name "*.sh" -type f 2>/dev/null | sort)

	# Scripts comunes (solo los principales)
	local common_scripts=("init.sh" "logging.sh" "validation.sh" "services.sh" "error-handling.sh")
	for script in "${common_scripts[@]}"; do
		if [[ -f "$common_dir/$script" ]]; then
			eval "$all_scripts_var+=(\"$common_dir/$script\")"
		fi
	done
}

# Función: Encontrar test correspondiente
find_test_for_script() {
	local script_path="$1"
	local tests_unit_dir="$2"
	local tests_integration_dir="$3"

	_script_name=$(basename "$script_path" .sh)
	local script_name="$_script_name"
	unset _script_name

	# Buscar en tests unitarios
	local test_file="$tests_unit_dir/test-${script_name}.bats"
	if [[ -f "$test_file" ]]; then
		echo "$test_file"
		return 0
	fi

	# Buscar variaciones comunes
	local variations=(
		"test-${script_name}.bats"
		"test-${script_name//-/_}.bats"
		"test-$(echo "$script_name" | tr '-' '_').bats"
	)

	for var in "${variations[@]}"; do
		if [[ -f "$tests_unit_dir/$var" ]]; then
			echo "$tests_unit_dir/$var"
			return 0
		fi
	done

	# Buscar en tests de integración
	for var in "${variations[@]}"; do
		if [[ -f "$tests_integration_dir/$var" ]]; then
			echo "$tests_integration_dir/$var"
			return 0
		fi
	done

	# Buscar por nombre parcial (ej: check-version-compatibility.sh -> test-check-version-compatibility.bats)
	_base_name=$(basename "$script_path")
	local base_name="$_base_name"
	unset _base_name
	for test_file in "$tests_unit_dir"/test-*.bats "$tests_integration_dir"/test-*.bats; do
		if [[ -f "$test_file" ]]; then
			_test_base=$(basename "$test_file" .bats | sed 's/^test-//')
			local test_base="$_test_base"
			unset _test_base
			if [[ "$base_name" == *"$test_base"* ]] || [[ "$test_base" == *"$script_name"* ]]; then
				echo "$test_file"
				return 0
			fi
		fi
	done

	return 1
}
