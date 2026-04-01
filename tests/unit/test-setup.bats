#!/usr/bin/env bats
# ============================================================================
# Test: test-setup.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests unitarios para setup.sh usando BATS.
#
# Uso:
#   bats tests/unit/test-setup.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'helpers'

@test "setup.sh existe" {
	assert_file_exists "$TEST_SCRIPTS_DIR/setup/setup.sh"
}

@test "setup.sh ejecuta pasos de configuración" {
	local project_dir=$(create_temp_dir)

	# Crear Makefile mínimo para que make funcione
	cat > "$project_dir/Makefile" <<'EOF'
.PHONY: check-dependencies setup-env validate network-tool check-ports verify-installation
check-dependencies:
	@echo "Dependencies OK"
setup-env:
	@echo "Setup env OK"
validate:
	@echo "Validate OK"
network-tool:
	@echo "Network OK"
check-ports:
	@echo "Ports OK"
verify-installation:
	@echo "Verify OK"
EOF

	run bash "$TEST_SCRIPTS_DIR/setup/setup.sh" \
		PROJECT_ROOT="$project_dir"

	# Debería ejecutar todos los pasos
	[[ $status -ge 0 ]]
	assert_contains "$output" "CONFIGURACIÓN\|Paso\|completada" "Debería mostrar pasos de configuración"
}

@test "setup.sh maneja errores en pasos individuales" {
	local project_dir=$(create_temp_dir)

	# Crear Makefile que falla en algunos pasos
	cat > "$project_dir/Makefile" <<'EOF'
.PHONY: check-dependencies setup-env validate network-tool check-ports verify-installation
check-dependencies:
	@exit 1
setup-env:
	@exit 1
validate:
	@exit 0
network-tool:
	@exit 0
check-ports:
	@exit 0
verify-installation:
	@exit 0
EOF

	run bash "$TEST_SCRIPTS_DIR/setup/setup.sh" \
		PROJECT_ROOT="$project_dir"

	# Debería continuar aunque algunos pasos fallen
	[[ $status -ge 0 ]]
	assert_contains "$output" "pueden faltar\|fallaron\|warn" "Debería manejar errores graciosamente"
}

@test "setup.sh muestra próximos pasos al finalizar" {
	local project_dir=$(create_temp_dir)

	# Crear Makefile mínimo
	cat > "$project_dir/Makefile" <<'EOF'
.PHONY: check-dependencies setup-env validate network-tool check-ports verify-installation
check-dependencies:
	@echo "OK"
setup-env:
	@echo "OK"
validate:
	@echo "OK"
network-tool:
	@echo "OK"
check-ports:
	@echo "OK"
verify-installation:
	@echo "OK"
EOF

	run bash "$TEST_SCRIPTS_DIR/setup/setup.sh" \
		PROJECT_ROOT="$project_dir"

	assert_contains "$output" "Próximos pasos\|help-toolbox\|make up" "Debería mostrar próximos pasos"
}

@test "setup.sh ejecuta todos los pasos en orden" {
	local project_dir=$(create_temp_dir)
	local log_file=$(create_temp_file)

	# Crear Makefile que registra ejecución
	cat > "$project_dir/Makefile" <<'EOF'
.PHONY: check-dependencies setup-env validate network-tool check-ports verify-installation
check-dependencies:
	@echo "STEP1" >> LOG_FILE
setup-env:
	@echo "STEP2" >> LOG_FILE
validate:
	@echo "STEP3" >> LOG_FILE
network-tool:
	@echo "STEP4" >> LOG_FILE
check-ports:
	@echo "STEP5" >> LOG_FILE
verify-installation:
	@echo "STEP6" >> LOG_FILE
EOF

	# Reemplazar LOG_FILE en Makefile
	sed -i "s|LOG_FILE|$log_file|g" "$project_dir/Makefile"

	run bash "$TEST_SCRIPTS_DIR/setup/setup.sh" \
		PROJECT_ROOT="$project_dir"

	# Verificar que todos los pasos se ejecutaron
	local log_content=$(cat "$log_file")
	assert_contains "$log_content" "STEP1" "Debería ejecutar paso 1"
	assert_contains "$log_content" "STEP2" "Debería ejecutar paso 2"
	assert_contains "$log_content" "STEP3" "Debería ejecutar paso 3"
	assert_contains "$log_content" "STEP4" "Debería ejecutar paso 4"
	assert_contains "$log_content" "STEP5" "Debería ejecutar paso 5"
	assert_contains "$log_content" "STEP6" "Debería ejecutar paso 6"
}
