#!/usr/bin/env bash
# ============================================================================
# Script: setup.sh
# Ubicación: scripts/sh/setup/
# ============================================================================
# Script de configuración inicial completa del proyecto.
# Configura todo desde cero: dependencias, entorno, red, y servicios.
#
# Uso:
#   ./scripts/sh/setup/setup.sh
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#
# Retorno:
#   0 si la configuración fue exitosa
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

log_title "CONFIGURACIÓN INICIAL DEL PROYECTO"

# Paso 1: Verificar dependencias
log_step "Paso 1/6: Verificando dependencias del sistema..."
cd "$PROJECT_ROOT"
if make check-dependencies >/dev/null 2>&1; then
	log_success "Dependencias verificadas"
else
	log_warn "Algunas dependencias pueden faltar"
	log_info "Ejecuta: make install-dependencies para más información"
fi
echo ""

# Paso 2: Configurar entorno
log_step "Paso 2/6: Configurando archivo de entorno..."
if make setup-env >/dev/null 2>&1; then
	log_success "Archivo .env configurado"
else
	log_warn "No se pudo configurar .env automáticamente"
	log_info "Ejecuta: make init-env para crear el .env manualmente"
fi
echo ""

# Paso 3: Validar configuración
log_step "Paso 3/6: Validando configuración..."
if make validate >/dev/null 2>&1; then
	log_success "Configuración válida"
else
	log_warn "Algunas validaciones fallaron"
	log_info "Revisa los mensajes arriba y corrige los problemas"
fi
echo ""

# Paso 4: Configurar red Docker
log_step "Paso 4/6: Configurando red Docker..."
if make network-tool >/dev/null 2>&1; then
	log_success "Red Docker configurada"
else
	log_warn "No se pudo configurar la red"
	log_info "Verifica que Docker esté corriendo y que tengas permisos"
fi
echo ""

# Paso 5: Verificar puertos
log_step "Paso 5/6: Verificando disponibilidad de puertos..."
if make check-ports >/dev/null 2>&1; then
	log_success "Puertos disponibles"
else
	log_warn "Algunos puertos pueden estar en uso"
	log_info "Revisa los mensajes arriba"
fi
echo ""

# Paso 6: Verificación post-instalación
log_step "Paso 6/6: Ejecutando verificación post-instalación..."
if make verify-installation >/dev/null 2>&1; then
	log_success "Verificación post-instalación completada"
else
	log_warn "Algunas verificaciones fallaron"
fi
echo ""

log_title "CONFIGURACIÓN COMPLETADA"
echo ""
log_info "Próximos pasos:"
echo "  1. Revisa y edita el archivo .env con tus valores personalizados"
echo "  2. Inicia los servicios con: make up-<servicio> (para cada servicio definido)"
echo "  3. Verifica el estado con: make status"
echo "  4. Consulta la ayuda con: make help-toolbox"
echo ""
