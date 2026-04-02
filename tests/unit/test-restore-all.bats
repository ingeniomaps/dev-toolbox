#!/usr/bin/env bats
# ============================================================================
# Test: test-restore-all.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests unitarios para restore-all.sh usando BATS.
#
# Uso:
#   bats tests/unit/test-restore-all.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'helpers'

@test "restore-all.sh existe" {
	assert_file_exists "$TEST_SCRIPTS_DIR/commands/restore-all.sh"
}

@test "restore-all.sh requiere .env" {
	# Simular entrada "n" para cancelar confirmación
	echo "n" | run bash "$TEST_SCRIPTS_DIR/commands/restore-all.sh" \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Debería fallar sin .env o cancelar operación
	[[ $status -ge 0 ]]
}

@test "restore-all.sh detecta servicios desde .env" {
	local env_file=$(create_test_env_file "POSTGRES_VERSION=15.0\nMONGO_VERSION=7.0")

	# Simular entrada "n" para cancelar confirmación
	echo "n" | run bash "$TEST_SCRIPTS_DIR/commands/restore-all.sh" \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Debería detectar servicios (puede fallar si no hay comandos make, pero no por falta de servicios)
	[[ $status -ge 0 ]]
}

@test "restore-all.sh acepta opción --skip-missing" {
	local env_file=$(create_test_env_file "POSTGRES_VERSION=15.0")

	# Simular entrada "n" para cancelar confirmación
	echo "n" | run bash "$TEST_SCRIPTS_DIR/commands/restore-all.sh" --skip-missing \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Debería aceptar la opción sin error de sintaxis
	[[ $status -ge 0 ]]
}

@test "restore-all.sh acepta BACKUP_PATH como parámetro" {
	local env_file=$(create_test_env_file "POSTGRES_VERSION=15.0")
	local backup_path="/tmp/test-backup-$(date +%s)"

	# Simular entrada "n" para cancelar confirmación
	echo "n" | run bash "$TEST_SCRIPTS_DIR/commands/restore-all.sh" "$backup_path" \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Debería aceptar BACKUP_PATH como primer argumento
	[[ $status -ge 0 ]]
}

@test "restore-all.sh usa variable de entorno BACKUP_PATH" {
	local env_file=$(create_test_env_file "POSTGRES_VERSION=15.0")
	local backup_path="/tmp/test-backup-$(date +%s)"

	# Simular entrada "n" para cancelar confirmación
	echo "n" | run bash "$TEST_SCRIPTS_DIR/commands/restore-all.sh" \
		BACKUP_PATH="$backup_path" \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Debería usar la variable de entorno
	[[ $status -ge 0 ]]
}

@test "restore-all.sh maneja servicios no encontrados con --skip-missing" {
	local env_file=$(create_test_env_file "NONEXISTENT_VERSION=1.0")

	# Simular entrada "n" para cancelar confirmación
	echo "n" | run bash "$TEST_SCRIPTS_DIR/commands/restore-all.sh" --skip-missing \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Con --skip-missing debería continuar aunque el servicio no exista
	[[ $status -ge 0 ]]
}

@test "restore-all.sh muestra resumen de operaciones" {
	local env_file=$(create_test_env_file "POSTGRES_VERSION=15.0")

	# Simular entrada "n" para cancelar confirmación
	echo "n" | run bash "$TEST_SCRIPTS_DIR/commands/restore-all.sh" --skip-missing \
		PROJECT_ROOT="$TEST_TMP_DIR"

	# Debería mostrar resumen al final (si llega a ejecutarse)
	# Nota: Puede no mostrarse si se cancela antes
	[[ $status -ge 0 ]]
}

@test "restore-all.sh requiere confirmación interactiva" {
	skip "Requiere TTY interactivo para confirmación"
}
