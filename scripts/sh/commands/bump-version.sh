#!/usr/bin/env bash
# ============================================================================
# Script: bump-version.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Incrementa la versión semántica de la infraestructura (major, minor, patch)
# en .version, .env, README.md y crea tag de Git automáticamente.
#
# Uso:
#   make bump-version PART=patch
#   ./scripts/sh/commands/bump-version.sh <part> [--no-tag] [--no-commit]
#
# Parámetros:
#   $1 - Parte a incrementar: major, minor, patch
#   $2 - Opciones: --no-tag (no crear tag), --no-commit (no hacer commit)
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (donde está .version y .env).
#                  Make pasa $(CURDIR).
#   VERSION_FILE - Ruta al archivo .version (opcional, default: .version)
#   SKIP_GIT_TAG - Si está definido, no crea tag de Git
#   SKIP_GIT_COMMIT - Si está definido, no hace commit automático
#
# Retorno:
#   0 si la versión se actualizó correctamente
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

# ---------------------------------------------------------
# Valida que una versión sigue el formato semver (X.Y.Z)
# ---------------------------------------------------------
validate_semver() {
	local version="$1"
	if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		return 1
	fi
	return 0
}

# ---------------------------------------------------------
# Actualiza versión en README.md
# ---------------------------------------------------------
update_readme_version() {
	local old_version="$1"
	local new_version="$2"
	local readme_file="$PROJECT_ROOT/README.md"

	if [[ ! -f "$readme_file" ]]; then
		log_warn "README.md no encontrado, saltando actualización"
		return 0
	fi

	# Actualizar badge de versión
	if grep -q "badge/version" "$readme_file" 2>/dev/null; then
		sed -i "s|badge/version-${old_version}|badge/version-${new_version}|g" \
			"$readme_file"
		sed -i "s|version-${old_version}-blue|version-${new_version}-blue|g" \
			"$readme_file"
	fi

	# Actualizar versión al final del README
	if grep -q "^\*\*Versión\*\*:" "$readme_file" 2>/dev/null; then
		sed -i "s|^\*\*Versión\*\*: ${old_version}|\*\*Versión\*\*: ${new_version}|g" \
			"$readme_file"
	fi

	log_success "README.md actualizado: $old_version → $new_version"
}

# ---------------------------------------------------------
# Crea tag de Git
# ---------------------------------------------------------
create_git_tag() {
	local version="$1"
	local tag_name="v${version}"

	# Verificar que estamos en un repositorio Git
	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		log_warn "No es un repositorio Git, saltando creación de tag"
		return 0
	fi

	# Verificar que no hay cambios sin commitear (opcional, solo warning)
	if ! git diff-index --quiet HEAD -- 2>/dev/null; then
		log_warn "Hay cambios sin commitear. Considera hacer commit primero."
	fi

	# Verificar si el tag ya existe
	if git rev-parse "$tag_name" >/dev/null 2>&1; then
		log_error "El tag $tag_name ya existe"
		return 1
	fi

	# Crear tag
	if git tag -a "$tag_name" -m "Release version $version" 2>/dev/null; then
		log_success "Tag de Git creado: $tag_name"
		log_info "Para publicar el tag: git push origin $tag_name"
		return 0
	else
		log_error "No se pudo crear el tag $tag_name"
		return 1
	fi
}

# ---------------------------------------------------------
# Hace commit de los cambios de versión
# ---------------------------------------------------------
commit_version_changes() {
	local new_version="$1"

	# Verificar que estamos en un repositorio Git
	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		log_warn "No es un repositorio Git, saltando commit"
		return 0
	fi

	# Verificar si hay cambios para commitear
	if git diff --quiet && git diff --cached --quiet 2>/dev/null; then
		log_info "No hay cambios para commitear"
		return 0
	fi

	# Hacer commit
	if git add .version .env README.md CHANGELOG.md 2>/dev/null && \
		git commit -m "chore: bump version to $new_version" 2>/dev/null; then
		log_success "Cambios commiteados: version $new_version"
		return 0
	else
		log_warn "No se pudo hacer commit automático"
		log_info "Haz commit manualmente: git add .version .env README.md CHANGELOG.md"
		return 0
	fi
}

# ---------------------------------------------------------
# Punto de entrada
# ---------------------------------------------------------
PART="${1:-}"
SKIP_TAG=false
SKIP_COMMIT=false

# Procesar opciones
shift 2>/dev/null || true
while [[ $# -gt 0 ]]; do
	case "$1" in
		--no-tag)
			SKIP_TAG=true
			shift
			;;
		--no-commit)
			SKIP_COMMIT=true
			shift
			;;
		*)
			log_warn "Opción desconocida: $1"
			shift
			;;
	esac
done

# También verificar variables de entorno
if [[ -n "${SKIP_GIT_TAG:-}" ]]; then
	SKIP_TAG=true
fi
if [[ -n "${SKIP_GIT_COMMIT:-}" ]]; then
	SKIP_COMMIT=true
fi

VERSION_FILE="${VERSION_FILE:-$PROJECT_ROOT/.version}"
readonly ENV_FILE="$PROJECT_ROOT/.env"

# Validar parámetro PART
if [[ -z "$PART" ]]; then
	log_error "Debes especificar PART (major, minor, patch)"
	log_info "Uso: $0 <part> [--no-tag] [--no-commit]"
	log_info "Ejemplo: $0 patch"
	exit 1
fi

# Leer versión actual
CURRENT=$(cat "$VERSION_FILE" 2>/dev/null || echo "1.0.0")

# Validar que la versión actual sigue semver
if ! validate_semver "$CURRENT"; then
	log_error "Versión actual no sigue formato semver: $CURRENT"
	log_info "El formato debe ser: X.Y.Z (ejemplo: 2.3.0)"
	exit 1
fi

# Extraer componentes
MAJOR=$(echo "$CURRENT" | cut -d'.' -f1)
MINOR=$(echo "$CURRENT" | cut -d'.' -f2)
PATCH=$(echo "$CURRENT" | cut -d'.' -f3)

# Calcular nueva versión
case "$PART" in
	major)
		NEW_VERSION=$((MAJOR + 1)).0.0
		;;
	minor)
		NEW_VERSION=$MAJOR.$((MINOR + 1)).0
		;;
	patch)
		NEW_VERSION=$MAJOR.$MINOR.$((PATCH + 1))
		;;
	*)
		log_error "PART debe ser major, minor o patch"
		exit 1
		;;
esac

# Validar que la nueva versión sigue semver
if ! validate_semver "$NEW_VERSION"; then
	log_error "Nueva versión calculada no sigue formato semver: $NEW_VERSION"
	exit 1
fi

log_step "Actualizando versión: $CURRENT → $NEW_VERSION"

# 1. Actualizar .version
echo "$NEW_VERSION" > "$VERSION_FILE"
log_success ".version actualizado: $NEW_VERSION"

# 2. Actualizar .env
if [[ -f "$ENV_FILE" ]]; then
	if grep -q "^INFRASTRUCTURE_VERSION=" "$ENV_FILE" 2>/dev/null; then
		sed -i "s|^INFRASTRUCTURE_VERSION=.*|INFRASTRUCTURE_VERSION=$NEW_VERSION|" \
			"$ENV_FILE"
	else
		echo "INFRASTRUCTURE_VERSION=$NEW_VERSION" >> "$ENV_FILE"
	fi
	log_success ".env actualizado: INFRASTRUCTURE_VERSION=$NEW_VERSION"
fi

# 3. Actualizar README.md
update_readme_version "$CURRENT" "$NEW_VERSION"

# 4. Actualizar CHANGELOG.md
UPDATE_CHANGELOG_SCRIPT="$PROJECT_ROOT/scripts/sh/utils/update-changelog.sh"
if [[ -f "$UPDATE_CHANGELOG_SCRIPT" ]]; then
	log_info "Actualizando CHANGELOG.md..."
	if bash "$UPDATE_CHANGELOG_SCRIPT" "$NEW_VERSION" 2>/dev/null; then
		log_success "CHANGELOG.md actualizado"
	else
		log_warn "No se pudo actualizar CHANGELOG.md automáticamente"
		log_info "Actualiza CHANGELOG.md manualmente con: bash $UPDATE_CHANGELOG_SCRIPT $NEW_VERSION"
	fi
fi

# 5. Hacer commit (si no se saltó)
if [[ "$SKIP_COMMIT" == "false" ]]; then
	commit_version_changes "$NEW_VERSION"
fi

# 6. Crear tag de Git (si no se saltó)
if [[ "$SKIP_TAG" == "false" ]]; then
	create_git_tag "$NEW_VERSION"
fi

log_success "Versión actualizada: $CURRENT → $NEW_VERSION"
log_info ""
log_info "Resumen de cambios:"
log_info "  - .version: $NEW_VERSION"
if [[ -f "$ENV_FILE" ]]; then
	log_info "  - .env: INFRASTRUCTURE_VERSION=$NEW_VERSION"
fi
log_info "  - README.md: actualizado"
log_info "  - CHANGELOG.md: actualizado"
if [[ "$SKIP_COMMIT" == "false" ]]; then
	log_info "  - Git commit: realizado"
fi
if [[ "$SKIP_TAG" == "false" ]]; then
	log_info "  - Git tag: v$NEW_VERSION"
fi
log_info ""
log_info "Próximos pasos:"
if [[ "$SKIP_TAG" == "false" ]]; then
	log_info "  - Revisa los cambios: git diff"
	log_info "  - Publica el tag: git push origin v$NEW_VERSION"
fi
log_info "  - Crea release en GitHub (opcional)"

exit 0
