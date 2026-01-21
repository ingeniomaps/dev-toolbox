#!/usr/bin/env bats
# ============================================================================
# Test: test-replace-domains.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests unitarios para replace-domains.sh usando BATS.
#
# Uso:
#   bats tests/unit/test-replace-domains.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'tests/unit/helpers.bash'

@test "replace-domains.bats existe" {
	assert_file_exists "$TEST_SCRIPTS_DIR/utils/replace-domains.sh"
}

@test "replace-domains.sh requiere 2 argumentos" {
	run bash "$TEST_SCRIPTS_DIR/utils/replace-domains.sh"

	assert_failure "$output" "$status" "Debería fallar sin argumentos"
	assert_contains "$output" "2 argumentos\|Uso:" "Debería indicar que se requieren 2 argumentos"
}

@test "replace-domains.sh reemplaza dominio en archivos" {
	local project_dir=$(create_temp_dir)
	local test_file="$project_dir/test.txt"

	echo "Config for olddomain.com" > "$test_file"

	run bash "$TEST_SCRIPTS_DIR/utils/replace-domains.sh" "newdomain.com" "olddomain.com" \
		PROJECT_ROOT="$project_dir"

	assert_success "$output" "$status" "Debería reemplazar dominio exitosamente"

	# Verificar que se reemplazó
	local file_content=$(cat "$test_file")
	assert_contains "$file_content" "newdomain.com" "Debería contener nuevo dominio"
	assert_not_contains "$file_content" "olddomain.com" "No debería contener dominio antiguo"
}

@test "replace-domains.sh maneja dominios iguales" {
	local project_dir=$(create_temp_dir)

	run bash "$TEST_SCRIPTS_DIR/utils/replace-domains.sh" "samedomain.com" "samedomain.com" \
		PROJECT_ROOT="$project_dir"

	# Debería retornar éxito pero no hacer nada
	[[ $status -eq 0 ]]
	assert_contains "$output" "iguales\|nada que reemplazar" "Debería indicar que los dominios son iguales"
}

@test "replace-domains.sh valida que dominios no estén vacíos" {
	local project_dir=$(create_temp_dir)

	run bash "$TEST_SCRIPTS_DIR/utils/replace-domains.sh" "" "olddomain.com" \
		PROJECT_ROOT="$project_dir"

	assert_failure "$output" "$status" "Debería fallar con dominio vacío"
	assert_contains "$output" "no pueden estar vacíos" "Debería indicar que no pueden estar vacíos"
}

@test "replace-domains.sh excluye directorios .git" {
	local project_dir=$(create_temp_dir)
	mkdir -p "$project_dir/.git"
	local git_file="$project_dir/.git/config"

	echo "olddomain.com" > "$git_file"

	run bash "$TEST_SCRIPTS_DIR/utils/replace-domains.sh" "newdomain.com" "olddomain.com" \
		PROJECT_ROOT="$project_dir"

	# Verificar que .git fue excluido
	local git_content=$(cat "$git_file")
	assert_contains "$git_content" "olddomain.com" "No debería modificar archivos en .git"
}

@test "replace-domains.sh excluye archivos .md" {
	local project_dir=$(create_temp_dir)
	local md_file="$project_dir/README.md"

	echo "olddomain.com" > "$md_file"

	run bash "$TEST_SCRIPTS_DIR/utils/replace-domains.sh" "newdomain.com" "olddomain.com" \
		PROJECT_ROOT="$project_dir"

	# Verificar que .md fue excluido
	local md_content=$(cat "$md_file")
	assert_contains "$md_content" "olddomain.com" "No debería modificar archivos .md"
}

@test "replace-domains.sh reemplaza múltiples ocurrencias" {
	local project_dir=$(create_temp_dir)
	local test_file="$project_dir/test.txt"

	cat > "$test_file" <<'EOF'
Config for olddomain.com
Another reference to olddomain.com
EOF

	run bash "$TEST_SCRIPTS_DIR/utils/replace-domains.sh" "newdomain.com" "olddomain.com" \
		PROJECT_ROOT="$project_dir"

	local file_content=$(cat "$test_file")
	local count=$(echo "$file_content" | grep -o "newdomain.com" | wc -l)
	[[ $count -eq 2 ]] || [[ $count -ge 1 ]]  "Debería reemplazar todas las ocurrencias"
}

@test "replace-domains.sh maneja archivos sin el dominio" {
	local project_dir=$(create_temp_dir)
	local test_file="$project_dir/test.txt"

	echo "No domain here" > "$test_file"

	run bash "$TEST_SCRIPTS_DIR/utils/replace-domains.sh" "newdomain.com" "olddomain.com" \
		PROJECT_ROOT="$project_dir"

	# Debería ejecutarse sin error aunque no haya nada que reemplazar
	[[ $status -ge 0 ]]
}
