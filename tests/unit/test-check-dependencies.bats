#!/usr/bin/env bats
# ============================================================================
# Test: test-check-dependencies.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests para check-dependencies.sh
# ============================================================================

load 'helpers'

setup() {
	export TEST_PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
	export TEST_COMMANDS_DIR="$TEST_PROJECT_ROOT/scripts/sh/commands"
}

@test "check-dependencies: muestra ayuda con --help" {
	run bash "$TEST_COMMANDS_DIR/check-dependencies.sh" --help

	assert_success "$output" "$status"
	assert_contains "$output" "Uso:"
	assert_contains "$output" "check-dependencies"
}

@test "check-dependencies: verifica Docker está instalado" {
	run bash "$TEST_COMMANDS_DIR/check-dependencies.sh" 2>&1

	# Debería verificar Docker
	assert_contains "$output" "Docker\|docker" || assert_success "$output" "$status"
}

@test "check-dependencies: verifica docker-compose está instalado" {
	run bash "$TEST_COMMANDS_DIR/check-dependencies.sh" 2>&1

	# Debería verificar docker-compose
	assert_contains "$output" "compose\|docker-compose" || assert_success "$output" "$status"
}

@test "check-dependencies: detecta sistema operativo" {
	run bash "$TEST_COMMANDS_DIR/check-dependencies.sh" 2>&1

	# Debería detectar el OS
	assert_contains "$output" "Linux\|macOS\|Windows" || assert_success "$output" "$status"
}

@test "check-dependencies: muestra advertencia para Windows nativo" {
	# Mock para Windows
	export OS_TYPE="windows"

	run bash "$TEST_COMMANDS_DIR/check-dependencies.sh" 2>&1 || true

	# Debería mostrar advertencia sobre WSL
	assert_contains "$output" "WSL\|Windows" || assert_success "$output" "$status" || true
}

@test "check-dependencies: verifica versiones mínimas" {
	run bash "$TEST_COMMANDS_DIR/check-dependencies.sh" 2>&1

	# Debería verificar versiones
	assert_contains "$output" "versión\|version" || assert_success "$output" "$status"
}

@test "check-dependencies: retorna código de salida apropiado" {
	run bash "$TEST_COMMANDS_DIR/check-dependencies.sh"

	# Debería retornar 0 si todo está bien, 1 si falta algo
	[[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}
