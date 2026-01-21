#!/usr/bin/env bash
# ============================================================================
# Script: backup-storage.sh
# Ubicación: scripts/sh/backup/
# ============================================================================
# Almacena backups en diferentes backends (local, S3, GCS, Azure).
#
# Uso:
#   ./scripts/sh/backup/backup-storage.sh <archivo_backup> <backend> [opciones]
#
# Parámetros:
#   $1 - Archivo de backup a almacenar
#   $2 - Backend: local, s3, gcs, azure (default: local)
#
# Variables de entorno:
#   BACKUP_S3_BUCKET - Bucket de S3 (default: backups)
#   BACKUP_S3_PATH - Ruta en S3 (default: nombre del archivo)
#   BACKUP_GCS_BUCKET - Bucket de GCS (default: backups)
#   BACKUP_GCS_PATH - Ruta en GCS (default: nombre del archivo)
#   BACKUP_AZURE_CONTAINER - Contenedor de Azure (default: backups)
#   BACKUP_AZURE_PATH - Ruta en Azure (default: nombre del archivo)
#   PROJECT_ROOT - Raíz del proyecto (opcional)
#
# Retorno:
#   0 si el almacenamiento fue exitoso
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

if [[ -f "$COMMON_SCRIPTS_DIR/validation.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/validation.sh"
fi

# Validar argumentos usando helper
if ! validate_required_args 1 "$0 <archivo_backup> [backend]" "$@"; then
	log_info "Backends: local, s3, gcs, azure"
	exit 1
fi

readonly BACKUP_FILE="$1"
readonly BACKEND="${2:-local}"

# Validar que el archivo existe usando helper
if ! validate_file_exists "$BACKUP_FILE" "Archivo de backup"; then
	exit 1
fi

log_info "Almacenando backup en backend: $BACKEND"

case "$BACKEND" in
	local)
		log_success "Backup almacenado localmente en: $BACKUP_FILE"
		;;
	s3)
		if ! command -v aws >/dev/null 2>&1; then
			log_error "AWS CLI no está instalado"
			log_info "Instala con: pip install awscli o apt-get install awscli"
			exit 1
		fi
		readonly S3_BUCKET="${BACKUP_S3_BUCKET:-backups}"
		readonly S3_PATH="${BACKUP_S3_PATH:-$(basename "$BACKUP_FILE")}"
		log_info "Subiendo a S3: s3://$S3_BUCKET/$S3_PATH"
		if aws s3 cp "$BACKUP_FILE" "s3://$S3_BUCKET/$S3_PATH"; then
			log_success "Backup almacenado en S3: s3://$S3_BUCKET/$S3_PATH"
		else
			log_error "Error al subir a S3"
			exit 1
		fi
		;;
	gcs)
		if ! command -v gsutil >/dev/null 2>&1; then
			log_error "gsutil no está instalado"
			log_info "Instala Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
			exit 1
		fi
		readonly GCS_BUCKET="${BACKUP_GCS_BUCKET:-backups}"
		readonly GCS_PATH="${BACKUP_GCS_PATH:-$(basename "$BACKUP_FILE")}"
		log_info "Subiendo a GCS: gs://$GCS_BUCKET/$GCS_PATH"
		if gsutil cp "$BACKUP_FILE" "gs://$GCS_BUCKET/$GCS_PATH"; then
			log_success "Backup almacenado en GCS: gs://$GCS_BUCKET/$GCS_PATH"
		else
			log_error "Error al subir a GCS"
			exit 1
		fi
		;;
	azure)
		if ! command -v az >/dev/null 2>&1; then
			log_error "Azure CLI no está instalado"
			log_info "Instala con: https://docs.microsoft.com/cli/azure/install-azure-cli"
			exit 1
		fi
		readonly AZURE_CONTAINER="${BACKUP_AZURE_CONTAINER:-backups}"
		readonly AZURE_PATH="${BACKUP_AZURE_PATH:-$(basename "$BACKUP_FILE")}"
		log_info "Subiendo a Azure: $AZURE_CONTAINER/$AZURE_PATH"
		if az storage blob upload \
			--container-name "$AZURE_CONTAINER" \
			--name "$AZURE_PATH" \
			--file "$BACKUP_FILE" >/dev/null 2>&1; then
			log_success "Backup almacenado en Azure: $AZURE_CONTAINER/$AZURE_PATH"
		else
			log_error "Error al subir a Azure"
			exit 1
		fi
		;;
	*)
		log_error "Backend no soportado: $BACKEND"
		log_info "Backends soportados: local, s3, gcs, azure"
		exit 1
		;;
esac
