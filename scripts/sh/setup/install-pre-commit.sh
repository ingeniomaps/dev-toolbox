#!/usr/bin/env bash
# ============================================================================
# Script: install-pre-commit.sh
# Ubicación: scripts/sh/setup/
# ============================================================================
# Instala y configura pre-commit hooks para el proyecto.
# Intenta instalar pre-commit automáticamente si no está instalado.
#
# Uso:
#   ./scripts/sh/setup/install-pre-commit.sh [--auto-install] [--run]
#
# Opciones:
#   --auto-install  - Intenta instalar pre-commit automáticamente si no está instalado
#   --run          - Ejecuta pre-commit run --all-files después de instalar
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#
# Retorno:
#   0 si la instalación fue exitosa
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
fi

# Parsear argumentos
AUTO_INSTALL=false
RUN_AFTER_INSTALL=false

for arg in "$@"; do
	case "$arg" in
		--auto-install)
			AUTO_INSTALL=true
			;;
		--run)
			RUN_AFTER_INSTALL=true
			;;
		*)
			;;
	esac
done

log_title "INSTALACIÓN DE PRE-COMMIT HOOKS"

# Verificar que pre-commit está instalado
if ! command -v pre-commit >/dev/null 2>&1; then
	log_warn "pre-commit no está instalado"

	if [[ "$AUTO_INSTALL" == "true" ]]; then
		log_step "Intentando instalar pre-commit automáticamente..."

		# Intentar con pip
		if command -v pip >/dev/null 2>&1; then
			if pip install pre-commit >/dev/null 2>&1; then
				log_success "pre-commit instalado con pip"
			elif pip3 install pre-commit >/dev/null 2>&1; then
				log_success "pre-commit instalado con pip3"
			else
				log_error "No se pudo instalar pre-commit con pip"
				log_info "Instala manualmente con:"
				log_info "  pip install pre-commit"
				log_info "  O desde: https://pre-commit.com/#installation"
				exit 1
			fi
		# Intentar con pipx
		elif command -v pipx >/dev/null 2>&1; then
			if pipx install pre-commit >/dev/null 2>&1; then
				log_success "pre-commit instalado con pipx"
			else
				log_error "No se pudo instalar pre-commit con pipx"
				log_info "Instala manualmente con:"
				log_info "  pipx install pre-commit"
				log_info "  O desde: https://pre-commit.com/#installation"
				exit 1
			fi
		else
			log_error "No se encontró pip ni pipx para instalar pre-commit"
			log_info "Instala manualmente con:"
			log_info "  pip install pre-commit"
			log_info "  pipx install pre-commit"
			log_info "  O desde: https://pre-commit.com/#installation"
			exit 1
		fi
	else
		log_info "Instala con:"
		log_info "  pip install pre-commit"
		log_info "  O desde: https://pre-commit.com/#installation"
		log_info ""
		log_info "O ejecuta este script con --auto-install para instalar automáticamente"
		exit 1
	fi
fi

log_info "pre-commit encontrado: $(pre-commit --version)"

# Verificar que .pre-commit-config.yaml existe
if [[ ! -f "$PROJECT_ROOT/.pre-commit-config.yaml" ]]; then
	log_error "Archivo .pre-commit-config.yaml no encontrado"
	exit 1
fi

log_info "Configuración encontrada: .pre-commit-config.yaml"

# Instalar hooks
log_step "Instalando pre-commit hooks..."
cd "$PROJECT_ROOT"

if pre-commit install; then
	log_success "Pre-commit hooks instalados"
else
	log_error "Error al instalar pre-commit hooks"
	exit 1
fi

echo ""

# Verificar que los hooks están instalados
if [[ -d "$PROJECT_ROOT/.git/hooks" ]]; then
	if [[ -f "$PROJECT_ROOT/.git/hooks/pre-commit" ]]; then
		log_success "Hook pre-commit instalado correctamente"
	else
		log_warn "Hook pre-commit no encontrado (puede ser normal si no es un repo Git)"
	fi
fi

echo ""
log_info "Próximos pasos:"
log_info "  1. Los hooks se ejecutarán automáticamente en cada commit"
log_info "  2. Para ejecutar manualmente: pre-commit run --all-files"
log_info "  3. Para saltar hooks: git commit --no-verify"
echo ""

# Ejecutar validaciones si se solicita
if [[ "$RUN_AFTER_INSTALL" == "true" ]]; then
	echo ""
	log_step "Ejecutando validaciones de pre-commit..."
	if pre-commit run --all-files; then
		log_success "Todas las validaciones pasaron"
	else
		log_warn "Algunas validaciones fallaron. Revisa los errores arriba."
		exit 1
	fi
fi

log_success "Instalación completada"
