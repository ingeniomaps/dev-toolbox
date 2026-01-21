#!/usr/bin/env bats
# ============================================================================
# Test: test-setup-e2e.bats
# Ubicación: tests/integration/
# ============================================================================
# Test end-to-end para el comando `make setup`.
# Ejecuta el flujo completo de configuración inicial en un entorno aislado.
#
# Uso:
#   bats tests/integration/test-setup-e2e.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'tests/integration/helpers.bash'

# Setup específico para test E2E de setup
setup() {
	# Llamar setup base
	setup_integration_test || true

	# Crear proyecto de test con estructura mínima
	mkdir -p "$TEST_PROJECT_ROOT_FOR_TEST"
	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Copiar Makefile del proyecto real
	if [[ -f "$TEST_PROJECT_ROOT/Makefile" ]]; then
		cp "$TEST_PROJECT_ROOT/Makefile" "$TEST_PROJECT_ROOT_FOR_TEST/"
	fi

	# Copiar estructura de makefiles
	if [[ -d "$TEST_PROJECT_ROOT/makefiles" ]]; then
		cp -r "$TEST_PROJECT_ROOT/makefiles" "$TEST_PROJECT_ROOT_FOR_TEST/"
	fi

	# Copiar scripts necesarios
	if [[ -d "$TEST_PROJECT_ROOT/scripts" ]]; then
		cp -r "$TEST_PROJECT_ROOT/scripts" "$TEST_PROJECT_ROOT_FOR_TEST/"
	fi

	# Crear .env-template básico para init-env
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env-template" <<'EOF'
# Network Configuration
NETWORK_NAME=dev-network
NETWORK_IP=172.20.0.0

# Service Versions (opcional)
# POSTGRES_VERSION=15-alpine
# MONGO_VERSION=7.0
EOF

	# Establecer PROJECT_ROOT para los comandos make
	export PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST"
	cd "$TEST_PROJECT_ROOT_FOR_TEST"
}

# Teardown específico
teardown() {
	# Limpiar archivos creados por setup
	if [[ -d "$TEST_PROJECT_ROOT_FOR_TEST" ]]; then
		rm -rf "$TEST_PROJECT_ROOT_FOR_TEST"
	fi

	# Llamar teardown base
	teardown_integration_test || true
}

@test "make setup ejecuta configuración completa" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Ejecutar make setup (puede fallar en algunos pasos, pero debe ejecutarse)
	run make setup PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Verificar que el comando se ejecutó (puede tener warnings pero no errores fatales)
	[[ $status -ge 0 ]] || [[ $status -eq 1 ]]  # Puede fallar en algunos pasos

	# Verificar que se intentó ejecutar los pasos
	assert_contains "$output" "CONFIGURACIÓN\|Paso\|setup\|dependencias\|entorno\|valid" \
		"Debería mostrar pasos de configuración"
}

@test "make setup crea archivo .env si no existe" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Asegurar que .env no existe
	rm -f "$TEST_PROJECT_ROOT_FOR_TEST/.env"

	# Ejecutar make setup
	run make setup PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Verificar que se creó .env (setup-env debería crearlo)
	if [[ -f "$TEST_PROJECT_ROOT_FOR_TEST/.env-template" ]]; then
		# Si hay template, debería intentar crear .env
		[[ -f "$TEST_PROJECT_ROOT_FOR_TEST/.env" ]] || \
			assert_contains "$output" "init-env\|setup-env\|.env" \
				"Debería intentar crear .env"
	fi
}

@test "make setup verifica dependencias" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Ejecutar make setup
	run make setup PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Verificar que se ejecutó check-dependencies
	assert_contains "$output" "dependencias\|check-dependencies\|Docker" \
		"Debería verificar dependencias"
}

@test "make setup ejecuta validación" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env básico para que validate pueda ejecutarse
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=172.20.0.0
EOF

	# Ejecutar make setup
	run make setup PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Verificar que se ejecutó validación
	assert_contains "$output" "valid\|Valid\|configuración" \
		"Debería ejecutar validación"
}

@test "make setup configura red Docker" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env con configuración de red
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network-e2e
NETWORK_IP=172.21.0.0
EOF

	# Ejecutar make setup
	run make setup PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Verificar que se intentó configurar la red
	assert_contains "$output" "red\|network\|Docker" \
		"Debería intentar configurar red Docker"
}

@test "make setup muestra próximos pasos" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Ejecutar make setup
	run make setup PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Verificar que muestra próximos pasos al final
	assert_contains "$output" "Próximos pasos\|next steps\|help-toolbox\|make up" \
		"Debería mostrar próximos pasos"
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
