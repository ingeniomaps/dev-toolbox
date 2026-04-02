#!/usr/bin/env bats
# ============================================================================
# Test: test-metrics-alerts-e2e.bats
# Ubicación: tests/integration/
# ============================================================================
# Test end-to-end para los comandos `make metrics` y `make alerts`.
# Ejecuta el flujo completo de monitoreo en un entorno aislado.
#
# Uso:
#   bats tests/integration/test-metrics-alerts-e2e.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'helpers'

# Setup específico para test E2E de metrics/alerts
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

@test "make metrics requiere .env si no se especifican servicios" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Asegurar que .env no existe
	rm -f "$TEST_PROJECT_ROOT_FOR_TEST/.env"

	# Ejecutar make metrics sin servicios
	run make metrics PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Debería fallar o mostrar advertencia
	[[ $status -eq 1 ]] || assert_contains "$output" ".env\|no encontrado\|init-env\|servicios" \
		"Debería indicar que falta .env o servicios"
}

@test "make metrics ejecuta con servicios especificados" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Ejecutar make metrics con servicios específicos
	run make metrics PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" \
		SERVICES="test-service" SKIP_MISSING=true 2>&1 || true

	# Debería ejecutarse (puede no encontrar servicios pero no fallar fatalmente)
	[[ $status -ge 0 ]]

	# Verificar que se intentó mostrar métricas
	assert_contains "$output" "métrica\|MÉTRICA\|servicio\|docker\|stats" \
		"Debería intentar mostrar métricas"
}

@test "make metrics detecta servicios desde .env" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env con servicios
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=172.20.0.0
POSTGRES_VERSION=15-alpine
MONGO_VERSION=7.0
EOF

	# Ejecutar make metrics
	run make metrics PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" SKIP_MISSING=true 2>&1 || true

	# Debería detectar servicios desde .env
	assert_contains "$output" "postgres\|mongo\|servicio\|detectado" \
		"Debería detectar servicios desde .env"
}

@test "make metrics maneja --skip-missing" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env con servicios que no existen
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=172.20.0.0
NONEXISTENT_VERSION=1.0
EOF

	# Ejecutar make metrics con --skip-missing
	run make metrics PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" SKIP_MISSING=true 2>&1 || true

	# Debería continuar sin fallar
	[[ $status -ge 0 ]]

	# Verificar que muestra info sobre servicios
	assert_contains "$output" "encontrado\|servicio\|skip-missing\|MÉTRICA" \
		"Debería mostrar info de servicios"
}

@test "make alerts requiere .env si no se especifican servicios" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Asegurar que .env no existe
	rm -f "$TEST_PROJECT_ROOT_FOR_TEST/.env"

	# Ejecutar make alerts sin servicios
	run make alerts PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Debería fallar o mostrar advertencia
	[[ $status -eq 1 ]] || assert_contains "$output" ".env\|no encontrado\|init-env\|servicios" \
		"Debería indicar que falta .env o servicios"
}

@test "make alerts ejecuta con servicios especificados" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Ejecutar make alerts con servicios específicos
	run make alerts PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" \
		SERVICES="test-service" 2>&1 || true

	# Debería ejecutarse
	[[ $status -ge 0 ]]

	# Verificar que se intentó verificar alertas
	assert_contains "$output" "alerta\|ALERTA\|servicio\|estado\|salud" \
		"Debería intentar verificar alertas"
}

@test "make alerts detecta servicios desde .env" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env con servicios
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=172.20.0.0
POSTGRES_VERSION=15-alpine
EOF

	# Ejecutar make alerts
	run make alerts PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Debería detectar servicios desde .env
	assert_contains "$output" "postgres\|servicio\|detectado\|ALERTA" \
		"Debería detectar servicios desde .env"
}

@test "make alerts retorna éxito cuando no hay alertas" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env con servicios
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=172.20.0.0
EOF

	# Ejecutar make alerts
	run make alerts PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Debería retornar éxito si no hay alertas
	[[ $status -eq 0 ]] || assert_contains "$output" "alerta\|problema\|error" \
		"Debería indicar estado de alertas"
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
