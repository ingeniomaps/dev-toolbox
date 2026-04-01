# ============================================================================
# start_required.sh
# Ubicación: scripts/sh/common/
# ============================================================================
# Funciones para iniciar contenedores y repositorios requeridos.
#
# Uso:
#   source "$COMMON_SCRIPTS_DIR/start_required.sh"
#   start_required_containers "servicio1 servicio2 servicio3"
#   start_required_repositories "main" "user" "token" "servicio1 servicio2"
#
# Variables de entorno:
#   SERVICE_PREFIX - Prefijo del nombre del contenedor (opcional)
#
# Funciones:
#   - start_required_containers: Inicia contenedores si no están en ejecución
#   - start_required_repositories: Clona/actualiza repos y inicia contenedores
# ============================================================================

# -------------------------------------------------------------------------
# Inicia los contenedores locales requeridos si no están en ejecución.
#
# Parámetros:
#   $1 - Lista de nombres de contenedores separados por espacios
#
# Variables de entorno:
#   SERVICE_PREFIX - Prefijo del nombre del contenedor (opcional)
#
# Descripción:
#   - Por cada contenedor:
#       - Si no está en ejecución (`docker ps`), ejecuta `make up-<nombre>`.
# -------------------------------------------------------------------------
start_required_containers() {
	local containers
	IFS=' ' read -ra containers <<< "$1"
	local slug="${SERVICE_PREFIX:+$SERVICE_PREFIX-}"

	for name in "${containers[@]}"; do
		if [[ -z $(docker ps -q -f "name=$slug$name") ]]; then
			make "up-$name"
		fi
	done
}

# -------------------------------------------------------------------------
# Inicializa los contenedores requeridos si no están corriendo localmente.
#
# Parámetros:
#   $1 - Rama del repositorio Git (ej: "main", "develop")
#   $2 - Usuario de GitHub
#   $3 - Token personal de GitHub (para acceso autenticado)
#   $4 - Lista de repositorios separados por espacios (ej: "servicio1 servicio2")
#   $5 - (opcional) Patrón de URL del repositorio
#        (default: "https://${git_token}@github.com/${git_user}/${repo_name}.git")
#   $6 - (opcional) Patrón de carpeta destino (default: ".${repo_name}")
#
# Variables de entorno:
#   SERVICE_PREFIX - Prefijo del nombre del contenedor (opcional)
#   REPO_URL_PATTERN - Patrón de URL (opcional, sobreescribe $5)
#   REPO_FOLDER_PATTERN - Patrón de carpeta (opcional, sobreescribe $6)
#
# Descripción:
#   - Clona o actualiza repositorios especificados.
#   - Verifica si los contenedores están en ejecución (`docker ps`).
#   - Si no están activos:
#       - Clona o actualiza el repositorio correspondiente en una carpeta local.
#   - Usa acceso autenticado para evitar problemas de permisos con `git clone`.
#
# Retorno:
#   No retorna valores directamente, pero escribe mensajes a la salida estándar
#   y realiza operaciones de clonación o actualización de repositorios.
# -------------------------------------------------------------------------
start_required_repositories() {
	local branch="${1}"
	local git_user="${2}"
	local git_token="${3}"
	local slug="${SERVICE_PREFIX:+$SERVICE_PREFIX-}"
	local repositories
	IFS=' ' read -ra repositories <<< "$4"

	# Patrones configurables para URLs y carpetas
	local repo_url_pattern="${REPO_URL_PATTERN:-${5:-https://${git_token}@github.com/${git_user}/\${repo_name}.git}}"
	local repo_folder_pattern="${REPO_FOLDER_PATTERN:-${6:-.\${repo_name}}}"

	for repo_name in "${repositories[@]}"; do
		# Expandir patrones con el nombre del repositorio
		local repo_url
		repo_url="${repo_url_pattern//\$\{repo_name\}/$repo_name}"
		repo_url="${repo_url//\$\{git_user\}/$git_user}"
		repo_url="${repo_url//\$\{git_token\}/$git_token}"
		local target
		target="${repo_folder_pattern//\$\{repo_name\}/$repo_name}"

		if [[ ! -d "$target" ]]; then
			if [[ -z $(docker ps -q -f "name=$slug$repo_name") ]]; then
				git clone --depth=1 --branch "$branch" "$repo_url" "$target"
				make "up-$repo_name"
			fi
		else
			before=$(git -C "$target" rev-parse HEAD 2>/dev/null || echo "")
			git -C "$target" pull --quiet 2>/dev/null || true
			after=$(git -C "$target" rev-parse HEAD 2>/dev/null || echo "")

			if [[ -n "$before" ]] && [[ -n "$after" ]] && [[ "$before" != "$after" ]]; then
				make "down-$repo_name" 2>/dev/null || true
				make "up-$repo_name"
			fi
		fi
	done
}
