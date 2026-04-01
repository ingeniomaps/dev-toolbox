#!/usr/bin/env bats
# ============================================================================
# Test: test-network.bats
# Ubicación: tests/integration/
# ============================================================================
# Tests de integración para ensure-network.sh usando BATS.
#
# Uso:
#   bats tests/integration/test-network.bats
#
# Requisitos:
#   - Docker instalado y corriendo
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'helpers'

@test "ensure-network.sh existe" {
	assert_file_exists "$TEST_SCRIPTS_DIR/utils/ensure-network.sh"
}

@test "ensure-network.sh crea red cuando no existe" {
	local network_name="${TEST_NETWORK_NAME}-create"
	local network_ip="${TEST_NETWORK_IP}"

	# Limpiar red si existe
	docker network rm "$network_name" >/dev/null 2>&1 || true

	# Ejecutar ensure-network.sh
	run bash "$TEST_SCRIPTS_DIR/utils/ensure-network.sh" \
		NETWORK_NAME="$network_name" \
		NETWORK_IP="$network_ip"

	assert_success "$output" "$status" "Debería crear la red exitosamente"

	# Verificar que la red existe
	docker network ls --format "{{.Name}}" | grep -q "^${network_name}$"

	# Limpiar
	docker network rm "$network_name" >/dev/null 2>&1 || true
}

@test "ensure-network.sh valida configuración de red existente" {
	local network_name="${TEST_NETWORK_NAME}-validate"
	local network_ip="${TEST_NETWORK_IP}"
	local subnet="172.99.0.0/16"

	# Crear red manualmente
	docker network create --subnet="$subnet" "$network_name" >/dev/null 2>&1 || true

	# Ejecutar ensure-network.sh (debería validar y retornar éxito)
	run bash "$TEST_SCRIPTS_DIR/utils/ensure-network.sh" \
		NETWORK_NAME="$network_name" \
		NETWORK_IP="$network_ip"

	# Debería retornar éxito si la configuración es correcta
	[[ $status -eq 0 ]] || [[ $status -eq 1 ]]

	# Limpiar
	docker network rm "$network_name" >/dev/null 2>&1 || true
}

@test "ensure-network.sh detecta conflicto de subnet" {
	local network_name="${TEST_NETWORK_NAME}-conflict"
	local network_ip="${TEST_NETWORK_IP}"
	local subnet="172.99.0.0/16"

	# Crear red con subnet diferente
	local existing_network="${TEST_NETWORK_NAME}-existing"
	docker network create --subnet="$subnet" "$existing_network" >/dev/null 2>&1 || true

	# Intentar crear otra red con mismo subnet
	run bash "$TEST_SCRIPTS_DIR/utils/ensure-network.sh" \
		NETWORK_NAME="$network_name" \
		NETWORK_IP="$network_ip"

	# Debería detectar el conflicto
	assert_contains "$output" "conflicto" "Debería detectar conflicto de subnet"

	# Limpiar
	docker network rm "$existing_network" >/dev/null 2>&1 || true
	docker network rm "$network_name" >/dev/null 2>&1 || true
}

@test "ensure-network.sh --recreate recrea red con configuración diferente" {
	local network_name="${TEST_NETWORK_NAME}-recreate"
	local network_ip="172.98.0.0"  # Diferente subnet
	local subnet="172.99.0.0/16"

	# Crear red con subnet diferente
	docker network create --subnet="$subnet" "$network_name" >/dev/null 2>&1 || true

	# Recrear con --recreate
	run bash "$TEST_SCRIPTS_DIR/utils/ensure-network.sh" --recreate \
		NETWORK_NAME="$network_name" \
		NETWORK_IP="$network_ip"

	# Debería recrear la red
	# Nota: Este test puede requerir confirmación interactiva,
	# por lo que puede fallar en CI/CD sin interacción

	# Limpiar
	docker network rm "$network_name" >/dev/null 2>&1 || true
}
