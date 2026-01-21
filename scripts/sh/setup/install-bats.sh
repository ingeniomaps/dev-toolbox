#!/usr/bin/env bash
# ============================================================================
# Script: install-bats.sh
# Ubicación: scripts/sh/setup/
# ============================================================================
# Instala BATS (Bash Automated Testing System) para ejecutar tests.
#
# Uso:
#   ./scripts/sh/setup/install-bats.sh
#   make install-bats
#
# Variables de entorno:
#   BATS_VERSION - Versión de BATS a instalar (default: latest)
#   BATS_INSTALL_DIR - Directorio donde instalar BATS (default: .bats)
#
# Retorno:
#   0 si la instalación fue exitosa
#   1 si hubo errores
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_script_dir"
unset _script_dir
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"
_project_root="$(cd "$SCRIPT_DIR/../../.." && pwd)"
readonly PROJECT_ROOT="$_project_root"
unset _project_root

# Cargar helpers comunes
if [[ -f "$COMMON_SCRIPTS_DIR/init.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/init.sh"
	init_script
else
	_pr="${PROJECT_ROOT:-$(pwd)}"
	readonly PROJECT_ROOT="${_pr%/}"
	unset _pr
	if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
		source "$COMMON_SCRIPTS_DIR/logging.sh"
	fi
fi

readonly BATS_VERSION="${BATS_VERSION:-latest}"
readonly BATS_INSTALL_DIR="${BATS_INSTALL_DIR:-$PROJECT_ROOT/.bats}"
readonly BATS_BIN="$BATS_INSTALL_DIR/bin/bats"

log_step "Instalando BATS (Bash Automated Testing System)..."

# Verificar si BATS ya está instalado
if command -v bats >/dev/null 2>&1; then
	INSTALLED_VERSION=$(bats --version 2>/dev/null | head -1 || echo "unknown")
	log_success "BATS ya está instalado: $INSTALLED_VERSION"
	log_info "Ubicación: $(command -v bats)"

	# Verificar si está en el directorio esperado
	if [[ "$(command -v bats)" == "$BATS_BIN" ]]; then
		log_info "BATS está en la ubicación esperada"
		exit 0
	else
		log_info "BATS está instalado globalmente, no en $BATS_INSTALL_DIR"
		log_info "Para usar la versión local, ejecuta: export PATH=\"$BATS_INSTALL_DIR/bin:\$PATH\""
		exit 0
	fi
fi

# Verificar si ya existe instalación local
if [[ -f "$BATS_BIN" ]] && [[ -x "$BATS_BIN" ]]; then
	log_success "BATS ya está instalado localmente en $BATS_INSTALL_DIR"
	log_info "Versión: $($BATS_BIN --version 2>/dev/null | head -1 || echo "unknown")"
	exit 0
fi

# Verificar dependencias
if ! command -v git >/dev/null 2>&1; then
	log_error "Git no está instalado. BATS requiere Git para instalarse."
	log_info "💡 Sugerencia: Instala Git desde https://git-scm.com/downloads"
	exit 1
fi

# Crear directorio de instalación
mkdir -p "$BATS_INSTALL_DIR"

log_info "Instalando BATS en: $BATS_INSTALL_DIR"

# Clonar repositorio de BATS
BATS_REPO="https://github.com/bats-core/bats-core.git"
BATS_TEMP_DIR=$(mktemp -d)

if ! git clone "$BATS_REPO" "$BATS_TEMP_DIR" >/dev/null 2>&1; then
	log_error "Error al clonar repositorio de BATS"
	rm -rf "$BATS_TEMP_DIR"
	exit 1
fi

# Instalar BATS
cd "$BATS_TEMP_DIR" || exit 1

if [[ "$BATS_VERSION" != "latest" ]]; then
	if git checkout "v${BATS_VERSION}" >/dev/null 2>&1 || \
		git checkout "$BATS_VERSION" >/dev/null 2>&1; then
		log_info "Instalando BATS versión $BATS_VERSION"
	else
		log_warn "No se encontró versión $BATS_VERSION, usando latest"
	fi
fi

# Ejecutar instalación
if ./install.sh "$BATS_INSTALL_DIR" >/dev/null 2>&1; then
	log_success "BATS instalado exitosamente"
else
	log_error "Error al instalar BATS"
	rm -rf "$BATS_TEMP_DIR"
	exit 1
fi

# Limpiar
cd "$PROJECT_ROOT" || exit 1
rm -rf "$BATS_TEMP_DIR"

# Verificar instalación
if [[ -f "$BATS_BIN" ]] && [[ -x "$BATS_BIN" ]]; then
	INSTALLED_VERSION=$("$BATS_BIN" --version 2>/dev/null | head -1 || echo "unknown")
	log_success "BATS instalado correctamente: $INSTALLED_VERSION"
	log_info "Ubicación: $BATS_BIN"
	echo ""
	log_info "💡 Para usar BATS, agrega al PATH:"
	echo "   export PATH=\"$BATS_INSTALL_DIR/bin:\$PATH\""
	echo ""
	log_info "   O usa directamente:"
	echo "   $BATS_BIN tests/unit/test-validation.bats"
	exit 0
else
	log_error "BATS no se instaló correctamente"
	exit 1
fi
