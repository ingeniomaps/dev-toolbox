#!/usr/bin/env bash
# ============================================================================
# Script: export-config.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Exporta configuración del proyecto a formato portable (JSON o YAML).
#
# Uso:
#   ./scripts/sh/commands/export-config.sh [formato] [archivo_salida]
#
# Parámetros:
#   $1 - (opcional) Formato de salida: json, yaml (default: json)
#   $2 - (opcional) Archivo de salida (default: config.json o config.yaml)
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   FORMAT - Formato de salida (json, yaml)
#   OUTPUT - Archivo de salida
#
# Retorno:
#   0 si la exportación fue exitosa
#   1 si hay errores
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR="$_script_dir"
unset _script_dir
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"

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

# Cargar validation.sh para validar prerrequisitos
if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

readonly FORMAT="${1:-${FORMAT:-json}}"
readonly OUTPUT="${2:-${OUTPUT:-}}"
readonly ENV_FILE="$PROJECT_ROOT/.env"
readonly VERSION_FILE="$PROJECT_ROOT/.version"

# Validar que .env existe (opcional, pero recomendado)
if [[ ! -f "$ENV_FILE" ]]; then
	log_warn "Archivo .env no encontrado: $ENV_FILE"
	log_info "💡 Sugerencia: Ejecuta 'make init-env' para crear el archivo .env"
	log_info "   Continuando sin .env..."
fi

# Determinar archivo de salida
if [[ -z "$OUTPUT" ]]; then
	if [[ "$FORMAT" == "yaml" ]]; then
		OUTPUT_FILE="$PROJECT_ROOT/config.yaml"
	else
		OUTPUT_FILE="$PROJECT_ROOT/config.json"
	fi
else
	OUTPUT_FILE="$OUTPUT"
fi

# Validar formato
if [[ "$FORMAT" != "json" ]] && [[ "$FORMAT" != "yaml" ]]; then
	log_error "Formato no válido: $FORMAT (debe ser json o yaml)"
	exit 1
fi

log_step "Exportando configuración a $FORMAT..."

# Leer versión
VERSION="desconocida"
if [[ -f "$VERSION_FILE" ]]; then
	VERSION=$(cat "$VERSION_FILE" 2>/dev/null | tr -d '\n' || echo "desconocida")
fi

# Leer variables de .env (sin secretos)
SECRET_PATTERNS="PASSWORD|SECRET|TOKEN|KEY|PRIVATE|CREDENTIAL"
CONFIG_VARS=""

if [[ -f "$ENV_FILE" ]]; then
	while IFS='=' read -r line; do
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ -z "${line// }" ]] && continue

		VAR_NAME=$(echo "$line" | cut -d'=' -f1)
		VAR_VALUE=$(echo "$line" | cut -d'=' -f2- | sed 's/^["'\'']//;s/["'\'']$//')

		# Ocultar secretos
		if echo "$VAR_NAME" | grep -qiE "$SECRET_PATTERNS"; then
			VAR_VALUE="***OCULTO***"
		fi

		CONFIG_VARS="${CONFIG_VARS}${VAR_NAME}=${VAR_VALUE}"$'\n'
	done < "$ENV_FILE"
fi

# Generar exportación según formato
if [[ "$FORMAT" == "json" ]]; then
	{
		echo "{"
		echo "  \"version\": \"$VERSION\","
		echo "  \"exported_at\": \"$(date -Iseconds)\","
		echo "  \"variables\": {"

		FIRST=true
		while IFS='=' read -r var_line; do
			[[ -z "$var_line" ]] && continue
			VAR_NAME=$(echo "$var_line" | cut -d'=' -f1)
			VAR_VALUE=$(echo "$var_line" | cut -d'=' -f2-)

			if [[ "$FIRST" == "false" ]]; then
				echo ","
			fi
			FIRST=false

			# Escapar valores JSON
			VAR_VALUE_ESC=$(echo "$VAR_VALUE" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
			echo -n "    \"$VAR_NAME\": \"$VAR_VALUE_ESC\""
		done <<< "$CONFIG_VARS"

		echo ""
		echo "  }"
		echo "}"
	} > "$OUTPUT_FILE"
else
	# YAML
	{
		echo "version: $VERSION"
		echo "exported_at: $(date -Iseconds)"
		echo "variables:"

		while IFS='=' read -r var_line; do
			[[ -z "$var_line" ]] && continue
			VAR_NAME=$(echo "$var_line" | cut -d'=' -f1)
			VAR_VALUE=$(echo "$var_line" | cut -d'=' -f2-)

			# Escapar valores YAML
			VAR_VALUE_ESC=$(echo "$VAR_VALUE" | sed "s/:/\\:/g")
			echo "  $VAR_NAME: \"$VAR_VALUE_ESC\""
		done <<< "$CONFIG_VARS"
	} > "$OUTPUT_FILE"
fi

log_success "Configuración exportada a: $OUTPUT_FILE"
