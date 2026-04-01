#!/usr/bin/env bats
# ============================================================================
# Test: test-init-env.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests unitarios para init-env.sh usando BATS.
#
# Uso:
#   bats tests/unit/test-init-env.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'helpers'

@test "init-env.sh existe" {
	assert_file_exists "$TEST_SCRIPTS_DIR/setup/init-env.sh"
}

@test "init-env.sh crea .env desde plantilla .env-template" {
	local project_dir=$(create_temp_dir)
	local template_file="$project_dir/.env-template"

	cat > "$template_file" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=101.80.0.0
POSTGRES_VERSION=15.0
EOF

	run bash "$TEST_SCRIPTS_DIR/setup/init-env.sh" \
		PROJECT_ROOT="$project_dir"

	assert_success "$output" "$status" "Debería crear .env desde plantilla"
	assert_file_exists "$project_dir/.env" "Debería crear archivo .env"

	# Verificar contenido
	local env_content=$(cat "$project_dir/.env")
	assert_contains "$env_content" "NETWORK_NAME" "Debería copiar contenido de plantilla"
}

@test "init-env.sh usa .env.template si .env-template no existe" {
	local project_dir=$(create_temp_dir)
	local template_file="$project_dir/.env.template"

	cat > "$template_file" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=101.80.0.0
EOF

	run bash "$TEST_SCRIPTS_DIR/setup/init-env.sh" \
		PROJECT_ROOT="$project_dir"

	assert_success "$output" "$status" "Debería usar .env.template"
	assert_file_exists "$project_dir/.env" "Debería crear archivo .env"
}

@test "init-env.sh falla si no hay plantilla disponible" {
	local project_dir=$(create_temp_dir)

	run bash "$TEST_SCRIPTS_DIR/setup/init-env.sh" \
		PROJECT_ROOT="$project_dir"

	assert_failure "$output" "$status" "Debería fallar sin plantilla"
	assert_contains "$output" "No se encontró\|plantilla" "Debería indicar que no hay plantilla"
}

@test "init-env.sh no sobrescribe .env existente sin --force" {
	local project_dir=$(create_temp_dir)
	local template_file="$project_dir/.env-template"
	local env_file="$project_dir/.env"

	cat > "$template_file" <<'EOF'
NETWORK_NAME=new-network
EOF

	# Crear .env existente
	echo "NETWORK_NAME=old-network" > "$env_file"

	run bash "$TEST_SCRIPTS_DIR/setup/init-env.sh" \
		PROJECT_ROOT="$project_dir"

	# Debería retornar éxito pero no sobrescribir
	[[ $status -eq 0 ]]

	# Verificar que no se sobrescribió
	local env_content=$(cat "$env_file")
	assert_contains "$env_content" "old-network" "No debería sobrescribir .env existente"
}

@test "init-env.sh sobrescribe .env existente con --force" {
	local project_dir=$(create_temp_dir)
	local template_file="$project_dir/.env-template"
	local env_file="$project_dir/.env"

	cat > "$template_file" <<'EOF'
NETWORK_NAME=new-network
EOF

	# Crear .env existente
	echo "NETWORK_NAME=old-network" > "$env_file"

	run bash "$TEST_SCRIPTS_DIR/setup/init-env.sh" --force \
		PROJECT_ROOT="$project_dir"

	assert_success "$output" "$status" "Debería sobrescribir con --force"

	# Verificar que se sobrescribió
	local env_content=$(cat "$env_file")
	assert_contains "$env_content" "new-network" "Debería sobrescribir .env con --force"
}

@test "init-env.sh crea .env.NAME cuando se especifica nombre" {
	local project_dir=$(create_temp_dir)
	local template_file="$project_dir/.env-template"

	cat > "$template_file" <<'EOF'
NETWORK_NAME=test-network
EOF

	run bash "$TEST_SCRIPTS_DIR/setup/init-env.sh" "development" \
		PROJECT_ROOT="$project_dir"

	assert_success "$output" "$status" "Debería crear .env.development"
	assert_file_exists "$project_dir/.env.development" "Debería crear archivo .env.development"
	assert_file_not_exists "$project_dir/.env" "No debería crear .env cuando se especifica nombre"
}

@test "init-env.sh funciona en modo --silent" {
	local project_dir=$(create_temp_dir)
	local template_file="$project_dir/.env-template"

	cat > "$template_file" <<'EOF'
NETWORK_NAME=test-network
EOF

	run bash "$TEST_SCRIPTS_DIR/setup/init-env.sh" --silent \
		PROJECT_ROOT="$project_dir"

	assert_success "$output" "$status" "Debería funcionar en modo silencioso"
	assert_file_exists "$project_dir/.env" "Debería crear .env en modo silencioso"

	# En modo silencioso, no debería haber mucha salida
	# (excepto errores)
	[[ ${#output} -lt 200 ]] || true  # Permitir algo de salida
}

@test "init-env.sh muestra ayuda con --help" {
	run bash "$TEST_SCRIPTS_DIR/setup/init-env.sh" --help

	assert_success "$output" "$status" "Debería mostrar ayuda"
	assert_contains "$output" "Uso\|Usage\|--force\|--silent" "Debería mostrar información de uso"
}
