#!/usr/bin/env bash
# ============================================================================
# Script: backup-all.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Realiza backup de todos los servicios detectados desde variables *_VERSION
# en .env. Soporta ejecución en paralelo para mejorar performance.
#
# Uso:
#   ./scripts/sh/commands/backup-all.sh [--skip-missing] [--parallel] [--max-parallel=N]
#
# Opciones:
#   --skip-missing  - Continuar con otros servicios si uno no existe o falla
#   --parallel      - Ejecutar backups en paralelo (default: secuencial)
#   --max-parallel=N - Máximo número de backups paralelos (default: número de CPUs)
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   SKIP_MISSING - true: continuar si servicios no existen (equivalente a --skip-missing)
#   PARALLEL - true: ejecutar en paralelo (equivalente a --parallel)
#   MAX_PARALLEL - Número máximo de backups paralelos (equivalente a --max-parallel)
#
# Ejemplos:
#   # Backup secuencial (default)
#   ./scripts/sh/commands/backup-all.sh
#
#   # Backup en paralelo (todos a la vez)
#   ./scripts/sh/commands/backup-all.sh --parallel
#
#   # Backup en paralelo con máximo 3 simultáneos
#   ./scripts/sh/commands/backup-all.sh --parallel --max-parallel=3
#
# Retorno:
#   0 si todos los backups fueron exitosos
#   1 si algún backup falló (o 0 si --skip-missing está activo)
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

# Cargar validation.sh para validar prerrequisitos
if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

# Cargar helper de servicios si está disponible
if [[ -f "$COMMON_SCRIPTS_DIR/services.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/services.sh"
fi

# Parsear argumentos
SKIP_MISSING=false
PARALLEL=false
MAX_PARALLEL=""

for arg in "$@"; do
	case "$arg" in
		--skip-missing)
			SKIP_MISSING=true
			;;
		--parallel)
			PARALLEL=true
			;;
		--max-parallel=*)
			MAX_PARALLEL="${arg#*=}"
			PARALLEL=true  # Activar paralelo si se especifica max-parallel
			;;
		*)
			log_warn "Argumento desconocido: $arg"
			;;
	esac
done

# Verificar variables de entorno
if [[ "${SKIP_MISSING_ENV:-}" == "true" ]] || [[ "${SKIP_MISSING:-}" == "true" ]]; then
	SKIP_MISSING=true
fi

if [[ "${PARALLEL_ENV:-}" == "true" ]] || [[ "${PARALLEL:-}" == "true" ]]; then
	PARALLEL=true
fi

if [[ -n "${MAX_PARALLEL_ENV:-}" ]]; then
	MAX_PARALLEL="${MAX_PARALLEL_ENV}"
	PARALLEL=true
fi

# Determinar número máximo de jobs paralelos
if [[ "$PARALLEL" == "true" ]]; then
	if [[ -n "$MAX_PARALLEL" ]]; then
		# Validar que sea un número positivo
		if ! [[ "$MAX_PARALLEL" =~ ^[0-9]+$ ]] || [[ "$MAX_PARALLEL" -lt 1 ]]; then
			log_error "MAX_PARALLEL debe ser un número positivo: $MAX_PARALLEL"
			exit 1
		fi
		MAX_JOBS="$MAX_PARALLEL"
	else
		# Detectar número de CPUs disponibles
		if command -v nproc >/dev/null 2>&1; then
			MAX_JOBS=$(nproc)
		elif command -v sysctl >/dev/null 2>&1; then
			MAX_JOBS=$(sysctl -n hw.ncpu 2>/dev/null || echo "4")
		else
			MAX_JOBS=4  # Fallback conservador
		fi
	fi
	log_info "Modo paralelo activado: máximo $MAX_JOBS backups simultáneos"
else
	MAX_JOBS=1
fi

readonly ENV_FILE="$PROJECT_ROOT/.env"

# Validar que .env existe
if ! validate_env_file "$ENV_FILE"; then
	log_error "No se puede realizar backup sin archivo .env"
	exit 1
fi

log_step "Realizando backup de todos los servicios..."

# Usar helper común para detectar servicios
if command -v detect_services_from_env >/dev/null 2>&1; then
	SERVICES_LIST=$(detect_services_from_env "$ENV_FILE")
else
	# Fallback si helper no está disponible
	SERVICES_LIST=$(grep -E '^[A-Z_]+_VERSION=' "$ENV_FILE" 2>/dev/null | \
		sed 's/_VERSION=.*//' | tr '[:upper:]' '[:lower:]' | \
		tr '_' '-' | tr '\n' ' ' || echo "")
fi

if [[ -z "$SERVICES_LIST" ]]; then
	log_warn "No se encontraron servicios con *_VERSION en .env"
	exit 0
fi

EXIT_CODE=0
SUCCESS_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0

# Array para almacenar resultados de backups paralelos
declare -A BACKUP_RESULTS
declare -A BACKUP_PIDS

# Función para ejecutar backup de un servicio
# Parámetros:
#   $1 - Nombre del servicio
# Retorna: 0 si exitoso, 1 si falló
execute_backup() {
	local service="$1"
	local backup_exit_code=0
	local log_file

	# Crear archivo de log temporal para este backup (solo en modo paralelo)
	if [[ "$PARALLEL" == "true" ]]; then
		log_file=$(mktemp "/tmp/backup-${service}-XXXXXX.log")
		exec 3>&1 4>&2
		exec 1>>"$log_file" 2>&1
	fi

	# Verificar si el servicio existe
	if ! command -v service_exists >/dev/null 2>&1 || \
		! service_exists "$service" "backup" "$PROJECT_ROOT"; then
		if [[ "$SKIP_MISSING" == "true" ]]; then
			log_warn "[$service] Servicio no encontrado (omitido)"
			backup_exit_code=2  # Código especial para "omitido"
		else
			log_error "[$service] Servicio no encontrado"
			log_info "[$service] 💡 Sugerencia: Usa --skip-missing para continuar"
			backup_exit_code=1
		fi

		if [[ "$PARALLEL" == "true" ]]; then
			exec 1>&3 2>&4
			rm -f "$log_file"
		fi

		BACKUP_RESULTS["$service"]=$backup_exit_code
		return $backup_exit_code
	fi

	# Verificar si el comando make está disponible
	if ! make -C "$PROJECT_ROOT" -n "backup-${service}" >/dev/null 2>&1; then
		if [[ "$SKIP_MISSING" == "true" ]]; then
			log_warn "[$service] Comando backup-${service} no disponible (omitido)"
			backup_exit_code=2  # Código especial para "omitido"
		else
			log_warn "[$service] Comando backup-${service} no disponible"
			backup_exit_code=1
		fi

		if [[ "$PARALLEL" == "true" ]]; then
			exec 1>&3 2>&4
			rm -f "$log_file"
		fi

		BACKUP_RESULTS["$service"]=$backup_exit_code
		return $backup_exit_code
	fi

	# Intentar backup
	log_info "[$service] Iniciando backup..."
	if make -C "$PROJECT_ROOT" "backup-${service}" 2>&1; then
		log_success "[$service] Backup completado exitosamente"
		backup_exit_code=0
	else
		if [[ "$SKIP_MISSING" == "true" ]]; then
			log_error "[$service] Backup falló (continuando...)"
		else
			log_error "[$service] Backup falló"
		fi
		backup_exit_code=1
	fi

	# Restaurar stdout/stderr y mostrar logs en modo paralelo
	if [[ "$PARALLEL" == "true" ]]; then
		exec 1>&3 2>&4

		# Mostrar logs del backup
		if [[ -f "$log_file" ]]; then
			log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
			log_info "📦 Backup de $service:"
			cat "$log_file"
			log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
			rm -f "$log_file"
		fi

		# Mostrar resultado
		if [[ $backup_exit_code -eq 0 ]]; then
			log_success "✅ Backup de $service completado"
		elif [[ $backup_exit_code -eq 2 ]]; then
			log_warn "⏭️  Backup de $service omitido"
		else
			log_error "❌ Backup de $service falló"
		fi
	fi

	BACKUP_RESULTS["$service"]=$backup_exit_code
	return $backup_exit_code
}

# Ejecutar backups (secuencial o paralelo)
if [[ "$PARALLEL" == "true" ]]; then
	# Modo paralelo: usar jobs de bash
	log_step "Ejecutando backups en paralelo (máximo $MAX_JOBS simultáneos)..."

	ACTIVE_JOBS=0

	for service in $SERVICES_LIST; do
		# Esperar si ya hay MAX_JOBS ejecutándose
		while [[ $ACTIVE_JOBS -ge $MAX_JOBS ]]; do
			# Esperar a que termine cualquier job
			wait -n 2>/dev/null || true

			# Recontar jobs activos
			ACTIVE_JOBS=0
			for pid in "${BACKUP_PIDS[@]}"; do
				if kill -0 "$pid" 2>/dev/null; then
					ACTIVE_JOBS=$((ACTIVE_JOBS + 1))
				fi
			done
		done

		# Iniciar backup en background
		execute_backup "$service" &
		BACKUP_PIDS["$service"]=$!
		ACTIVE_JOBS=$((ACTIVE_JOBS + 1))

		log_info "🚀 Backup de $service iniciado (PID: ${BACKUP_PIDS[$service]})"
	done

	# Esperar a que terminen todos los jobs
	log_info "Esperando a que terminen todos los backups..."
	for service in "${!BACKUP_PIDS[@]}"; do
		pid="${BACKUP_PIDS[$service]}"
		if wait "$pid" 2>/dev/null; then
			# Job terminó exitosamente
			:
		else
			# Job falló o fue terminado
			wait "$pid" 2>/dev/null || true
		fi
	done

	# Procesar resultados
	for service in "${!BACKUP_RESULTS[@]}"; do
		result="${BACKUP_RESULTS[$service]}"
		case "$result" in
			0)
				SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
				;;
			1)
				FAILED_COUNT=$((FAILED_COUNT + 1))
				if [[ "$SKIP_MISSING" != "true" ]]; then
					EXIT_CODE=1
				fi
				;;
			2)
				SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
				;;
		esac
	done
else
	# Modo secuencial (comportamiento original)
	log_step "Ejecutando backups secuencialmente..."

	for service in $SERVICES_LIST; do
		# Verificar si el servicio existe
		if ! command -v service_exists >/dev/null 2>&1 || \
			! service_exists "$service" "backup" "$PROJECT_ROOT"; then
			if [[ "$SKIP_MISSING" == "true" ]]; then
				log_warn "Servicio $service no encontrado (omitido)"
				SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
				continue
			else
				log_error "Servicio $service no encontrado"
				log_info "💡 Sugerencia: Usa --skip-missing para continuar con otros servicios"
				EXIT_CODE=1
				FAILED_COUNT=$((FAILED_COUNT + 1))
				continue
			fi
		fi

		# Verificar si el comando make está disponible
		if ! make -C "$PROJECT_ROOT" -n "backup-${service}" >/dev/null 2>&1; then
			if [[ "$SKIP_MISSING" == "true" ]]; then
				log_warn "Comando backup-${service} no disponible (omitido)"
				SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
				continue
			else
				log_warn "Comando backup-${service} no disponible"
				EXIT_CODE=1
				FAILED_COUNT=$((FAILED_COUNT + 1))
				continue
			fi
		fi

		# Intentar backup
		log_info "Backup de $service..."
		if make -C "$PROJECT_ROOT" "backup-${service}" 2>&1; then
			log_success "Backup de $service completado"
			SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
		else
			if [[ "$SKIP_MISSING" == "true" ]]; then
				log_error "Backup de $service falló (continuando...)"
				FAILED_COUNT=$((FAILED_COUNT + 1))
			else
				log_error "Backup de $service falló"
				EXIT_CODE=1
				FAILED_COUNT=$((FAILED_COUNT + 1))
			fi
		fi
	done
fi

echo ""
log_info "Resumen: $SUCCESS_COUNT exitosos, $FAILED_COUNT fallidos, $SKIPPED_COUNT omitidos"

if [[ $EXIT_CODE -eq 0 ]] && [[ $SUCCESS_COUNT -gt 0 ]]; then
	log_success "Backup completado exitosamente"
	exit 0
elif [[ "$SKIP_MISSING" == "true" ]] && [[ $SUCCESS_COUNT -gt 0 ]]; then
	log_warn "Backup completado con algunos fallos (modo --skip-missing)"
	exit 0
else
	log_error "Algunos backups fallaron"
	exit 1
fi
