#!/usr/bin/env bash
# ============================================================================
# Script: generate-password.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Genera contraseñas criptográficamente seguras con diferentes métodos
# según disponibilidad (openssl, pwgen, o /dev/urandom).
#
# Uso:
#   ./scripts/sh/utils/generate-password.sh [longitud]
#
# Parámetros:
#   $1 - Longitud de la contraseña (opcional, default: 24, mínimo: 12)
#
# Retorno:
#   Imprime la contraseña generada en stdout (una línea)
#   0 si la generación fue exitosa
#   1 si hay error (longitud inválida, etc.)
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

readonly LENGTH="${1:-24}"

# Verificar que la longitud sea válida
if ! [[ "$LENGTH" =~ ^[0-9]+$ ]] || [[ "$LENGTH" -lt 12 ]]; then
	echo "Error: La longitud debe ser un número >= 12" >&2
	exit 1
fi

# Generar contraseña segura usando diferentes métodos según disponibilidad
# Prioridad: openssl > pwgen > /dev/urandom
#
# Algoritmo de selección:
#   1. Intenta usar openssl (método preferido: rápido y portable)
#      - Genera 48 bytes en base64 (más de los necesarios)
#      - Elimina caracteres problemáticos (=, +, /) que pueden causar problemas en URLs
#      - Toma solo los primeros LENGTH caracteres
#      - Si falla, usa fallback con /dev/urandom
#
#   2. Si openssl no está disponible, intenta pwgen
#      - Genera contraseña segura directamente con la longitud especificada
#      - Opción -s: usa caracteres seguros (sin ambigüedad)
#
#   3. Si ninguno está disponible, usa /dev/urandom directamente
#      - Lee bytes aleatorios del sistema
#      - Filtra solo caracteres imprimibles seguros
#      - Toma exactamente LENGTH caracteres
#
# Ejemplo de salida:
#   generate-password.sh 16 -> "Kx9#mP2$vL8@nQ4!"
#   generate-password.sh 24 -> "aB3$cD5&eF7*gH9!jK1@mL3#nO5"

if command -v openssl >/dev/null 2>&1; then
	# Usar openssl (método preferido: más rápido y portable)
	# Genera base64, elimina caracteres problemáticos, toma longitud
	openssl rand -base64 48 | tr -d "=+/" | cut -c1-"${LENGTH}" || {
		# Fallback si falla
		tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' < /dev/urandom | \
			head -c "${LENGTH}" || exit 1
	}
	echo ""

elif command -v pwgen >/dev/null 2>&1; then
	# Usar pwgen si está disponible (genera contraseñas seguras)
	# Opción -s: caracteres seguros (sin ambigüedad como 0/O, 1/l/I)
	pwgen -s "${LENGTH}" 1 || exit 1

else
	# Fallback: usar /dev/urandom directamente
	# Incluye: mayúsculas, minúsculas, números y caracteres especiales
	tr -dc 'A-Za-z0-9!@#$%^&*()_+-=[]{}|;:,.<>?' < /dev/urandom | \
		head -c "${LENGTH}" || \
		tr -dc 'A-Za-z0-9!@#$%^&*()_+-=[]{}|;:,.<>?' < /dev/urandom | \
		head -c "${LENGTH}" || exit 1
	echo ""
fi
