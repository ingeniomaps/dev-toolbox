#!/usr/bin/env bash
# ============================================================================
# Script: keychain.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Helper para gestionar secretos usando keychain/secrets manager del OS.
# Soporta múltiples backends: secret-tool (Linux), security (macOS), pass (opcional).
#
# Funciones disponibles:
#   keychain_get <service> <key>         - Obtiene un secreto
#   keychain_set <service> <key> <value> - Guarda un secreto
#   keychain_delete <service> <key>      - Elimina un secreto
#   keychain_list <service>              - Lista secretos de un servicio
#
# Variables de entorno:
#   KEYCHAIN_BACKEND - Backend a usar: secret-tool (default en Linux),
#                      security (default en macOS), pass
#   KEYCHAIN_SERVICE - Nombre del servicio (default: dev-toolbox)
#
# Retorno:
#   0 si la operación fue exitosa
#   1 si hay errores o el backend no está disponible
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Detectar OS y backend por defecto
detect_backend() {
	local os_type
	os_type=$(uname -s 2>/dev/null || echo "Linux")

	case "$os_type" in
		Darwin)
			if command -v security >/dev/null 2>&1; then
				echo "security"
				return 0
			fi
			;;
		Linux)
			if command -v secret-tool >/dev/null 2>&1; then
				echo "secret-tool"
				return 0
			fi
			;;
	esac

	# Fallback: verificar si pass está disponible
	if command -v pass >/dev/null 2>&1; then
		echo "pass"
		return 0
	fi

	echo "none"
	return 1
}

# Backend por defecto
readonly DEFAULT_BACKEND="${KEYCHAIN_BACKEND:-$(detect_backend)}"
readonly KEYCHAIN_SERVICE="${KEYCHAIN_SERVICE:-dev-toolbox}"

# ============================================================================
# Backend: secret-tool (Linux)
# ============================================================================

_keychain_get_secret_tool() {
	local service="$1"
	local key="$2"

	if ! command -v secret-tool >/dev/null 2>&1; then
		return 1
	fi

	secret-tool lookup service "$service" account "$key" 2>/dev/null || return 1
}

_keychain_set_secret_tool() {
	local service="$1"
	local key="$2"
	local value="$3"

	if ! command -v secret-tool >/dev/null 2>&1; then
		return 1
	fi

	echo -n "$value" | secret-tool store \
		--label="dev-toolbox: $service/$key" \
		service "$service" \
		account "$key" 2>/dev/null || return 1
}

_keychain_delete_secret_tool() {
	local service="$1"
	local key="$2"

	if ! command -v secret-tool >/dev/null 2>&1; then
		return 1
	fi

	secret-tool clear service "$service" account "$key" 2>/dev/null || return 1
}

_keychain_list_secret_tool() {
	local service="$1"

	if ! command -v secret-tool >/dev/null 2>&1; then
		return 1
	fi

	# secret-tool no tiene listado nativo, usar búsqueda
	secret-tool search service "$service" 2>/dev/null | \
		grep -oP 'account = \K.*' 2>/dev/null || echo ""
}

# ============================================================================
# Backend: security (macOS Keychain)
# ============================================================================

_keychain_get_security() {
	local service="$1"
	local key="$2"
	local account="${service}-${key}"

	if ! command -v security >/dev/null 2>&1; then
		return 1
	fi

	security find-generic-password \
		-s "$service" \
		-a "$account" \
		-w 2>/dev/null || return 1
}

_keychain_set_security() {
	local service="$1"
	local key="$2"
	local value="$3"
	local account="${service}-${key}"

	if ! command -v security >/dev/null 2>&1; then
		return 1
	fi

	# Eliminar si existe
	security delete-generic-password \
		-s "$service" \
		-a "$account" \
		2>/dev/null || true

	# Agregar nuevo
	echo -n "$value" | security add-generic-password \
		-s "$service" \
		-a "$account" \
		-w - \
		-U 2>/dev/null || return 1
}

_keychain_delete_security() {
	local service="$1"
	local key="$2"
	local account="${service}-${key}"

	if ! command -v security >/dev/null 2>&1; then
		return 1
	fi

	security delete-generic-password \
		-s "$service" \
		-a "$account" \
		2>/dev/null || return 1
}

_keychain_list_security() {
	local service="$1"

	if ! command -v security >/dev/null 2>&1; then
		return 1
	fi

	security dump-keychain 2>/dev/null | \
		grep -A 2 "svce=\"$service\"" | \
		grep "acct=" | \
		sed 's/.*acct="\([^"]*\)".*/\1/' | \
		sed "s/^${service}-//" || echo ""
}

# ============================================================================
# Backend: pass (password store)
# ============================================================================

_keychain_get_pass() {
	local service="$1"
	local key="$2"

	if ! command -v pass >/dev/null 2>&1; then
		return 1
	fi

	pass show "${service}/${key}" 2>/dev/null | head -n 1 || return 1
}

_keychain_set_pass() {
	local service="$1"
	local key="$2"
	local value="$3"

	if ! command -v pass >/dev/null 2>&1; then
		return 1
	fi

	echo -n "$value" | pass insert -f "${service}/${key}" 2>/dev/null || return 1
}

_keychain_delete_pass() {
	local service="$1"
	local key="$2"

	if ! command -v pass >/dev/null 2>&1; then
		return 1
	fi

	pass rm -f "${service}/${key}" 2>/dev/null || return 1
}

_keychain_list_pass() {
	local service="$1"

	if ! command -v pass >/dev/null 2>&1; then
		return 1
	fi

	pass ls "${service}" 2>/dev/null | \
		sed "s/^.*${service}\///" | \
		sed 's/^[[:space:]]*//' || echo ""
}

# ============================================================================
# Funciones públicas
# ============================================================================

# Obtiene un secreto del keychain
keychain_get() {
	local service="${1:-$KEYCHAIN_SERVICE}"
	local key="${2:-}"

	if [[ -z "$key" ]]; then
		echo "Error: Se requiere un key" >&2
		return 1
	fi

	case "$DEFAULT_BACKEND" in
		secret-tool)
			_keychain_get_secret_tool "$service" "$key"
			;;
		security)
			_keychain_get_security "$service" "$key"
			;;
		pass)
			_keychain_get_pass "$service" "$key"
			;;
		*)
			echo "Error: Backend no disponible o no soportado: $DEFAULT_BACKEND" >&2
			return 1
			;;
	esac
}

# Guarda un secreto en el keychain
keychain_set() {
	local service="${1:-$KEYCHAIN_SERVICE}"
	local key="${2:-}"
	local value="${3:-}"

	if [[ -z "$key" ]] || [[ -z "$value" ]]; then
		echo "Error: Se requieren key y value" >&2
		return 1
	fi

	case "$DEFAULT_BACKEND" in
		secret-tool)
			_keychain_set_secret_tool "$service" "$key" "$value"
			;;
		security)
			_keychain_set_security "$service" "$key" "$value"
			;;
		pass)
			_keychain_set_pass "$service" "$key" "$value"
			;;
		*)
			echo "Error: Backend no disponible o no soportado: $DEFAULT_BACKEND" >&2
			return 1
			;;
	esac
}

# Elimina un secreto del keychain
keychain_delete() {
	local service="${1:-$KEYCHAIN_SERVICE}"
	local key="${2:-}"

	if [[ -z "$key" ]]; then
		echo "Error: Se requiere un key" >&2
		return 1
	fi

	case "$DEFAULT_BACKEND" in
		secret-tool)
			_keychain_delete_secret_tool "$service" "$key"
			;;
		security)
			_keychain_delete_security "$service" "$key"
			;;
		pass)
			_keychain_delete_pass "$service" "$key"
			;;
		*)
			echo "Error: Backend no disponible o no soportado: $DEFAULT_BACKEND" >&2
			return 1
			;;
	esac
}

# Lista secretos de un servicio
keychain_list() {
	local service="${1:-$KEYCHAIN_SERVICE}"

	case "$DEFAULT_BACKEND" in
		secret-tool)
			_keychain_list_secret_tool "$service"
			;;
		security)
			_keychain_list_security "$service"
			;;
		pass)
			_keychain_list_pass "$service"
			;;
		*)
			echo "Error: Backend no disponible o no soportado: $DEFAULT_BACKEND" >&2
			return 1
			;;
	esac
}

# Verifica si el keychain está disponible
keychain_available() {
	case "$DEFAULT_BACKEND" in
		none)
			return 1
			;;
		secret-tool)
			command -v secret-tool >/dev/null 2>&1
			;;
		security)
			command -v security >/dev/null 2>&1
			;;
		pass)
			command -v pass >/dev/null 2>&1
			;;
		*)
			return 1
			;;
	esac
}

# Obtiene el backend actual
keychain_backend() {
	echo "$DEFAULT_BACKEND"
}
