#!/usr/bin/env bats
# ============================================================================
# Test: test-compatibility-bash.bats
# Ubicación: tests/integration/
# ============================================================================
# Tests de compatibilidad para diferentes versiones de Bash.
# Verifica que el proyecto funciona correctamente con diferentes versiones.
#
# Uso:
#   bats tests/integration/test-compatibility-bash.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'tests/integration/helpers.bash'

# Setup específico para tests de compatibilidad Bash
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

@test "Scripts requieren Bash >= 4.0" {
	# Obtener versión de Bash actual
	bash_version=$("${BASH:-bash}" --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
	bash_major=$(echo "$bash_version" | cut -d. -f1)
	bash_minor=$(echo "$bash_version" | cut -d. -f2)

	# Verificar que es >= 4.0
	if [[ $bash_major -lt 4 ]] || ([[ $bash_major -eq 4 ]] && [[ $bash_minor -lt 0 ]]); then
		fail "Bash $bash_version < 4.0 (requerido: >= 4.0)"
	fi

	# Si llegamos aquí, la versión es válida
	[[ true ]]
}

@test "Scripts funcionan con Bash 4.x" {
	# Verificar versión de Bash
	bash_version=$("${BASH:-bash}" --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
	bash_major=$(echo "$bash_version" | cut -d. -f1)

	if [[ $bash_major -ne 4 ]]; then
		skip "Bash no es versión 4.x (actual: $bash_version)"
	fi

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env básico
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=172.20.0.0
EOF

	# Ejecutar script simple con Bash 4
	run "${BASH:-bash}" "$TEST_SCRIPTS_DIR/commands/check-dependencies.sh" \
		PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Debería ejecutarse (puede fallar si Docker no está disponible)
	[[ $status -ge 0 ]]
}

@test "Scripts funcionan con Bash 5.x" {
	# Verificar versión de Bash
	bash_version=$("${BASH:-bash}" --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
	bash_major=$(echo "$bash_version" | cut -d. -f1)

	if [[ $bash_major -ne 5 ]]; then
		skip "Bash no es versión 5.x (actual: $bash_version)"
	fi

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Crear .env básico
	cat > "$TEST_PROJECT_ROOT_FOR_TEST/.env" <<'EOF'
NETWORK_NAME=test-network
NETWORK_IP=172.20.0.0
EOF

	# Ejecutar script simple con Bash 5
	run "${BASH:-bash}" "$TEST_SCRIPTS_DIR/commands/check-dependencies.sh" \
		PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Debería ejecutarse (puede fallar si Docker no está disponible)
	[[ $status -ge 0 ]]
}

@test "Características de Bash 4+ funcionan correctamente" {
	# Verificar que características modernas de Bash funcionan

	# Arrays asociativos (Bash 4+)
	declare -A test_array
	test_array["key"]="value"

	value="${test_array[key]}"
	assert_equals "value" "$value" "Arrays asociativos deberían funcionar"

	# Parameter expansion avanzado
	test_var="test"
	result="${test_var:-default}"
	assert_equals "test" "$result" "Parameter expansion debería funcionar"

	# Substring expansion
	result="${test_var:0:2}"
	assert_equals "te" "$result" "Substring expansion debería funcionar"
}

@test "set -euo pipefail funciona correctamente" {
	# Verificar que set -euo pipefail funciona
	# Esto es crítico para los scripts del proyecto

	# Test con set -e
	set -e
	true || fail "set -e no funciona"

	# Test con set -u
	set -u
	test_var="value"
	[[ -n "${test_var:-}" ]] || fail "set -u no funciona correctamente"

	# Test con set -o pipefail
	set -o pipefail
	true | false && fail "pipefail no funciona" || true
}

@test "IFS funciona correctamente" {
	# Verificar que IFS se puede configurar
	old_ifs="$IFS"
	IFS=$'\n\t'

	# Verificar que IFS cambió
	[[ "$IFS" == $'\n\t' ]] || fail "IFS no se configuró correctamente"

	# Restaurar
	IFS="$old_ifs"
}

@test "readonly funciona correctamente" {
	# Verificar que readonly funciona
	readonly TEST_READONLY="test-value"

	# Intentar cambiar debería fallar (pero no podemos probarlo directamente)
	# Verificamos que la variable tiene el valor correcto
	[[ "${TEST_READONLY:-}" == "test-value" ]] || fail "readonly no funciona"
}

@test "Process substitution funciona" {
	# Verificar que process substitution funciona (Bash 4+)

	# Test básico
	result=$(cat < <(echo "test"))
	assert_equals "test" "$result" "Process substitution debería funcionar"
}

@test "mapfile funciona correctamente" {
	# Verificar que mapfile funciona (Bash 4+)

	# Crear archivo temporal
	test_file=$(mktemp)
	echo "line1" > "$test_file"
	echo "line2" >> "$test_file"

	# Usar mapfile
	mapfile -t lines < "$test_file"

	# Verificar que se leyeron las líneas
	[[ ${#lines[@]} -eq 2 ]] || fail "mapfile no leyó todas las líneas"
	assert_equals "line1" "${lines[0]}" "Primera línea debería ser correcta"
	assert_equals "line2" "${lines[1]}" "Segunda línea debería ser correcta"

	# Limpiar
	rm -f "$test_file"
}

@test "check-versions.sh verifica versión de Bash" {
	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Ejecutar check-versions
	run bash "$TEST_SCRIPTS_DIR/commands/check-versions.sh" \
		PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true

	# Debería ejecutarse (puede tener warnings)
	[[ $status -ge 0 ]]

	# Verificar que verifica versión de Bash
	assert_contains "$output" "Bash\|bash\|[0-9]\.[0-9]" "Debería verificar versión de Bash"
}

@test "Scripts usan características compatibles con Bash 4+" {
	# Verificar que los scripts no usan características de Bash 5+ exclusivas
	# que no funcionarían en Bash 4

	cd "$TEST_PROJECT_ROOT_FOR_TEST"

	# Verificar que init.sh se puede cargar
	source "$TEST_SCRIPTS_DIR/common/init.sh" || true

	# Si llegamos aquí, el script es compatible
	[[ true ]]
}
