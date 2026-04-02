#!/usr/bin/env bash
# ============================================================================
# Script: ensure-network.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Crea o verifica una red Docker. Lee NETWORK_NAME y NETWORK_IP de .env o entorno.
#
# Uso:
#   ./scripts/sh/utils/ensure-network.sh [--recreate]
#   make network-tool
#   make network-tool RECREATE=true
#
# Opciones:
#   --recreate  - Recrea la red si existe con configuración diferente
#
# Variables de entorno requeridas:
#   NETWORK_NAME: Nombre de la red Docker a crear/verificar
#   NETWORK_IP: Dirección IP base para calcular el subnet (ej: 101.80.0.0)
#   RECREATE: true para recrear red si existe con configuración diferente
#
# Retorno:
#   0 si la red existe o se creó correctamente
#   1 si faltan variables o error al crear
#
# Priorización: env vars > .env. No usa valores por defecto.
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Calcular rutas
_network_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly NETWORK_DIR="$_network_dir"
unset _network_dir
readonly PROJECT_ROOT="$NETWORK_DIR/.."
readonly NETWORK_ENV="$PROJECT_ROOT/.env"

# Cargar sistema de logging
readonly COMMON_SCRIPTS_DIR="$NETWORK_DIR/../common"
if [[ -f "$COMMON_SCRIPTS_DIR/logging.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/logging.sh"
fi

# Cargar validation.sh si está disponible
if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

# Cargar módulos de red
source "$NETWORK_DIR/network-utils.sh"
source "$NETWORK_DIR/network-validation.sh"
source "$NETWORK_DIR/network-ensure.sh"

# Parsear argumentos
RECREATE_NETWORK=false
for arg in "$@"; do
	case "$arg" in
		--recreate)
			RECREATE_NETWORK=true
			;;
		*)
			log_warn "Argumento desconocido: $arg"
			;;
	esac
done

# Verificar variable de entorno
if [[ "${RECREATE:-}" == "true" ]] || [[ "${RECREATE_NETWORK:-}" == "true" ]]; then
	RECREATE_NETWORK=true
fi

# Cargar variables de entorno con priorización:
# 1. Variables ya definidas en el entorno (pasadas por servicios)
# 2. Variables desde .env principal (si no están definidas y el archivo existe)
# NOTA: No creamos .env automáticamente. Si no existe, debe generarse un error.
if [[ -f "$NETWORK_ENV" ]]; then
	# Cargar .env principal, pero solo las variables que no estén ya definidas
	set -a
	# Leer .env línea por línea para no sobrescribir variables existentes
	while IFS= read -r line || [[ -n "$line" ]]; do
		# Ignorar comentarios y líneas vacías
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		[[ -z "${line// }" ]] && continue

		# Extraer nombre de variable
		if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)= ]]; then
			var_name="${BASH_REMATCH[1]}"
			# Solo cargar si la variable no está ya definida
			if [[ -z "${!var_name:-}" ]]; then
				eval "$line"
			fi
		fi
	done < "$NETWORK_ENV"
	set +a
fi

# Validar que las variables requeridas estén definidas
# Pueden venir del entorno (pasadas por servicios) o del .env principal
# Si no están definidas, generar error (no usar valores por defecto)
if [[ -z "${NETWORK_NAME:-}" ]]; then
	if [[ -f "$NETWORK_ENV" ]]; then
		log_error "NETWORK_NAME no está definido"
		log_info "Define NETWORK_NAME en $NETWORK_ENV o pásalo como variable de entorno"
	else
		log_error "NETWORK_NAME no está definido"
		log_error "Define NETWORK_NAME en $NETWORK_ENV (el archivo debe existir)" \
			"o pásalo como variable de entorno"
	fi
	exit 1
fi

if [[ -z "${NETWORK_IP:-}" ]]; then
	if [[ -f "$NETWORK_ENV" ]]; then
		log_error "NETWORK_IP no está definido"
		log_info "Define NETWORK_IP en $NETWORK_ENV o pásalo como variable de entorno"
	else
		log_error "NETWORK_IP no está definido"
		log_error "Define NETWORK_IP en $NETWORK_ENV (el archivo debe existir)" \
			"o pásalo como variable de entorno"
	fi
	exit 1
fi

# Crear o verificar la red Docker
ensure_docker_network "$NETWORK_NAME" "$NETWORK_IP" "$RECREATE_NETWORK"
