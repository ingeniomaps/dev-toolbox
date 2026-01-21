#!/usr/bin/env bash
# ============================================================================
# Script: update-changelog.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Actualiza el CHANGELOG.md con una nueva versión.
# Inserta una nueva sección [Unreleased] y mueve el contenido de [Unreleased]
# a la nueva versión.
#
# Uso:
#   ./scripts/sh/utils/update-changelog.sh <version> [fecha]
#   ./scripts/sh/utils/update-changelog.sh 2.4.0
#   ./scripts/sh/utils/update-changelog.sh 2.4.0 2025-01-28
#
# Parámetros:
#   $1 - Nueva versión (formato: X.Y.Z)
#   $2 - Fecha de release (opcional, default: fecha actual YYYY-MM-DD)
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto
#   CHANGELOG_FILE - Ruta al CHANGELOG.md (default: CHANGELOG.md)
#
# Retorno:
#   0 si la actualización fue exitosa
#   1 si hay errores
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_script_dir"
unset _script_dir
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"
_pr="${PROJECT_ROOT:-$(pwd)}"
readonly PROJECT_ROOT="${_pr%/}"
unset _pr

if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/logging.sh"
else
	log_info() { echo "[INFO] $*"; }
	log_warn() { echo "[WARN] $*" >&2; }
	log_error() { echo "[ERROR] $*" >&2; }
	log_success() { echo "[SUCCESS] $*"; }
	[[ -f "$COMMON_SCRIPTS_DIR/colors.sh" ]] && source "$COMMON_SCRIPTS_DIR/colors.sh"
fi

VERSION="${1:-}"
RELEASE_DATE="${2:-$(date +%Y-%m-%d)}"
CHANGELOG_FILE="${CHANGELOG_FILE:-$PROJECT_ROOT/CHANGELOG.md}"

# Validar versión
if [[ -z "$VERSION" ]]; then
	log_error "Debes especificar una versión"
	log_info "Uso: $0 <version> [fecha]"
	log_info "Ejemplo: $0 2.4.0"
	exit 1
fi

# Validar formato de versión (semver)
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	log_error "Versión inválida. Debe seguir formato semver: X.Y.Z"
	log_info "Ejemplo: 2.4.0"
	exit 1
fi

# Validar formato de fecha
if [[ ! "$RELEASE_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
	log_error "Fecha inválida. Debe seguir formato: YYYY-MM-DD"
	log_info "Ejemplo: 2025-01-28"
	exit 1
fi

# Verificar que CHANGELOG.md existe
if [[ ! -f "$CHANGELOG_FILE" ]]; then
	log_error "CHANGELOG.md no encontrado en: $CHANGELOG_FILE"
	exit 1
fi

# Crear backup
BACKUP_FILE="${CHANGELOG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
cp "$CHANGELOG_FILE" "$BACKUP_FILE"
log_info "Backup creado: $BACKUP_FILE"

# Leer contenido actual
CHANGELOG_CONTENT=$(cat "$CHANGELOG_FILE")

# Extraer sección [Unreleased]
if echo "$CHANGELOG_CONTENT" | grep -q "^## \[Unreleased\]"; then
	# Extraer contenido de [Unreleased] hasta el siguiente ##
	UNRELEASED_SECTION=$(echo "$CHANGELOG_CONTENT" | \
		awk '/^## \[Unreleased\]/,/^## \[/ {if (!/^## \[Unreleased\]/ && !/^## \[[0-9]/) print}')

	# Si está vacío, usar placeholder
	if [[ -z "$UNRELEASED_SECTION" ]] || \
		[[ "$UNRELEASED_SECTION" =~ ^[[:space:]]*$ ]]; then
		UNRELEASED_SECTION="### Added
- Sin cambios significativos en esta versión

"
	fi
else
	log_warn "No se encontró sección [Unreleased], creando placeholder"
	UNRELEASED_SECTION="### Added
- Sin cambios significativos en esta versión

"
fi

# Crear nueva sección de versión
NEW_VERSION_SECTION="## [$VERSION] - $RELEASE_DATE

$UNRELEASED_SECTION
---"

# Reemplazar [Unreleased] con nueva versión y agregar nuevo [Unreleased]
NEW_CHANGELOG=$(echo "$CHANGELOG_CONTENT" | \
	sed "/^## \[Unreleased\]/,/^---/c\\
## [Unreleased]\\
\\
### Added\\
- Nuevas funcionalidades que aún no han sido liberadas\\
\\
### Changed\\
- Cambios en funcionalidades existentes\\
\\
### Deprecated\\
- Funcionalidades que serán eliminadas en futuras versiones\\
\\
### Removed\\
- Funcionalidades eliminadas\\
\\
### Fixed\\
- Correcciones de bugs\\
\\
### Security\\
- Mejoras de seguridad\\
\\
---\\
\\
$NEW_VERSION_SECTION")

# Escribir nuevo contenido
echo "$NEW_CHANGELOG" > "$CHANGELOG_FILE"

log_success "CHANGELOG.md actualizado: versión $VERSION ($RELEASE_DATE)"
log_info "Revisa el contenido y ajusta si es necesario"
log_info "Backup disponible en: $BACKUP_FILE"

exit 0
