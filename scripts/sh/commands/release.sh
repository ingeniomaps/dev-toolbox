#!/usr/bin/env bash
# ============================================================================
# Script: release.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Proceso completo de release: ejecuta tests, actualiza versión, crea tag y
# genera release notes.
#
# Uso:
#   make release PART=patch
#   ./scripts/sh/commands/release.sh <part> [--dry-run] [--skip-tests]
#
# Parámetros:
#   $1 - Parte a incrementar: major, minor, patch
#   $2 - Opciones: --dry-run (simula sin hacer cambios), --skip-tests (salta tests)
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto
#   DRY_RUN - Si está definido, simula sin hacer cambios
#   SKIP_TESTS - Si está definido, salta ejecución de tests
#
# Retorno:
#   0 si el release fue exitoso
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
	log_step() { echo "[STEP] $*"; }
	[[ -f "$COMMON_SCRIPTS_DIR/colors.sh" ]] && source "$COMMON_SCRIPTS_DIR/colors.sh"
fi

# ---------------------------------------------------------
# Ejecuta todos los tests disponibles
# ---------------------------------------------------------
run_tests() {
	log_step "Ejecutando tests..."

	local tests_passed=0
	local tests_failed=0
	local test_dir="$PROJECT_ROOT/scripts/sh/tests"

	if [[ ! -d "$test_dir" ]]; then
		log_warn "Directorio de tests no encontrado: $test_dir"
		return 0
	fi

	# Ejecutar todos los tests
	for test_file in "$test_dir"/test-*.sh; do
		if [[ ! -f "$test_file" ]]; then
			continue
		fi

		_test_name=$(basename "$test_file")
		local test_name="$_test_name"
		unset _test_name
		log_info "Ejecutando: $test_name"

		if bash "$test_file" 2>&1; then
			((tests_passed++))
			log_success "✓ $test_name pasó"
		else
			((tests_failed++))
			log_error "✗ $test_name falló"
		fi
	done

	if [[ $tests_failed -gt 0 ]]; then
		log_error "$tests_failed test(s) fallaron"
		return 1
	fi

	if [[ $tests_passed -eq 0 ]]; then
		log_warn "No se encontraron tests para ejecutar"
		return 0
	fi

	log_success "Todos los tests pasaron ($tests_passed)"
	return 0
}

# ---------------------------------------------------------
# Genera release notes desde CHANGELOG.md
# ---------------------------------------------------------
generate_release_notes() {
	local version="$1"
	local changelog_file="$PROJECT_ROOT/CHANGELOG.md"
	local output_file="${2:-$PROJECT_ROOT/RELEASE_NOTES_${version}.md}"

	if [[ ! -f "$changelog_file" ]]; then
		log_warn "CHANGELOG.md no encontrado, no se generarán release notes"
		return 0
	fi

	# Extraer sección de la versión del CHANGELOG
	_version_section=$(awk "/^## \[${version}\]/,/^## \[/" "$changelog_file" | \
		head -n -1 | \
		sed '/^---$/d')

	if [[ -z "$version_section" ]]; then
		log_warn "No se encontró sección para versión $version en CHANGELOG.md"
		return 0
	fi

	# Crear release notes
	cat > "$output_file" <<EOF
# Release Notes - v${version}

$(date +%Y-%m-%d)

---

${version_section}

---

**Ver changelog completo**: [CHANGELOG.md](../CHANGELOG.md)
EOF

	log_success "Release notes generadas: $output_file"
	return 0
}

# ---------------------------------------------------------
# Valida que el repositorio está listo para release
# ---------------------------------------------------------
validate_repo() {
	log_step "Validando repositorio..."

	# Verificar que estamos en un repositorio Git
	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		log_warn "No es un repositorio Git, algunas validaciones se saltarán"
		return 0
	fi

	# Verificar que estamos en la rama correcta (main o master)
	_current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
	local current_branch="$_current_branch"
	unset _current_branch
	if [[ "$current_branch" != "main" ]] && [[ "$current_branch" != "master" ]]; then
		log_warn "No estás en la rama main/master (actual: $current_branch)"
		log_info "Considera hacer release desde main/master"
	fi

	# Verificar que no hay cambios sin commitear (warning, no error)
	if ! git diff-index --quiet HEAD -- 2>/dev/null; then
		log_warn "Hay cambios sin commitear"
		log_info "Considera hacer commit antes del release"
	fi

	# Verificar que estamos sincronizados con remoto (opcional)
	if git rev-parse --verify origin/main >/dev/null 2>&1 || \
		git rev-parse --verify origin/master >/dev/null 2>&1; then
		local remote_branch="origin/${current_branch}"
		if git rev-parse --verify "$remote_branch" >/dev/null 2>&1; then
			_local_commit=$(git rev-parse HEAD 2>/dev/null)
		local local_commit="$_local_commit"
		unset _local_commit
		local remote_commit
		remote_commit=$(git rev-parse "$remote_branch" 2>/dev/null)
			if [[ "$local_commit" != "$remote_commit" ]]; then
				log_warn "Rama local no está sincronizada con remoto"
				log_info "Considera hacer pull antes del release"
			fi
		fi
	fi

	log_success "Repositorio validado"
	return 0
}

# ---------------------------------------------------------
# Punto de entrada
# ---------------------------------------------------------
PART="${1:-}"
DRY_RUN=false
SKIP_TESTS=false

# Procesar opciones
shift 2>/dev/null || true
while [[ $# -gt 0 ]]; do
	case "$1" in
		--dry-run)
			DRY_RUN=true
			shift
			;;
		--skip-tests)
			SKIP_TESTS=true
			shift
			;;
		*)
			log_warn "Opción desconocida: $1"
			shift
			;;
	esac
done

# También verificar variables de entorno
if [[ -n "${DRY_RUN_ENV:-}" ]]; then
	DRY_RUN=true
fi
if [[ -n "${SKIP_TESTS:-}" ]]; then
	SKIP_TESTS=true
fi

# Validar parámetro PART
if [[ -z "$PART" ]]; then
	log_error "Debes especificar PART (major, minor, patch)"
	log_info "Uso: $0 <part> [--dry-run] [--skip-tests]"
	log_info "Ejemplo: $0 patch"
	exit 1
fi

if [[ "$PART" != "major" ]] && [[ "$PART" != "minor" ]] && [[ "$PART" != "patch" ]]; then
	log_error "PART debe ser major, minor o patch"
	exit 1
fi

log_title "🚀 PROCESO DE RELEASE"
echo ""

# Obtener versión actual
VERSION_FILE="${VERSION_FILE:-$PROJECT_ROOT/.version}"
CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "1.0.0")

# Calcular nueva versión
MAJOR=$(echo "$CURRENT_VERSION" | cut -d'.' -f1)
MINOR=$(echo "$CURRENT_VERSION" | cut -d'.' -f2)
PATCH=$(echo "$CURRENT_VERSION" | cut -d'.' -f3)

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
esac

log_info "Versión actual: $CURRENT_VERSION"
log_info "Nueva versión:  $NEW_VERSION"
log_info "Tipo de bump:   $PART"
if [[ "$DRY_RUN" == "true" ]]; then
	log_warn "MODO DRY-RUN: No se harán cambios reales"
fi
echo ""

# 1. Validar repositorio
validate_repo
echo ""

# 2. Ejecutar tests (si no se saltan)
if [[ "$SKIP_TESTS" == "false" ]]; then
	if ! run_tests; then
		log_error "Tests fallaron. Abortando release."
		exit 1
	fi
	echo ""
else
	log_warn "Tests saltados (--skip-tests)"
	echo ""
fi

# 3. Verificar calidad de código (opcional)
QUALITY_SCRIPT="$PROJECT_ROOT/scripts/sh/utils/check-code-quality.sh"
if [[ -f "$QUALITY_SCRIPT" ]] && [[ "$DRY_RUN" == "false" ]]; then
	log_step "Verificando calidad de código..."
	if bash "$QUALITY_SCRIPT" 2>&1; then
		log_success "Calidad de código verificada"
	else
		log_warn "Algunas verificaciones de calidad fallaron (continuando)"
	fi
	echo ""
fi

# 4. Bump version
BUMP_VERSION_SCRIPT="$PROJECT_ROOT/scripts/sh/commands/bump-version.sh"
if [[ ! -f "$BUMP_VERSION_SCRIPT" ]]; then
	log_error "bump-version.sh no encontrado"
	exit 1
fi

if [[ "$DRY_RUN" == "true" ]]; then
	log_info "[DRY-RUN] Ejecutaría: bash $BUMP_VERSION_SCRIPT $PART --no-tag --no-commit"
else
	log_step "Actualizando versión..."
	if bash "$BUMP_VERSION_SCRIPT" "$PART" --no-tag --no-commit; then
		log_success "Versión actualizada a $NEW_VERSION"
	else
		log_error "Falló al actualizar versión"
		exit 1
	fi
fi
echo ""

# 5. Generar release notes
if [[ "$DRY_RUN" == "false" ]]; then
	log_step "Generando release notes..."
	generate_release_notes "$NEW_VERSION"
	echo ""
fi

# 6. Crear tag de Git
if [[ "$DRY_RUN" == "true" ]]; then
	log_info "[DRY-RUN] Crearía tag: git tag -a v$NEW_VERSION -m \"Release version $NEW_VERSION\""
else
	log_step "Creando tag de Git..."
	if git rev-parse --git-dir >/dev/null 2>&1; then
		if git rev-parse "v$NEW_VERSION" >/dev/null 2>&1; then
			log_error "El tag v$NEW_VERSION ya existe"
			exit 1
		fi

		if git tag -a "v$NEW_VERSION" -m "Release version $NEW_VERSION" 2>/dev/null; then
			log_success "Tag creado: v$NEW_VERSION"
		else
			log_error "No se pudo crear el tag"
			exit 1
		fi
	else
		log_warn "No es un repositorio Git, saltando creación de tag"
	fi
fi
echo ""

# 7. Hacer commit de cambios
if [[ "$DRY_RUN" == "true" ]]; then
	log_info "[DRY-RUN] Haría commit: git commit -m \"chore: release version $NEW_VERSION\""
else
	log_step "Haciendo commit de cambios..."
	if git rev-parse --git-dir >/dev/null 2>&1; then
		if git diff --quiet && git diff --cached --quiet 2>/dev/null; then
			log_info "No hay cambios para commitear"
		else
			if git add .version .env README.md CHANGELOG.md \
				"RELEASE_NOTES_${NEW_VERSION}.md" 2>/dev/null && \
				git commit -m "chore: release version $NEW_VERSION" 2>/dev/null; then
				log_success "Cambios commiteados"
			else
				log_warn "No se pudo hacer commit automático"
				log_info "Haz commit manualmente de los archivos modificados"
			fi
		fi
	else
		log_warn "No es un repositorio Git, saltando commit"
	fi
fi
echo ""

# Resumen final
log_title "✅ RELEASE COMPLETADO"
echo ""
log_success "Versión: $CURRENT_VERSION → $NEW_VERSION"
log_info ""
log_info "Archivos actualizados:"
log_info "  - .version"
log_info "  - .env (INFRASTRUCTURE_VERSION)"
log_info "  - README.md"
log_info "  - CHANGELOG.md"
if [[ "$DRY_RUN" == "false" ]]; then
	log_info "  - RELEASE_NOTES_${NEW_VERSION}.md"
fi
log_info ""
log_info "Próximos pasos:"
if [[ "$DRY_RUN" == "false" ]]; then
	log_info "  1. Revisa los cambios: git diff"
	log_info "  2. Publica el tag: git push origin v$NEW_VERSION"
	log_info "  3. Publica el commit: git push origin $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'main')"
	log_info "  4. Crea release en GitHub usando RELEASE_NOTES_${NEW_VERSION}.md"
fi
log_info ""

exit 0
