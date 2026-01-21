#!/usr/bin/env bash
# ============================================================================
# Script: infisical-to-env.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Convierte la salida JSON de la API de Infisical (secrets + imports) en
# variables KEY=VALUE y las escribe o actualiza en un archivo .env.
#
# Uso:
#   curl ... | bash infisical-to-env.sh [archivo.env]
#   cat secrets.json | bash infisical-to-env.sh
#
# Parámetros:
#   $1 - Ruta al .env (opcional, default: .env)
#   stdin - JSON de Infisical con .secrets[] y .imports[].secrets[]
#
# Requiere: jq
#
# Retorno:
#   0 si se escribieron/actualizaron variables
#   1 si falta jq o el JSON es inválido
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
# Extrae claves y valores desde un JSON con estructura:
# {
#   "secrets": [ { "secretKey": "...", "secretValue": "..." }, ... ],
#   "imports": [ { "secrets": [ ... ] }, ... ]
# }
# Retorna líneas en formato KEY=VALUE
# Parámetros:
#   $1 - JSON en formato string
# ---------------------------------------------------------
parse_secrets_from_json() {
  local json_input="$1"
  echo "$json_input" | jq -r '
    [ (.secrets // [])[], ((.imports // [])[] | (.secrets // [])[]) ]
    | map(select((.secretKey != null) and (.secretKey != "")))
    | map({key: .secretKey, value: (.secretValue // "")})
    | .[]
    | "\(.key)=\(.value)"
  '
}

# ---------------------------------------------------------
# Verifica si una clave ya existe en el archivo .env
# Parámetros:
#   $1 - Clave a buscar
#   $2 - Ruta del archivo .env
# ---------------------------------------------------------
env_has_key() {
  local key="$1"
  local env_file="$2"
  awk -v k="$key" -F= '$1==k {exit 0} END{exit 1}' "$env_file" 2>/dev/null || return 1
}

# ---------------------------------------------------------
# Filtra las variables nuevas que aún no existen en el .env
# Parámetros:
#   $1 - Lista de KEY=VALUE (una por línea)
#   $2 - Ruta del archivo .env
# Retorna:
#   Lista de líneas KEY=VALUE que no están en el .env
# ---------------------------------------------------------
detect_new_variables() {
  local key_value_pairs="$1"
  local env_file="$2"
  local new_vars=""

  while IFS= read -r line; do
    local key="${line%%=*}"
    [[ -z "$key" ]] && continue
    if ! env_has_key "$key" "$env_file"; then
      new_vars+="$line"$'\n'
    fi
  done <<< "$key_value_pairs"

  echo "$new_vars"
}

# ---------------------------------------------------------
# Agrega un título al archivo .env si hay nuevas variables
# y el título aún no existe.
# Parámetros:
#   $1 - Ruta del archivo .env
#   $2 - Nuevas variables detectadas (string multi-linea)
# ---------------------------------------------------------
add_title_if_needed() {
  local title="# Secret variables (Infisical)"
  local env_file="$1"
  local new_variables="$2"
  if [[ -n "$new_variables" ]] && ! grep -Fxq "$title" "$env_file" 2>/dev/null; then
    printf '\n%s\n' "$title" >> "$env_file"
  fi
}

# ---------------------------------------------------------
# Reemplaza o agrega variables al archivo .env
# Parámetros:
#   $1 - Lista de KEY=VALUE (una por línea)
#   $2 - Ruta del archivo .env
# ---------------------------------------------------------
write_or_update_env() {
  local key_value_pairs="$1"
  local env_file="$2"

  while IFS= read -r line; do
    local key="${line%%=*}"
    [[ -z "$key" ]] && continue
    local value="${line#*=}"
    local escaped_value
    escaped_value=$(printf '%s\n' "$value" | sed 's/"/\\"/g')

    if env_has_key "$key" "$env_file"; then
      sed -i.bak "s|^$key=.*|$key=\"$escaped_value\"|" "$env_file"
    else
      echo "$key=\"$escaped_value\"" >> "$env_file"
    fi
  done <<< "$key_value_pairs"
}

# ---------------------------------------------------------
# Actualiza un archivo .env desde un JSON
# con estructura compatible. Agrega variables nuevas,
# reemplaza existentes, y agrega un título si es necesario.
#
# Parámetros:
#   $1 - Ruta del archivo .env (opcional, default: .env)
#   $2 - JSON en string (opcional, si no se pasa, se lee desde stdin)
# ---------------------------------------------------------
update_env_from_json() {
  local env_file="${1:-.env}"
  local json_input="${2:-$(cat)}"

  touch "$env_file"
  local key_value_pairs
  key_value_pairs=$(parse_secrets_from_json "$json_input")

  local new_vars
  new_vars=$(detect_new_variables "$key_value_pairs" "$env_file")

  add_title_if_needed "$env_file" "$new_vars"
  write_or_update_env "$key_value_pairs" "$env_file"

  if type log_success &>/dev/null; then
    log_success "Variables actualizadas en $env_file"
  else
    echo "[OK] Variables actualizadas en $env_file"
  fi
}

# Punto de entrada (lee el archivo env desde argumento $1 y JSON desde stdin)
main() {
  if ! command -v jq &>/dev/null; then
    if type log_error &>/dev/null; then
      log_error "jq es necesario. Instala: apt install jq / brew install jq"
    else
      echo "Error: jq es necesario. Instala: apt install jq / brew install jq" >&2
    fi
    exit 1
  fi
  local env_file="${1:-.env}"
  local json_input
  json_input="$(cat)"
  update_env_from_json "$env_file" "$json_input"
}

main "$@"
