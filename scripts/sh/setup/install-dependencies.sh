#!/usr/bin/env bash
# ============================================================================
# Script: install-dependencies.sh
# Ubicación: scripts/sh/setup/
# ============================================================================
# Intenta instalar dependencias faltantes automáticamente.
#
# Uso:
#   ./scripts/sh/setup/install-dependencies.sh
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (opcional)
#
# Retorno:
#   0 si todas las dependencias están instaladas o se instalaron exitosamente
#   1 si alguna instalación falló
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

EXIT_CODE=0

log_info "Verificando e instalando dependencias..."

# Detectar sistema operativo
if [[ -f /etc/os-release ]]; then
	. /etc/os-release
	OS=$ID
else
	OS=$(uname -s | tr '[:upper:]' '[:lower:]')
fi

# Verificar Docker
if ! command -v docker >/dev/null 2>&1; then
	log_warn "Docker no está instalado"
	log_info "Intentando instalar Docker..."

	case $OS in
		ubuntu|debian)
			if command -v apt-get >/dev/null 2>&1; then
				log_info "Ejecuta: curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh"
			fi
			;;
		fedora|rhel|centos)
			if command -v dnf >/dev/null 2>&1; then
				log_info "Ejecuta: sudo dnf install -y docker"
			elif command -v yum >/dev/null 2>&1; then
				log_info "Ejecuta: sudo yum install -y docker"
			fi
			;;
		*)
			log_warn "No se puede instalar Docker automáticamente en $OS"
			log_info "Visita: https://docs.docker.com/get-docker/"
			;;
	esac
	EXIT_CODE=1
else
	log_success "Docker está instalado"
fi

# Verificar Docker Compose
if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
	log_warn "Docker Compose no está instalado"
	log_info "Docker Compose V2 viene con Docker. Si usas V1, instala con:"
	log_info "  sudo curl -L \"https://github.com/docker/compose/releases/" \
		"latest/download/docker-compose-$(uname -s)-$(uname -m)\" " \
		"-o /usr/local/bin/docker-compose"
	log_info "  sudo chmod +x /usr/local/bin/docker-compose"
	EXIT_CODE=1
else
	log_success "Docker Compose está instalado"
fi

# Verificar Make
if ! command -v make >/dev/null 2>&1; then
	log_warn "Make no está instalado"
	log_info "Intentando instalar Make..."

	case $OS in
		ubuntu|debian)
			log_info "Ejecuta: sudo apt-get update && sudo apt-get install -y make"
			;;
		fedora|rhel|centos)
			if command -v dnf >/dev/null 2>&1; then
				log_info "Ejecuta: sudo dnf install -y make"
			elif command -v yum >/dev/null 2>&1; then
				log_info "Ejecuta: sudo yum install -y make"
			fi
			;;
		*)
			log_warn "No se puede instalar Make automáticamente en $OS"
			;;
	esac
	EXIT_CODE=1
else
	log_success "Make está instalado"
fi

# Verificar Bash
if ! command -v bash >/dev/null 2>&1; then
	log_error "Bash no está instalado (requerido)"
	EXIT_CODE=1
else
	log_success "Bash está instalado"
fi

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
	log_success "Todas las dependencias están instaladas"
	exit 0
else
	log_warn "Algunas dependencias necesitan instalación manual"
	log_info "Sigue las instrucciones arriba para instalar las dependencias faltantes"
	exit 1
fi
