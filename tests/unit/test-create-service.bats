#!/usr/bin/env bats
# ============================================================================
# Test: test-create-service.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests unitarios para create-service.sh usando BATS.
#
# Uso:
#   bats tests/unit/test-create-service.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'tests/unit/helpers.bash'

@test "create-service.sh existe" {
	assert_file_exists "$TEST_SCRIPTS_DIR/setup/create-service.sh"
}

@test "create-service.sh requiere nombre de servicio" {
	run bash "$TEST_SCRIPTS_DIR/setup/create-service.sh" \
		PROJECT_ROOT="$TEST_TMP_DIR"

	assert_failure "$output" "$status" "Debería fallar sin nombre de servicio"
	assert_contains "$output" "Debes especificar\|nombre del servicio" "Debería indicar que se requiere nombre"
}

@test "create-service.sh crea estructura de directorios" {
	local project_dir=$(create_temp_dir)
	local service_name="test-service-$(date +%s)"
	local service_dir="$project_dir/containers/$service_name"

	run bash "$TEST_SCRIPTS_DIR/setup/create-service.sh" "$service_name" \
		PROJECT_ROOT="$project_dir"

	assert_success "$output" "$status" "Debería crear estructura exitosamente"
	assert_dir_exists "$service_dir" "Debería crear directorio del servicio"
	assert_dir_exists "$service_dir/scripts" "Debería crear directorio scripts"
	assert_dir_exists "$service_dir/tests" "Debería crear directorio tests"
	assert_dir_exists "$service_dir/config" "Debería crear directorio config"
	assert_dir_exists "$service_dir/docs" "Debería crear directorio docs"
}

@test "create-service.sh crea docker-compose.yml" {
	local project_dir=$(create_temp_dir)
	local service_name="test-service-$(date +%s)"
	local service_dir="$project_dir/containers/$service_name"

	run bash "$TEST_SCRIPTS_DIR/setup/create-service.sh" "$service_name" \
		PROJECT_ROOT="$project_dir"

	assert_file_exists "$service_dir/docker-compose.yml" "Debería crear docker-compose.yml"

	# Verificar contenido
	local compose_content=$(cat "$service_dir/docker-compose.yml")
	assert_contains "$compose_content" "$service_name" "docker-compose.yml debería contener nombre del servicio"
	assert_contains "$compose_content" "version\|services" "docker-compose.yml debería tener estructura válida"
}

@test "create-service.sh crea Makefile" {
	local project_dir=$(create_temp_dir)
	local service_name="test-service-$(date +%s)"
	local service_dir="$project_dir/containers/$service_name"

	run bash "$TEST_SCRIPTS_DIR/setup/create-service.sh" "$service_name" \
		PROJECT_ROOT="$project_dir"

	assert_file_exists "$service_dir/Makefile" "Debería crear Makefile"

	# Verificar contenido
	local makefile_content=$(cat "$service_dir/Makefile")
	assert_contains "$makefile_content" "$service_name" "Makefile debería contener nombre del servicio"
	assert_contains "$makefile_content" "deploy-local\|down-$service_name" "Makefile debería tener comandos básicos"
}

@test "create-service.sh crea README.md" {
	local project_dir=$(create_temp_dir)
	local service_name="test-service-$(date +%s)"
	local service_dir="$project_dir/containers/$service_name"

	run bash "$TEST_SCRIPTS_DIR/setup/create-service.sh" "$service_name" \
		PROJECT_ROOT="$project_dir"

	assert_file_exists "$service_dir/README.md" "Debería crear README.md"

	# Verificar contenido
	local readme_content=$(cat "$service_dir/README.md")
	assert_contains "$readme_content" "$service_name" "README.md debería contener nombre del servicio"
}

@test "create-service.sh crea .gitignore" {
	local project_dir=$(create_temp_dir)
	local service_name="test-service-$(date +%s)"
	local service_dir="$project_dir/containers/$service_name"

	run bash "$TEST_SCRIPTS_DIR/setup/create-service.sh" "$service_name" \
		PROJECT_ROOT="$project_dir"

	assert_file_exists "$service_dir/.gitignore" "Debería crear .gitignore"
}

@test "create-service.sh crea .env-template" {
	local project_dir=$(create_temp_dir)
	local service_name="test-service-$(date +%s)"
	local service_dir="$project_dir/containers/$service_name"

	run bash "$TEST_SCRIPTS_DIR/setup/create-service.sh" "$service_name" \
		PROJECT_ROOT="$project_dir"

	assert_file_exists "$service_dir/.env-template" "Debería crear .env-template"

	# Verificar contenido
	local template_content=$(cat "$service_dir/.env-template")
	local service_upper=$(echo "$service_name" | tr '[:lower:]' '[:upper:]')
	assert_contains "$template_content" "$service_upper" ".env-template debería contener variables del servicio"
}

@test "create-service.sh falla si el servicio ya existe" {
	local project_dir=$(create_temp_dir)
	local service_name="test-service-$(date +%s)"
	local service_dir="$project_dir/containers/$service_name"

	# Crear directorio existente
	mkdir -p "$service_dir"

	run bash "$TEST_SCRIPTS_DIR/setup/create-service.sh" "$service_name" \
		PROJECT_ROOT="$project_dir"

	assert_failure "$output" "$status" "Debería fallar si el servicio ya existe"
	assert_contains "$output" "ya existe" "Debería indicar que el servicio ya existe"
}

@test "create-service.sh muestra próximos pasos al finalizar" {
	local project_dir=$(create_temp_dir)
	local service_name="test-service-$(date +%s)"

	run bash "$TEST_SCRIPTS_DIR/setup/create-service.sh" "$service_name" \
		PROJECT_ROOT="$project_dir"

	assert_contains "$output" "Próximos pasos\|docker-compose.yml\|README.md" "Debería mostrar próximos pasos"
}

@test "create-service.sh no acepta nombre de servicio vacío" {
	local project_dir=$(create_temp_dir)

	run bash "$TEST_SCRIPTS_DIR/setup/create-service.sh" "" \
		PROJECT_ROOT="$project_dir"

	assert_failure "$output" "$status" "Debería fallar con nombre vacío"
	assert_contains "$output" "no puede estar vacío\|Debes especificar" "Debería indicar que el nombre no puede estar vacío"
}
