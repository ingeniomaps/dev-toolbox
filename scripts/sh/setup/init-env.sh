#!/usr/bin/env bash
# ============================================================================
# Script: init-env.sh
# Ubicación: scripts/sh/setup/
# ============================================================================
# Crea .env desde plantillas. Busca: .env-template, .env.template, .env-example,
# .env.example.
#
# Uso:
#   ./scripts/sh/setup/init-env.sh [NOMBRE] [--force] [--silent]
#   make init-env  [NAME=development] [FORCE=true] [SILENT=true]
#
# Parámetros:
#   $1        - Nombre de entorno (ej. development → .env.development). Vacío = .env
#   --force   - Fuerza recreación aunque exista
#   --silent  - Solo errores
#
# Directorio de trabajo:
#   - make init-env: usa $(CURDIR), la carpeta desde donde se ejecutó make
#   - Ejecución directa: usa el directorio actual (pwd). Se puede forzar con
#     PROJECT_ROOT=/ruta bash init-env.sh
#
# Retorno:
#   0 si se creó o ya existía (y no --force)
#   1 si error (plantilla no encontrada, etc.)
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
	readonly PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
	if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
		source "$COMMON_SCRIPTS_DIR/logging.sh"
	fi
fi

# ============================================================================
# VARIABLES Y CONFIGURACIÓN
# ============================================================================

NAME="${1:-}"
FORCE=false
SILENT=false

# Procesar argumentos
while [[ $# -gt 0 ]]; do
	case $1 in
		--force|--Force|--FORCE|-f)
			FORCE=true
			shift
			;;
		--silent|--Silent|--SILENT|-s)
			SILENT=true
			shift
			;;
		--help|--Help|--HELP|-h)
			echo "Uso: $0 [NOMBRE] [--force] [--silent]"
			echo ""
			echo "Argumentos:"
			echo "  NOMBRE        Nombre del entorno (ej: development, production)"
			echo "                Si no se especifica, crea .env"
			echo "  --force, -f   Fuerza recreación incluso si existe"
			echo "  --silent, -s  Modo silencioso (solo muestra errores)"
			exit 0
			;;
		-*)
			log_error "Opción desconocida: $1"
			exit 1
			;;
		*)
			if [[ -z "$NAME" ]]; then
				NAME="$1"
			else
				log_error "Múltiples nombres especificados"
				exit 1
			fi
			shift
			;;
	esac
done

# Determinar nombre del archivo de salida
if [[ -n "$NAME" ]]; then
	ENV_FILE="$PROJECT_ROOT/.env.${NAME}"
else
	ENV_FILE="$PROJECT_ROOT/.env"
fi

# Lista de plantillas posibles en orden de prioridad
readonly TEMPLATE_CANDIDATES=(
	".env-template"
	".env.template"
	".env-example"
	".env.example"
)

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
	# Cambiar al directorio raíz del proyecto
	cd "$PROJECT_ROOT" || error_exit "No se pudo cambiar al directorio raíz"

	# Configurar modo silencioso si se solicita
	# VERBOSE está reservado para uso futuro
	if [[ "$SILENT" == "true" ]]; then
		# VERBOSE=false
		:
	fi

	# Mostrar paso inicial
	if [[ "$SILENT" != "true" ]]; then
		log_step "Inicializando archivo de entorno: $ENV_FILE"
	fi

	# Buscar plantilla disponible
	ENV_TEMPLATE=""
	for template in "${TEMPLATE_CANDIDATES[@]}"; do
		if [[ -f "$template" ]]; then
			ENV_TEMPLATE="$template"
			break
		fi
	done

	# Verificar que se encontró una plantilla
	if [[ -z "$ENV_TEMPLATE" ]]; then
		log_error "No se encontró ninguna plantilla. Buscadas: $(IFS=' '; echo "${TEMPLATE_CANDIDATES[*]}")"
		exit 1
	fi

	# Advertir si la plantilla está vacía
	if [[ ! -s "$ENV_TEMPLATE" ]]; then
		if [[ "$SILENT" != "true" ]]; then
			log_warn "Template $ENV_TEMPLATE está vacío"
		fi
	fi

	# Procesar creación/copia del archivo
	if [[ "$FORCE" == "true" ]] && [[ -f "$ENV_FILE" ]]; then
		if [[ "$SILENT" != "true" ]]; then
			log_info "Forzando recreación de $ENV_FILE desde $ENV_TEMPLATE" \
				"(archivo existente será sobrescrito)"
		fi
		cp "$ENV_TEMPLATE" "$ENV_FILE"
		if [[ "$SILENT" != "true" ]]; then
			log_success "Recreado $ENV_FILE desde $ENV_TEMPLATE"
		fi
	elif [[ ! -f "$ENV_FILE" ]]; then
		cp "$ENV_TEMPLATE" "$ENV_FILE"
		if [[ "$SILENT" != "true" ]]; then
			log_success "Creado $ENV_FILE desde $ENV_TEMPLATE"
			log_info "Edita $ENV_FILE con tus valores personalizados"
		fi
	else
		if [[ "$SILENT" != "true" ]]; then
			log_info "$ENV_FILE ya existe (usa --force para recrearlo)"
		fi
	fi
}

# Ejecutar función principal
main "$@"
