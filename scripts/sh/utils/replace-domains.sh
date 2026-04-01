#!/usr/bin/env bash
# ============================================================================
# Script: replace-domains.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Reemplaza todas las ocurrencias de un dominio por otro en los archivos del
# proyecto, incluyendo DNS invertidos (ej: ejemplo.com → com.ejemplo).
#
# Uso:
#   ./scripts/sh/utils/replace-domains.sh <dominio_nuevo> <dominio_actual>
#   ./scripts/sh/utils/replace-domains.sh nuevodominio.com viejodominio.com
#
# Parámetros:
#   $1 - Dominio nuevo (ej: nuevodominio.com)
#   $2 - Dominio actual a reemplazar (ej: viejodominio.com)
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto donde buscar (default: $(pwd))
#
# Notas:
#   - Excluye directorios: .git, log, logs, node_modules, certbot, cert, certs, *_data
#   - Excluye archivos: docker-compose.yml, package.json, .gitignore, *.md
#   - También reemplaza DNS invertidos (ej: ejemplo.com → com.ejemplo)
#
# Retorno:
#   0 si el reemplazo fue exitoso
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

if [[ $# -ne 2 ]]; then
	log_error "Se requieren 2 argumentos"
	log_info "Uso: $0 <dominio_nuevo> <dominio_actual>"
	log_info "Ejemplo: $0 nuevodominio.com viejodominio.com"
	exit 1
fi

readonly DOMAIN_NEW="$1"
readonly DOMAIN_CURRENT="$2"

if [[ -z "$DOMAIN_NEW" ]] || [[ -z "$DOMAIN_CURRENT" ]]; then
	log_error "Los dominios no pueden estar vacíos"
	exit 1
fi

if [[ "$DOMAIN_NEW" == "$DOMAIN_CURRENT" ]]; then
	log_warn "Los dominios son iguales. No hay nada que reemplazar."
	exit 0
fi

# Función auxiliar: unir elementos con un separador
join() {
	local IFS="$1"
	shift
	echo "$*"
}

log_info "Reemplazando dominios: $DOMAIN_CURRENT → $DOMAIN_NEW"

# Reemplazo de dominios principales
if grep -rl "$DOMAIN_CURRENT" "$PROJECT_ROOT" \
	--exclude-dir=".git" \
	--exclude-dir="log" \
	--exclude-dir="logs" \
	--exclude-dir="node_modules" \
	--exclude-dir="certbot" \
	--exclude-dir="cert" \
	--exclude-dir="certs" \
	--exclude="docker-compose.yml" \
	--exclude="package.json" \
	--exclude=".gitignore" \
	--exclude="*.md" \
	>/dev/null 2>&1; then

	grep -rl "$DOMAIN_CURRENT" "$PROJECT_ROOT" \
		--exclude-dir=".git" \
		--exclude-dir="log" \
		--exclude-dir="logs" \
		--exclude-dir="node_modules" \
		--exclude-dir="certbot" \
		--exclude-dir="cert" \
		--exclude-dir="certs" \
		--exclude="docker-compose.yml" \
		--exclude="package.json" \
		--exclude=".gitignore" \
		--exclude="*.md" \
		| xargs --no-run-if-empty sed -i "s#${DOMAIN_CURRENT}#${DOMAIN_NEW}#g"

	log_success "Dominio principal reemplazado en archivos"
else
	log_info "No se encontraron archivos con el dominio: $DOMAIN_CURRENT"
fi

# Reemplazo de DNS invertidos (ej: ejemplo.com → com.ejemplo)
#
# Algoritmo:
#   Para un dominio como "subdomain.ejemplo.com":
#   1. Divide el dominio en segmentos: ["subdomain", "ejemplo", "com"]
#   2. Toma los últimos 2 segmentos: "ejemplo" y "com"
#   3. Invierte el orden: "com.ejemplo"
#
#   Ejemplo:
#     "subdomain.ejemplo.com" -> "com.ejemplo"
#     "api.mi-servicio.com" -> "com.mi-servicio"
#     "test.example.org" -> "org.example"
#
#   Esto es útil para configuraciones DNS donde se necesita el formato invertido.
#
# Extraer los últimos dos segmentos del dominio y crear DNS invertido
OLD_DNS=$(join . "${DOMAIN_CURRENT//./ }" | awk '{print $(NF-1)"."$NF}' 2>/dev/null || echo "")
NEW_DNS=$(join . "${DOMAIN_NEW//./ }" | awk '{print $(NF-1)"."$NF}' 2>/dev/null || echo "")

if [[ -n "$OLD_DNS" ]] && [[ -n "$NEW_DNS" ]] && [[ "$OLD_DNS" != "$NEW_DNS" ]]; then
	if grep -rl "$OLD_DNS" "$PROJECT_ROOT" \
		--exclude-dir=".git" \
		--exclude-dir="log" \
		--exclude-dir="logs" \
		--exclude-dir="node_modules" \
		--exclude-dir="certbot" \
		--exclude-dir="cert" \
		--exclude-dir="certs" \
		--exclude="docker-compose.yml" \
		--exclude="package.json" \
		--exclude=".gitignore" \
		--exclude="*.md" \
		>/dev/null 2>&1; then

		grep -rl "$OLD_DNS" "$PROJECT_ROOT" \
			--exclude-dir=".git" \
			--exclude-dir="log" \
			--exclude-dir="logs" \
			--exclude-dir="node_modules" \
			--exclude-dir="certbot" \
			--exclude-dir="cert" \
			--exclude-dir="certs" \
			--exclude="docker-compose.yml" \
			--exclude="package.json" \
			--exclude=".gitignore" \
			--exclude="*.md" \
			| xargs --no-run-if-empty sed -i "s#${OLD_DNS}#${NEW_DNS}#g"

		log_success "DNS invertido reemplazado: $OLD_DNS → $NEW_DNS"
	fi
fi

log_success "Reemplazo de dominios completado"
