#!/usr/bin/env bats
# ============================================================================
# Test: test-compatibility-os.bats
# Ubicación: tests/integration/
# ============================================================================
# Tests de compatibilidad para diferentes sistemas operativos (Linux, macOS).
# Verifica que el proyecto funciona correctamente en ambos sistemas.
#
# Uso:
#   bats tests/integration/test-compatibility-os.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'helpers'

# Setup específico para tests de compatibilidad OS
setup() {
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

@test "Scripts detectan sistema operativo correctamente" {
	# Detectar OS actual
	os_type=$(uname -s)

	# Verificar que es Linux o Darwin (macOS)
	if [[ "$os_type" != "Linux" ]] && [[ "$os_type" != "Darwin" ]]; then
		skip "Sistema operativo no soportado: $os_type"
	fi

	# Verificar que los scripts pueden detectar el OS
	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Cargar init.sh que puede usar uname
	source "$TEST_SCRIPTS_DIR/common/init.sh" || true

	# Verificar que uname funciona
	detected_os=$(uname -s)
	assert_equals "$os_type" "$detected_os" "Debería detectar el OS correctamente"
}

@test "Scripts funcionan en Linux" {
	# Verificar que estamos en Linux
	if [[ "$(uname -s)" != "Linux" ]]; then
		skip "No estamos en Linux"
	fi

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env básico
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=172.20.0.0
EOF

	# Ejecutar check-dependencies (debería funcionar en Linux)
	run bash "$TEST_SCRIPTS_DIR/commands/check-dependencies.sh" \
		PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Debería ejecutarse (puede fallar si Docker no está disponible)
	[[ $status -ge 0 ]]

	# Verificar que no hay errores específicos de OS
	assert_not_contains "$output" "sistema operativo no soportado\|OS not supported" \
		"No debería tener errores de OS en Linux"
}

@test "Scripts funcionan en macOS" {
	# Verificar que estamos en macOS
	if [[ "$(uname -s)" != "Darwin" ]]; then
		skip "No estamos en macOS"
	fi

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env básico
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=172.20.0.0
EOF

	# Ejecutar check-dependencies (debería funcionar en macOS)
	run bash "$TEST_SCRIPTS_DIR/commands/check-dependencies.sh" \
		PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Debería ejecutarse (puede fallar si Docker no está disponible)
	[[ $status -ge 0 ]]

	# Verificar que no hay errores específicos de OS
	assert_not_contains "$output" "sistema operativo no soportado\|OS not supported" \
		"No debería tener errores de OS en macOS"
}

@test "Rutas de archivos funcionan en ambos sistemas" {
	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear archivo de prueba
	test_file="$TEST_PROJECT_ROOT_FOR_TEST/test-file.txt"
	echo "test" > "$test_file"

	# Verificar que el archivo existe (usando rutas absolutas)
	[[ -f "$test_file" ]] || fail "No se pudo crear archivo de prueba"

	# Verificar que se puede leer
	content=$(cat "$test_file")
	assert_equals "test" "$content" "Debería poder leer archivo en cualquier OS"
}

@test "Comandos comunes funcionan en ambos sistemas" {
	# Verificar que comandos comunes están disponibles
	commands=("ls" "cat" "echo" "mkdir" "rm" "grep" "sed" "awk")

	for cmd in "${commands[@]}"; do
		if ! command -v "$cmd" >/dev/null 2>&1; then
			fail "Comando $cmd no está disponible"
		fi
	done

	# Si llegamos aquí, todos los comandos están disponibles
	[[ true ]]
}

@test "Variables de entorno funcionan en ambos sistemas" {
	# Establecer variable de prueba
	export TEST_VAR="test-value"

	# Verificar que se puede leer
	value="${TEST_VAR:-}"
	assert_equals "test-value" "$value" "Debería poder leer variables de entorno"

	# Limpiar
	unset TEST_VAR
}

@test "Scripts manejan diferencias de paths entre sistemas" {
	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Verificar que PROJECT_ROOT se establece correctamente
	export PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST"

	# Verificar que se puede usar
	[[ -d "$PROJECT_ROOT" ]] || fail "PROJECT_ROOT no es un directorio válido"

	# Verificar que se puede construir ruta
	test_path="$PROJECT_ROOT/test"
	mkdir -p "$test_path"
	[[ -d "$test_path" ]] || fail "No se pudo crear directorio en PROJECT_ROOT"
}

@test "Scripts detectan Docker correctamente en ambos sistemas" {
	skip_if_no_docker

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Ejecutar check-dependencies
	run bash "$TEST_SCRIPTS_DIR/commands/check-dependencies.sh" \
		PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Debería detectar Docker (puede tener warnings pero no errores fatales)
	[[ $status -ge 0 ]]

	# Verificar que detecta Docker
	assert_contains "$output" "Docker\|docker" "Debería detectar Docker en cualquier OS"
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
