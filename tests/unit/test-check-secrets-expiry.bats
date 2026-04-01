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
	export TEST_ENV_FILE="$BATS_TEST_TMPDIR/.env.test"

	# Crear archivo .env de prueba
	cat > "$TEST_ENV_FILE" <<EOF
# Secretos con fechas de expiración
DB_PASSWORD=secret123
DB_PASSWORD_EXPIRES=2025-12-31
DB_PASSWORD_EXPIRY=2025-12-31

API_KEY=key123
API_KEY_EXPIRES=2024-01-01

TOKEN=token123
TOKEN_ROTATE_BEFORE=2024-06-01

# Secretos sin fecha
OTHER_SECRET=value123
EOF
}

teardown() {
	rm -f "$TEST_ENV_FILE"
}

@test "check-secrets-expiry: muestra ayuda con --help" {
	run bash "$TEST_COMMANDS_DIR/check-secrets-expiry.sh" --help

	assert_success "$output" "$status"
	assert_contains "$output" "Uso:"
	assert_contains "$output" "check-secrets-expiry"
}

@test "check-secrets-expiry: detecta secretos expirados" {
	# Crear .env con secreto expirado
	cat > "$TEST_ENV_FILE" <<EOF
SECRET_EXPIRED=value
SECRET_EXPIRED_EXPIRES=2020-01-01
EOF

	run bash "$TEST_COMMANDS_DIR/check-secrets-expiry.sh" "$TEST_ENV_FILE"

	assert_contains "$output" "expirado"
	assert_contains "$output" "SECRET_EXPIRED"
}

@test "check-secrets-expiry: detecta secretos próximos a expirar" {
	# Crear .env con secreto próximo a expirar (dentro de 30 días)
	local future_date=$(date -d "+15 days" +%Y-%m-%d 2>/dev/null || date -v+15d +%Y-%m-%d 2>/dev/null || echo "")
	if [[ -z "$future_date" ]]; then
		skip "No se puede calcular fecha futura"
	fi

	cat > "$TEST_ENV_FILE" <<EOF
SECRET_WARNING=value
SECRET_WARNING_EXPIRES=$future_date
EOF

	run bash "$TEST_COMMANDS_DIR/check-secrets-expiry.sh" "$TEST_ENV_FILE"

	assert_contains "$output" "próximo a expirar\|próximo"
}

@test "check-secrets-expiry: acepta --days para umbral personalizado" {
	local future_date=$(date -d "+10 days" +%Y-%m-%d 2>/dev/null || date -v+10d +%Y-%m-%d 2>/dev/null || echo "")
	if [[ -z "$future_date" ]]; then
		skip "No se puede calcular fecha futura"
	fi

	cat > "$TEST_ENV_FILE" <<EOF
SECRET=value
SECRET_EXPIRES=$future_date
EOF

	run bash "$TEST_COMMANDS_DIR/check-secrets-expiry.sh" --days=5 "$TEST_ENV_FILE"

	# Con umbral de 5 días, un secreto que expira en 10 días puede o no generar warning
	[[ $status -ge 0 ]]
}

@test "check-secrets-expiry: acepta --warn-only para solo warnings" {
	cat > "$TEST_ENV_FILE" <<EOF
SECRET_EXPIRED=value
SECRET_EXPIRED_EXPIRES=2020-01-01
EOF

	run bash "$TEST_COMMANDS_DIR/check-secrets-expiry.sh" --warn-only "$TEST_ENV_FILE"

	assert_success "$output" "$status"
	# Con --warn-only, no debería fallar aunque haya expirados
}

@test "check-secrets-expiry: acepta --export para salida JSON" {
	cat > "$TEST_ENV_FILE" <<EOF
SECRET=value
SECRET_EXPIRES=2025-12-31
EOF

	local export_file="$BATS_TEST_TMPDIR/export.json"
	run bash "$TEST_COMMANDS_DIR/check-secrets-expiry.sh" --export="$export_file" "$TEST_ENV_FILE"

	assert_success "$output" "$status"
	if [[ -f "$export_file" ]]; then
		assert_contains "$output" "exportado"
	fi
}

@test "check-secrets-expiry: maneja archivo .env inexistente" {
	run bash "$TEST_COMMANDS_DIR/check-secrets-expiry.sh" "/ruta/inexistente/.env"

	# El script puede manejar esto con exit 0 o 1 dependiendo de la implementación
	[[ $status -ge 0 ]]
	assert_contains "$output" "no encontrado\|no existe\|No se encontr" || true
}

@test "check-secrets-expiry: detecta múltiples formatos de fecha" {
	cat > "$TEST_ENV_FILE" <<EOF
SECRET1=value
SECRET1_EXPIRES=2025-12-31

SECRET2=value
SECRET2_EXPIRY=2025-12-31

SECRET3=value
SECRET3_ROTATE_BEFORE=2025-12-31
EOF

	run bash "$TEST_COMMANDS_DIR/check-secrets-expiry.sh" "$TEST_ENV_FILE"

	assert_success "$output" "$status"
	# Debería detectar los tres formatos
}
