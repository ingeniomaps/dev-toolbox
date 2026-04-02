#!/usr/bin/env bash
# ============================================================================
# Script: setup-backup-schedule.sh
# Ubicación: scripts/sh/backup/
# ============================================================================
# Configura programación automática de backups usando cron.
#
# Uso:
#   ./scripts/sh/backup/setup-backup-schedule.sh [frecuencia] [servicios]
#
# Parámetros:
#   $1 - (opcional) Frecuencia: daily, weekly, monthly (default: daily)
#   $2 - (opcional) Servicios separados por espacios. Si no se especifica,
#        intenta leer desde BACKUP_SERVICES en .env o usa servicios con
#        variables *_VERSION en .env
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#   BACKUP_SERVICES - Lista de servicios separados por espacios (desde .env)
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

# Cargar helpers comunes
if [[ -f "$COMMON_SCRIPTS_DIR/init.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/init.sh"
	init_script
else
	log_info() { echo "[INFO] $*"; }
	log_warn() { echo "[WARN] $*" >&2; }
	log_error() { echo "[ERROR] $*" >&2; }
	log_success() { echo "[SUCCESS] $*"; }
fi

readonly FREQUENCY="${1:-daily}"

# Determinar servicios: parámetro > .env > detectar desde *_VERSION
if [[ -n "${2:-}" ]]; then
	readonly SERVICES="$2"
elif [[ -f "$PROJECT_ROOT/.env" ]]; then
	# Intentar leer desde BACKUP_SERVICES en .env
	BACKUP_SERVICES_ENV=$(grep "^BACKUP_SERVICES=" "$PROJECT_ROOT/.env" 2>/dev/null | \
		cut -d'=' -f2 | sed 's/^["'\'']//;s/["'\'']$//' || echo "")
	if [[ -n "$BACKUP_SERVICES_ENV" ]]; then
		readonly SERVICES="$BACKUP_SERVICES_ENV"
	else
		# Detectar servicios desde variables *_VERSION en .env
		SERVICES_DETECTED=$(grep -E '^[A-Z_]+_VERSION=' "$PROJECT_ROOT/.env" 2>/dev/null | \
			sed 's/_VERSION=.*//' | tr '[:upper:]' '[:lower:]' | tr '_' '-' | tr '\n' ' ' | sed 's/ $//' || echo "")
		if [[ -n "$SERVICES_DETECTED" ]]; then
			readonly SERVICES="$SERVICES_DETECTED"
		else
			log_warn "No se encontraron servicios. Especifica servicios como parámetro o define BACKUP_SERVICES en .env"
			log_info "Uso: $0 daily 'servicio1 servicio2'"
			exit 1
		fi
	fi
else
	log_warn "No se encontró .env y no se especificaron servicios"
	log_info "Uso: $0 daily 'servicio1 servicio2'"
	exit 1
fi

log_info "Configurando programación de backups: $FREQUENCY"

# Determinar hora según frecuencia
case "$FREQUENCY" in
	daily)
		CRON_TIME="0 2 * * *"
		;;
	weekly)
		CRON_TIME="0 2 * * 0"
		;;
	monthly)
		CRON_TIME="0 2 1 * *"
		;;
	*)
		log_error "Frecuencia no válida: $FREQUENCY"
		log_info "Frecuencias válidas: daily, weekly, monthly"
		exit 1
		;;
esac

# Crear script de backup programado
readonly BACKUP_SCRIPT="$PROJECT_ROOT/scripts/backup-scheduled.sh"
readonly LOGS_DIR="$PROJECT_ROOT/logs"

mkdir -p "$LOGS_DIR"

cat > "$BACKUP_SCRIPT" << 'EOFSCRIPT'
#!/usr/bin/env bash
# Script de backup programado generado automáticamente
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Cargar .env si existe
if [[ -f .env ]]; then
	set -a
	source .env
	set +a
fi

# Ejecutar backups
EOFSCRIPT

for service in $SERVICES; do
	echo "make backup-${service} || echo \"Error en backup de ${service}\"" \
		>> "$BACKUP_SCRIPT"
done

chmod +x "$BACKUP_SCRIPT"

# Crear entrada de cron
readonly CRON_ENTRY="$CRON_TIME cd $PROJECT_ROOT && $BACKUP_SCRIPT >> $LOGS_DIR/backup-scheduled.log 2>&1"

# Verificar si ya existe
if crontab -l 2>/dev/null | grep -q "$BACKUP_SCRIPT"; then
	log_warn "Ya existe una entrada de cron para este script"
	log_info "Elimínala manualmente con: crontab -e"
else
	# Agregar a crontab
	(crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
	log_success "Entrada de cron agregada"
fi

log_info "Configuración completada:"
echo "  - Script: $BACKUP_SCRIPT"
echo "  - Frecuencia: $FREQUENCY"
echo "  - Hora: $CRON_TIME"
echo "  - Servicios: $SERVICES"
echo ""
log_info "Para ver la configuración de cron: crontab -l"
log_info "Para eliminar: crontab -e (editar manualmente)"
