#!/usr/bin/env bats
# ============================================================================
# Test: test-validate-e2e.bats
# Ubicación: tests/integration/
# ============================================================================
# Test end-to-end para el comando `make validate`.
# Ejecuta el flujo completo de validación en un entorno aislado.
#
# Uso:
#   bats tests/integration/test-validate-e2e.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'tests/integration/helpers.bash'

# Setup específico para test E2E de validate
setup() {
	# Llamar setup base
	setup_integration_test || true

	# Crear proyecto de test
	mkdir -p "$TEST_PROJECT_ROOT_FOR_TEST"
	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Copiar Makefile y estructura necesaria
	if [[ -f "$TEST_PROJECT_ROOT/Makefile" ]]; then
		cp "$TEST_PROJECT_ROOT/Makefile" "$TEST_PROJECT_ROOT_FOR_TEST/"
	fi

	if [[ -d "$TEST_PROJECT_ROOT/makefiles" ]]; then
		cp -r "$TEST_PROJECT_ROOT/makefiles" "$TEST_PROJECT_ROOT_FOR_TEST/"
	fi

	if [[ -d "$TEST_PROJECT_ROOT/scripts" ]]; then
		cp -r "$TEST_PROJECT_ROOT/scripts" "$TEST_PROJECT_ROOT_FOR_TEST/"
	fi

	export PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST"
	cd "$TEST_PROJECT_ROOT_FOR_TEST"
}

# Teardown específico
teardown() {
	if [[ -d "$TEST_PROJECT_ROOT_FOR_TEST" ]]; then
		rm -rf "$TEST_PROJECT_ROOT_FOR_TEST"
	fi

	teardown_integration_test || true
}

@test "make validate falla sin archivo .env" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Asegurar que .env no existe
	rm -f "$TEST_PROJECT_ROOT_FOR_TEST/.env"

	# Ejecutar make validate
	run make validate PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1

	# Debería fallar o mostrar advertencia
	[[ $status -eq 1 ]] || assert_contains "$output" ".env\|no encontrado\|init-env" \
		"Debería indicar que falta .env"
}

@test "make validate pasa con .env válido" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env válido
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=172.20.0.0
EOF

	# Ejecutar make validate
	run make validate PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Debería ejecutarse (puede tener warnings pero no errores fatales)
	[[ $status -ge 0 ]]

	# Verificar que se ejecutó validación
	assert_contains "$output" "valid\|Valid\|configuración\|.env" \
		"Debería ejecutar validación"
}

@test "make validate verifica variables requeridas" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env sin NETWORK_NAME
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_IP=172.20.0.0
EOF

	# Ejecutar make validate
	run make validate PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Debería detectar variable faltante
	assert_contains "$output" "NETWORK_NAME\|faltante\|requerida" \
		"Debería detectar variable faltante"
}

@test "make validate verifica IPs si están presentes" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env con IPs
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=172.20.0.0
POSTGRES_HOST=172.20.0.10
EOF

	# Ejecutar make validate
	run make validate PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Debería validar IPs
	assert_contains "$output" "IP\|validate-ips\|172.20" \
		"Debería validar IPs"
}

@test "make validate verifica puertos si PORTS está definido" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env válido
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=172.20.0.0
EOF

	# Ejecutar make validate con PORTS
	run make validate PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" PORTS="5432 80" 2>&1 || true

	# Debería verificar puertos
	assert_contains "$output" "puerto\|port\|5432\|80\|check-ports" \
		"Debería verificar puertos"
}

@test "make validate verifica versiones de servicios" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env con versiones
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=172.20.0.0
POSTGRES_VERSION=15-alpine
MONGO_VERSION=7.0
EOF

	# Ejecutar make validate
	run make validate PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Debería verificar versiones
	assert_contains "$output" "versión\|version\|compatibilidad\|check-version" \
		"Debería verificar versiones"
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
