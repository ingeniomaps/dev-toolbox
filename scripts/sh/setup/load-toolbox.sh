#!/usr/bin/env bash
# ============================================================================
# Script: load-toolbox.sh
# Ubicación: scripts/sh/setup/
# ============================================================================
# Clona o actualiza el repositorio dev-toolbox (u otro vía env) en .toolbox
# para usarlo como dependencia del proyecto.
#
# Uso:
#   make load-toolbox
#   GIT_USER=u GIT_TOKEN=t bash load-toolbox.sh
#
# Variables de entorno requeridas:
#   GIT_USER  - Usuario de GitHub
#   GIT_TOKEN - Token de acceso personal (repo)
#
# Variables opcionales (valores por defecto):
#   GIT_BRANCH     - Rama o tag (default: main). Si es tag, actualizar puede fallar.
#   GIT_REPO       - Repositorio (default: dev-toolbox)
#   TOOLBOX_TARGET - Carpeta destino (default: .toolbox)
#
# Retorno:
#   0 si se clonó o actualizó correctamente
#   1 si faltan GIT_USER/GIT_TOKEN o error en clone/pull
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_script_dir"
unset _script_dir
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"
if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/logging.sh"
fi

# ---------------------------------------------------------
# Clona o actualiza un repositorio.
#
# Parámetros:
#   1. Nombre de la rama o tag (ej. main, v1.2.0)
#   2. Usuario de GitHub
#   3. Token de acceso personal de GitHub
#   4. Nombre del repositorio (ej. dev-toolbox)
#   5. Carpeta destino local (opcional, default: .toolbox)
# ---------------------------------------------------------
clone_or_update_repo() {
	local branch="$1"
	local git_user="$2"
	local git_token="$3"
	local repo_name="$4"
	local target="${5:-.toolbox}"

	local repo="https://${git_token}@github.com/${git_user}/${repo_name}.git"
	local repo_display="github.com/${git_user}/${repo_name}.git"

	if [[ ! -d "$target" ]]; then
		if type log_info &>/dev/null; then
			log_info "Clonando $repo_display en $target (rama $branch)"
		else
			echo "[INFO] Clonando $repo_display en $target (rama $branch)"
		fi
		git clone --depth=1 --branch "$branch" "$repo" "$target"
	else
		if type log_info &>/dev/null; then
			log_info "Actualizando $target..."
		else
			echo "Actualizando $target..."
		fi
		git -C "$target" fetch origin
		git -C "$target" pull origin "$branch"
	fi
}

# ---------------------------------------------------------
# Punto de entrada
# ---------------------------------------------------------
main() {
	if [[ -z "${GIT_USER:-}" ]]; then
		if type log_error &>/dev/null; then
			log_error "GIT_USER es obligatorio. Exporta: export GIT_USER=tu_usuario"
		else
			echo "Error: GIT_USER es obligatorio. Exporta: export GIT_USER=tu_usuario" >&2
		fi
		exit 1
	fi
	if [[ -z "${GIT_TOKEN:-}" ]]; then
		if type log_error &>/dev/null; then
			log_error "GIT_TOKEN es obligatorio. Exporta: export GIT_TOKEN=tu_token"
		else
			echo "Error: GIT_TOKEN es obligatorio. Exporta: export GIT_TOKEN=tu_token" >&2
		fi
		exit 1
	fi

	local branch="${GIT_BRANCH:-main}"
	local repo_name="${GIT_REPO:-dev-toolbox}"
	local target="${TOOLBOX_TARGET:-.toolbox}"

	clone_or_update_repo "$branch" "$GIT_USER" "$GIT_TOKEN" "$repo_name" "$target"
}

main "$@"
