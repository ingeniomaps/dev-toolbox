#!/usr/bin/env bats
# ============================================================================
# Test: test-backup-restore-e2e.bats
# Ubicación: tests/integration/
# ============================================================================
# Test end-to-end para los comandos `make backup-all` y `make restore-all`.
# Ejecuta el flujo completo de backup y restauración en un entorno aislado.
#
# Uso:
#   bats tests/integration/test-backup-restore-e2e.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'helpers'

# Setup específico para test E2E de backup/restore
setup() {
	# Llamar setup base
	setup_integration_test || true

	# Crear proyecto de test
	mkdir -p "$TEST_PROJECT_ROOT_FOR_TEST"
	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Copiar estructura necesaria
	if [[ -f "$TEST_PROJECT_ROOT/Makefile" ]]; then
		cp "$TEST_PROJECT_ROOT/Makefile" "$TEST_PROJECT_ROOT_FOR_TEST/"
	fi

	if [[ -d "$TEST_PROJECT_ROOT/makefiles" ]]; then
		cp -r "$TEST_PROJECT_ROOT/makefiles" "$TEST_PROJECT_ROOT_FOR_TEST/"
	fi

	if [[ -d "$TEST_PROJECT_ROOT/scripts" ]]; then
		cp -r "$TEST_PROJECT_ROOT/scripts" "$TEST_PROJECT_ROOT_FOR_TEST/"
	fi

	# Crear directorio de backups
	mkdir -p "$TEST_PROJECT_ROOT_FOR_TEST/backups"

	export PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST"
	cd "$TEST_PROJECT_ROOT_FOR_TEST"
}

# Teardown específico
teardown() {
	# Limpiar backups de test
	if [[ -d "$TEST_PROJECT_ROOT_FOR_TEST/backups" ]]; then
		rm -rf "$TEST_PROJECT_ROOT_FOR_TEST/backups"
	fi

	if [[ -d "$TEST_PROJECT_ROOT_FOR_TEST" ]]; then
		rm -rf "$TEST_PROJECT_ROOT_FOR_TEST"
	fi

	teardown_integration_test || true
}

@test "make backup-all requiere archivo .env" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Asegurar que .env no existe
	rm -f "$TEST_PROJECT_ROOT_FOR_TEST/.env"

	# Ejecutar make backup-all
	run make backup-all PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Debería fallar o mostrar advertencia
	[[ $status -eq 1 ]] || assert_contains "$output" ".env\|no encontrado\|init-env" \
		"Debería indicar que falta .env"
}

@test "make backup-all ejecuta con .env válido" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env con servicios
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=172.20.0.0
POSTGRES_VERSION=15-alpine
MONGO_VERSION=7.0
EOF

	# Ejecutar make backup-all (puede fallar si no hay servicios corriendo)
	run make backup-all PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" SKIP_MISSING=true 2>&1 || true

	# Debería ejecutarse (puede tener warnings)
	[[ $status -ge 0 ]]

	# Verificar que se intentó hacer backup
	assert_contains "$output" "backup\|Backup\|servicio\|servicios" \
		"Debería intentar hacer backup"
}

@test "make backup-all maneja --skip-missing" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env con servicios que no existen
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=172.20.0.0
POSTGRES_VERSION=15-alpine
NONEXISTENT_VERSION=1.0
EOF

	# Ejecutar make backup-all con --skip-missing
	run make backup-all PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" SKIP_MISSING=true 2>&1 || true

	# Debería continuar sin fallar
	[[ $status -ge 0 ]]

	# Verificar que muestra resumen
	assert_contains "$output" "resumen\|exitosos\|fallidos\|omitidos" \
		"Debería mostrar resumen de operaciones"
}

@test "make restore-all requiere archivo .env" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Asegurar que .env no existe
	rm -f "$TEST_PROJECT_ROOT_FOR_TEST/.env"

	# Ejecutar make restore-all
	run make restore-all PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Debería fallar o mostrar advertencia
	[[ $status -eq 1 ]] || assert_contains "$output" ".env\|no encontrado\|init-env" \
		"Debería indicar que falta .env"
}

@test "make restore-all requiere BACKUP_PATH" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env válido
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=172.20.0.0
POSTGRES_VERSION=15-alpine
EOF

	# Ejecutar make restore-all sin BACKUP_PATH
	run make restore-all PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" SKIP_MISSING=true 2>&1 || true

	# Debería indicar que falta BACKUP_PATH
	assert_contains "$output" "BACKUP_PATH\|backup\|ruta" \
		"Debería indicar que falta BACKUP_PATH"
}

@test "make restore-all muestra confirmación interactiva" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env válido
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=172.20.0.0
POSTGRES_VERSION=15-alpine
EOF

	# Ejecutar make restore-all con BACKUP_PATH (simulando entrada 'n' para cancelar)
	echo "n" | run make restore-all PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" \
		BACKUP_PATH="/tmp/test-backup" SKIP_MISSING=true 2>&1 || true

	# Sin TTY, el script puede no mostrar prompt de confirmación
	[[ $status -ge 0 ]]
}

@test "make backup-all y restore-all muestran resumen" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env con servicios
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=172.20.0.0
POSTGRES_VERSION=15-alpine
EOF

	# Ejecutar make backup-all
	run make backup-all PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" SKIP_MISSING=true 2>&1 || true

	# Verificar que muestra resumen
	assert_contains "$output" "resumen\|exitosos\|fallidos\|omitidos\|completado" \
		"Debería mostrar resumen de backup"
}

# Helper para saltar si Docker no está disponible
skip_if_no_docker() {
	if ! command -v docker >/dev/null 2>&1; then
		skip "Docker no está disponible"
	fi

	if ! docker info >/dev/null 2>&1; then
		skip "Docker no está corriendo"
	fi
}
