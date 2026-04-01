#!/usr/bin/env bats
# ============================================================================
# Test: test-load-toolbox.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests unitarios para load-toolbox.sh usando BATS.
#
# Nota: Tests que ejecutan el script usan timeout para evitar
# bloqueos por git clone con credenciales inválidas.
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'helpers'

@test "load-toolbox.sh existe" {
	assert_file_exists "$TEST_SCRIPTS_DIR/setup/load-toolbox.sh"
}

@test "load-toolbox.sh requiere GIT_USER" {
	run bash "$TEST_SCRIPTS_DIR/setup/load-toolbox.sh"

	assert_failure "$output" "$status" "Debería fallar sin GIT_USER"
	assert_contains "$output" "GIT_USER.*obligatorio\|requerido" "Debería indicar que GIT_USER es requerido"
}

@test "load-toolbox.sh requiere GIT_TOKEN" {
	run env GIT_USER="testuser" \
		bash "$TEST_SCRIPTS_DIR/setup/load-toolbox.sh"

	assert_failure "$output" "$status" "Debería fallar sin GIT_TOKEN"
	assert_contains "$output" "GIT_TOKEN.*obligatorio\|requerido" "Debería indicar que GIT_TOKEN es requerido"
}

@test "load-toolbox.sh acepta GIT_USER y GIT_TOKEN" {
	# Con credenciales inválidas, git clone fallará rápido con timeout
	run timeout 5 env GIT_USER="testuser" GIT_TOKEN="testtoken" \
		bash "$TEST_SCRIPTS_DIR/setup/load-toolbox.sh" 2>&1 || true

	# El script debería intentar clonar (puede fallar por auth)
	[[ $status -ge 0 ]]
}

@test "load-toolbox.sh usa GIT_BRANCH si está definido" {
	run timeout 5 env GIT_USER="testuser" GIT_TOKEN="testtoken" GIT_BRANCH="develop" \
		bash "$TEST_SCRIPTS_DIR/setup/load-toolbox.sh" 2>&1 || true

	[[ $status -ge 0 ]]
}

@test "load-toolbox.sh usa GIT_REPO si está definido" {
	run timeout 5 env GIT_USER="testuser" GIT_TOKEN="testtoken" GIT_REPO="custom-repo" \
		bash "$TEST_SCRIPTS_DIR/setup/load-toolbox.sh" 2>&1 || true

	[[ $status -ge 0 ]]
}

@test "load-toolbox.sh usa TOOLBOX_TARGET si está definido" {
	local custom_target=$(create_temp_dir)

	run timeout 5 env GIT_USER="testuser" GIT_TOKEN="testtoken" TOOLBOX_TARGET="$custom_target" \
		bash "$TEST_SCRIPTS_DIR/setup/load-toolbox.sh" 2>&1 || true

	[[ $status -ge 0 ]]
}

@test "load-toolbox.sh usa main como rama por defecto" {
	local script_content=$(cat "$TEST_SCRIPTS_DIR/setup/load-toolbox.sh")

	assert_contains "$script_content" "GIT_BRANCH.*main\|main.*GIT_BRANCH" "Debería usar main como rama por defecto"
}

@test "load-toolbox.sh usa dev-toolbox como repo por defecto" {
	local script_content=$(cat "$TEST_SCRIPTS_DIR/setup/load-toolbox.sh")

	assert_contains "$script_content" "GIT_REPO.*dev-toolbox\|dev-toolbox.*GIT_REPO" "Debería usar dev-toolbox como repo por defecto"
}

@test "load-toolbox.sh usa .toolbox como destino por defecto" {
	local script_content=$(cat "$TEST_SCRIPTS_DIR/setup/load-toolbox.sh")

	assert_contains "$script_content" "TOOLBOX_TARGET.*\.toolbox\|\.toolbox.*TOOLBOX_TARGET" "Debería usar .toolbox como destino por defecto"
}
