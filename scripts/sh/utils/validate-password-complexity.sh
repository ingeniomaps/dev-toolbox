#!/usr/bin/env bash
# ============================================================================
# Script: validate-password-complexity.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Verifica que una contraseña cumpla con requisitos de seguridad:
# - Longitud mínima (12 caracteres)
# - Al menos una mayúscula
# - Al menos una minúscula
# - Al menos un número
# - Al menos un carácter especial
# - No contiene patrones débiles comunes
#
# Uso:
#   ./scripts/sh/utils/validate-password-complexity.sh <contraseña>
#
# Parámetros:
#   $1 - Contraseña a validar (requerido)
#
# Retorno:
#   0 si la contraseña es válida
#   1 si la contraseña no cumple los requisitos
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Determinar directorio del script
_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_script_dir"
unset _script_dir

# Cargar sistema de logging (opcional, ya que puede usarse silenciosamente)
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"
if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/logging.sh"
fi

readonly PASSWORD="${1:-}"

if [[ -z "$PASSWORD" ]]; then
	if command -v log_error >/dev/null 2>&1; then
		log_error "Debes proporcionar una contraseña"
	else
		echo "Error: Debes proporcionar una contraseña" >&2
	fi
	exit 1
fi

EXIT_CODE=0
readonly MIN_LENGTH=12

# Verificar longitud
if [[ ${#PASSWORD} -lt $MIN_LENGTH ]]; then
	if command -v log_error >/dev/null 2>&1; then
		log_error "La contraseña debe tener al menos $MIN_LENGTH caracteres"
	else
		echo "Error: La contraseña debe tener al menos $MIN_LENGTH caracteres" >&2
	fi
	EXIT_CODE=1
fi

# Verificar mayúsculas
if ! [[ "$PASSWORD" =~ [A-Z] ]]; then
	if command -v log_error >/dev/null 2>&1; then
		log_error "La contraseña debe contener al menos una letra mayúscula"
	else
		echo "Error: La contraseña debe contener al menos una letra mayúscula" >&2
	fi
	EXIT_CODE=1
fi

# Verificar minúsculas
if ! [[ "$PASSWORD" =~ [a-z] ]]; then
	if command -v log_error >/dev/null 2>&1; then
		log_error "La contraseña debe contener al menos una letra minúscula"
	else
		echo "Error: La contraseña debe contener al menos una letra minúscula" >&2
	fi
	EXIT_CODE=1
fi

# Verificar números
if ! [[ "$PASSWORD" =~ [0-9] ]]; then
	if command -v log_error >/dev/null 2>&1; then
		log_error "La contraseña debe contener al menos un número"
	else
		echo "Error: La contraseña debe contener al menos un número" >&2
	fi
	EXIT_CODE=1
fi

# Verificar caracteres especiales
if ! [[ "$PASSWORD" =~ [^A-Za-z0-9] ]]; then
	if command -v log_error >/dev/null 2>&1; then
		log_error "La contraseña debe contener al menos un carácter especial"
	else
		echo "Error: La contraseña debe contener al menos un carácter especial" >&2
	fi
	EXIT_CODE=1
fi

# Verificar contraseñas comunes débiles
#
# Algoritmo:
#   1. Convierte la contraseña a minúsculas para comparación case-insensitive
#   2. Verifica si contiene alguna de las contraseñas débiles comunes
#   3. Usa coincidencia de subcadena (*"$common"*) para detectar variaciones
#      Ejemplo: "MyPassword123" contiene "password" -> rechazada
#
# Lista consolidada de contraseñas débiles comunes
# Nota: Esta lista incluye las contraseñas más comunes según estudios de seguridad
readonly COMMON_PASSWORDS=(
	"password"
	"12345678"
	"123456"
	"qwerty"
	"admin"
	"root"
	"letmein"
	"admin123"
	"admin12345"
	"welcome"
)

# Convertir a minúsculas para comparación case-insensitive
# Ejemplo: "MyPassword123" -> "mypassword123"
LOWER_PASSWORD=$(echo "$PASSWORD" | tr '[:upper:]' '[:lower:]')

# Verificar si contiene alguna contraseña débil
for common in "${COMMON_PASSWORDS[@]}"; do
	# Usar coincidencia de subcadena para detectar variaciones
	# Ejemplo: "MyPassword123" contiene "password" -> rechazada
	if [[ "$LOWER_PASSWORD" == *"$common"* ]]; then
		if command -v log_error >/dev/null 2>&1; then
			log_error "La contraseña contiene patrones débiles comunes: $common"
		else
			echo "Error: La contraseña contiene patrones débiles comunes: $common" >&2
		fi
		EXIT_CODE=1
		break
	fi
done

if [[ $EXIT_CODE -eq 0 ]]; then
	if command -v log_success >/dev/null 2>&1; then
		log_success "La contraseña cumple con los requisitos de complejidad"
	fi
	exit 0
else
	exit 1
fi
