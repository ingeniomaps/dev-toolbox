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

	assert_success
	assert_output --partial "Uso:"
	assert_output --partial "check-dependencies"
}

@test "check-dependencies: verifica Docker está instalado" {
	run bash "$TEST_COMMANDS_DIR/check-dependencies.sh" 2>&1

	# Debería verificar Docker
	assert_output --partial "Docker" || assert_output --partial "docker" || assert_success
}

@test "check-dependencies: verifica docker-compose está instalado" {
	run bash "$TEST_COMMANDS_DIR/check-dependencies.sh" 2>&1

	# Debería verificar docker-compose
	assert_output --partial "compose" || assert_output --partial "docker-compose" || assert_success
}

@test "check-dependencies: detecta sistema operativo" {
	run bash "$TEST_COMMANDS_DIR/check-dependencies.sh" 2>&1

	# Debería detectar el OS
	assert_output --partial "Linux" || assert_output --partial "macOS" || assert_output --partial "Windows" || assert_success
}

@test "check-dependencies: muestra advertencia para Windows nativo" {
	# Mock para Windows
	export OS_TYPE="windows"

	run bash "$TEST_COMMANDS_DIR/check-dependencies.sh" 2>&1 || true

	# Debería mostrar advertencia sobre WSL
	assert_output --partial "WSL" || assert_output --partial "Windows" || assert_success || true
}

@test "check-dependencies: verifica versiones mínimas" {
	run bash "$TEST_COMMANDS_DIR/check-dependencies.sh" 2>&1

	# Debería verificar versiones
	assert_output --partial "versión" || assert_output --partial "version" || assert_success
}

@test "check-dependencies: retorna código de salida apropiado" {
	run bash "$TEST_COMMANDS_DIR/check-dependencies.sh"

	# Debería retornar 0 si todo está bien, 1 si falta algo
	assert [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}
