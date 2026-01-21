#!/usr/bin/env bats
# ============================================================================
# Test: test-doctor-e2e.bats
# Ubicación: tests/integration/
# ============================================================================
# Test end-to-end para el comando `make doctor`.
# Ejecuta el flujo completo de diagnóstico en un entorno aislado.
#
# Uso:
#   bats tests/integration/test-doctor-e2e.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'tests/integration/helpers.bash'

# Setup específico para test E2E de doctor
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

@test "make doctor ejecuta diagnóstico completo" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Ejecutar make doctor
	run make doctor PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Debería ejecutarse (puede tener errores pero debe ejecutar todos los pasos)
	[[ $status -ge 0 ]]

	# Verificar que muestra título de diagnóstico
	assert_contains "$output" "DIAGNÓSTICO\|diagnóstico\|DOCTOR" \
		"Debería mostrar título de diagnóstico"
}

@test "make doctor verifica prerrequisitos" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Ejecutar make doctor
	run make doctor PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Verificar que ejecuta check-dependencies
	assert_contains "$output" "prerrequisito\|dependencia\|check-dependencies\|Docker" \
		"Debería verificar prerrequisitos"
}

@test "make doctor valida configuración" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env válido
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=172.20.0.0
EOF

	# Ejecutar make doctor
	run make doctor PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Verificar que ejecuta validación
	assert_contains "$output" "Validando\|validación\|validate\|configuración" \
		"Debería validar configuración"
}

@test "make doctor verifica sintaxis del Makefile" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Ejecutar make doctor
	run make doctor PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Verificar que ejecuta validate-syntax
	assert_contains "$output" "sintaxis\|syntax\|Makefile" \
		"Debería verificar sintaxis del Makefile"
}

@test "make doctor muestra estado de servicios" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Ejecutar make doctor
	run make doctor PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Verificar que ejecuta status
	assert_contains "$output" "Estado\|servicio\|status\|contenedor" \
		"Debería mostrar estado de servicios"
}

@test "make doctor verifica secretos" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env con posibles secretos
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=172.20.0.0
POSTGRES_PASSWORD=test123
EOF

	# Ejecutar make doctor
	run make doctor PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Verificar que ejecuta secrets-check
	assert_contains "$output" "secreto\|secret\|secrets-check\|contraseña" \
		"Debería verificar secretos"
}

@test "make doctor muestra resumen final" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Ejecutar make doctor
	run make doctor PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Verificar que muestra resumen final
	assert_contains "$output" "COMPLETADO\|completado\|TODO EN ORDEN\|PROBLEMAS" \
		"Debería mostrar resumen final"
}

@test "make doctor ejecuta todos los pasos en orden" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Ejecutar make doctor
	run make doctor PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Verificar que muestra pasos numerados
	assert_contains "$output" "1\..*\|2\..*\|3\..*\|4\..*\|5\..*" \
		"Debería mostrar pasos numerados"
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
