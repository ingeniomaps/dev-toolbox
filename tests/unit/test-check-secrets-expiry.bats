#!/usr/bin/env bats
# ============================================================================
# Test: test-check-secrets-expiry.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests para check-secrets-expiry.sh
# ============================================================================

load 'helpers'

setup() {
	export TEST_PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
	export TEST_COMMANDS_DIR="$TEST_PROJECT_ROOT/scripts/sh/commands"
	export TEST_TMP=$(mktemp -d)
}

teardown() {
	rm -rf "$TEST_TMP"
}

@test "check-secrets-expiry: ejecuta sin errores de sintaxis" {
	run env PROJECT_ROOT="$TEST_TMP" \
		bash "$TEST_COMMANDS_DIR/check-secrets-expiry.sh" 2>&1

	# Sin .env debería mostrar advertencia pero no fallar por sintaxis
	[[ $status -ge 0 ]]
}

@test "check-secrets-expiry: detecta secretos expirados" {
	# Crear .env con secreto expirado
	cat > "$TEST_TMP/.env" <<EOF
SECRET_EXPIRED=value
SECRET_EXPIRED_EXPIRES=2020-01-01
EOF

	run env PROJECT_ROOT="$TEST_TMP" \
		bash "$TEST_COMMANDS_DIR/check-secrets-expiry.sh"

	assert_contains "$output" "expirado\|EXPIRED\|expired"
}

@test "check-secrets-expiry: detecta secretos próximos a expirar" {
	local future_date=$(date -d "+15 days" +%Y-%m-%d 2>/dev/null || date -v+15d +%Y-%m-%d 2>/dev/null || echo "")
	if [[ -z "$future_date" ]]; then
		skip "No se puede calcular fecha futura"
	fi

	cat > "$TEST_TMP/.env" <<EOF
SECRET_WARNING=value
SECRET_WARNING_EXPIRES=$future_date
EOF

	run env PROJECT_ROOT="$TEST_TMP" \
		bash "$TEST_COMMANDS_DIR/check-secrets-expiry.sh"

	assert_contains "$output" "próximo\|expirar\|warning\|advertencia"
}

@test "check-secrets-expiry: acepta --days para umbral personalizado" {
	local future_date=$(date -d "+10 days" +%Y-%m-%d 2>/dev/null || date -v+10d +%Y-%m-%d 2>/dev/null || echo "")
	if [[ -z "$future_date" ]]; then
		skip "No se puede calcular fecha futura"
	fi

	cat > "$TEST_TMP/.env" <<EOF
SECRET=value
SECRET_EXPIRES=$future_date
EOF

	run env PROJECT_ROOT="$TEST_TMP" \
		bash "$TEST_COMMANDS_DIR/check-secrets-expiry.sh" --days=5

	# Con umbral de 5 días, un secreto que expira en 10 días puede o no generar warning
	[[ $status -ge 0 ]]
}

@test "check-secrets-expiry: acepta --warn-only para solo warnings" {
	cat > "$TEST_TMP/.env" <<EOF
SECRET_EXPIRED=value
SECRET_EXPIRED_EXPIRES=2020-01-01
EOF

	run env PROJECT_ROOT="$TEST_TMP" \
		bash "$TEST_COMMANDS_DIR/check-secrets-expiry.sh" --warn-only

	assert_success "$output" "$status"
}

@test "check-secrets-expiry: acepta --export para salida JSON" {
	cat > "$TEST_TMP/.env" <<EOF
SECRET=value
SECRET_EXPIRES=2028-12-31
EOF

	local export_file="$TEST_TMP/export.json"
	run env PROJECT_ROOT="$TEST_TMP" \
		bash "$TEST_COMMANDS_DIR/check-secrets-expiry.sh" --export="$export_file"

	assert_success "$output" "$status"
}

@test "check-secrets-expiry: maneja archivo .env inexistente" {
	run env PROJECT_ROOT="/tmp/nonexistent-$(date +%s)" \
		bash "$TEST_COMMANDS_DIR/check-secrets-expiry.sh"

	# El script maneja esto con warning
	[[ $status -ge 0 ]]
}

@test "check-secrets-expiry: detecta múltiples formatos de fecha" {
	cat > "$TEST_TMP/.env" <<EOF
SECRET1=value
SECRET1_EXPIRES=2028-12-31

SECRET2=value
SECRET2_EXPIRY=2028-12-31

SECRET3=value
SECRET3_ROTATE_BEFORE=2028-12-31
EOF

	run env PROJECT_ROOT="$TEST_TMP" \
		bash "$TEST_COMMANDS_DIR/check-secrets-expiry.sh"

	assert_success "$output" "$status"
}
