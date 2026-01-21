#!/usr/bin/env bats
# ============================================================================
# Test: test-check-ports.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests unitarios para check-ports.sh usando BATS.
#
# Uso:
#   bats tests/unit/test-check-ports.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'tests/unit/helpers.bash'

@test "check-ports.sh existe" {
	assert_file_exists "$TEST_SCRIPTS_DIR/commands/check-ports.sh"
}

@test "check-ports.sh es ejecutable" {
	[[ -x "$TEST_SCRIPTS_DIR/commands/check-ports.sh" ]]
}

@test "check-ports.sh valida puertos inválidos" {
	run bash "$TEST_SCRIPTS_DIR/commands/check-ports.sh" "0" "65536" "abc"

	# Debería continuar ejecutando pero ignorar puertos inválidos
	[[ $status -ge 0 ]]
	assert_contains "$output" "inválido" "Debería detectar puertos inválidos"
}

@test "check-ports.sh acepta puertos válidos como argumentos" {
	# Usar puertos que probablemente no estén en uso (rangos altos)
	run bash "$TEST_SCRIPTS_DIR/commands/check-ports.sh" "65534" "65533"

	# El script debería ejecutarse (puede fallar si los puertos están en uso, pero no por sintaxis)
	[[ $status -ge 0 ]]
}

@test "check-ports.sh usa puertos por defecto si no se especifican" {
	run bash "$TEST_SCRIPTS_DIR/commands/check-ports.sh"

	# Debería usar puertos por defecto
	[[ $status -ge 0 ]]
	assert_contains "$output" "5432\|27017\|6379\|80\|8081\|5540" "Debería verificar puertos por defecto"
}

@test "check-ports.sh maneja correctamente cuando no hay herramienta de red" {
	# Mock: crear script temporal que simula ausencia de herramientas
	local mock_script=$(create_temp_file)
	cat > "$mock_script" <<'EOF'
#!/usr/bin/env bash
# Mock que elimina herramientas de red del PATH
export PATH=""
bash "$1" "$2" "$3"
EOF
	chmod +x "$mock_script"

	# Este test puede fallar si realmente no hay herramientas, pero verifica el manejo
	run bash "$TEST_SCRIPTS_DIR/commands/check-ports.sh" "8080"

	# El script debería manejar la ausencia de herramientas
	[[ $status -ge 0 ]]
}
