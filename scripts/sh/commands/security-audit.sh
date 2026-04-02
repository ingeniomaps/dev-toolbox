#!/usr/bin/env bash
# ============================================================================
# Script: security-audit.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Realiza auditoría de seguridad del proyecto.
#
# Uso:
#   ./scripts/sh/commands/security-audit.sh [--export=report.json]
#
# Parámetros:
#   --export=<archivo> - (opcional) Exportar reporte a archivo JSON
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#
# Retorno:
#   0 si no se encontraron problemas críticos
#   1 si se encontraron problemas de seguridad
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

# Parsear argumentos
EXPORT_FILE=""
for arg in "$@"; do
	case "$arg" in
		--export=*)
			EXPORT_FILE="${arg#*=}"
			;;
		*)
			;;
	esac
done

ISSUES_FOUND=0
ISSUES_CRITICAL=0
AUDIT_REPORT=()

log_title "AUDITORÍA DE SEGURIDAD"
echo ""

# 1. Verificar secretos hardcodeados
log_info "1. Verificando secretos hardcodeados..."
if [[ -f "$PROJECT_ROOT/.env" ]]; then
	SECRET_PATTERNS="password|secret|token|key|private|credential"
	HARDCODED_RAW=$(grep -iE "$SECRET_PATTERNS" "$PROJECT_ROOT/.env" 2>/dev/null | \
		grep -v "^#" | grep -v "^\s*$" | grep -c . 2>/dev/null || echo "0")
	HARDCODED=$(echo "$HARDCODED_RAW" | tr -d '[:space:]')
	HARDCODED=${HARDCODED:-0}
	HARDCODED=$((HARDCODED + 0))  # Forzar conversión a número

	if [[ $HARDCODED -gt 0 ]]; then
		log_warn "  Encontradas $HARDCODED variables que parecen secretos en .env"
		log_info "  Asegúrate de usar un gestor de secretos (Infisical, etc.)"
		ISSUES_FOUND=$((ISSUES_FOUND + 1))
	fi
else
	log_warn "  .env no encontrado"
fi
echo ""

# 2. Verificar permisos de archivos sensibles
log_info "2. Verificando permisos de archivos sensibles..."
SENSITIVE_FILES=".env .env.* *.key *.pem *.p12"
for pattern in $SENSITIVE_FILES; do
	for file in $PROJECT_ROOT/$pattern; do
		[[ ! -f "$file" ]] && continue
		PERMS=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%OLp" "$file" 2>/dev/null || echo "???")
		if [[ "$PERMS" != "600" ]] && [[ "$PERMS" != "400" ]]; then
			log_warn "  $file tiene permisos $PERMS (recomendado: 600)"
			ISSUES_FOUND=$((ISSUES_FOUND + 1))
		fi
	done
done
echo ""

# 3. Verificar configuración de red
log_info "3. Verificando configuración de red..."
if [[ -n "${NETWORK_NAME:-}" ]]; then
	if docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
		log_success "  Red '${NETWORK_NAME}' configurada correctamente"
	else
		log_warn "  Red '${NETWORK_NAME}' no existe"
		ISSUES_FOUND=$((ISSUES_FOUND + 1))
	fi
else
	log_warn "  NETWORK_NAME no definido"
	ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

# 4. Verificar versiones de servicios
log_info "4. Verificando versiones de servicios..."
ENV_FILE="$PROJECT_ROOT/.env"
if [[ -f "$ENV_FILE" ]]; then
	# Verificar versiones muy antiguas o sin soporte
	OLD_VERSIONS_RAW=$(grep -E "_VERSION=" "$ENV_FILE" 2>/dev/null | \
		grep -E "(^[0-9]\.|^[0-9]$)" | grep -c . 2>/dev/null || echo "0")
	OLD_VERSIONS=$(echo "$OLD_VERSIONS_RAW" | tr -d '[:space:]')
	OLD_VERSIONS=${OLD_VERSIONS:-0}
	OLD_VERSIONS=$((OLD_VERSIONS + 0))  # Forzar conversión a número

	if [[ $OLD_VERSIONS -gt 0 ]]; then
		log_warn "  Algunas versiones pueden ser muy antiguas"
		log_info "  Revisa las versiones en .env"
		ISSUES_FOUND=$((ISSUES_FOUND + 1))
	fi
fi
echo ""

# 5. Verificar que secrets-check se ejecuta
log_info "5. Verificando validación de secretos..."
if make -C "$PROJECT_ROOT" -n secrets-check >/dev/null 2>&1; then
	log_success "  Comando secrets-check disponible"
	AUDIT_REPORT+=('{"category": "secrets-check", "status": "ok", "message": "Comando disponible"}')
else
	log_warn "  Comando secrets-check no disponible"
	ISSUES_FOUND=$((ISSUES_FOUND + 1))
	AUDIT_REPORT+=('{"category": "secrets-check", "status": "warning", "message": "Comando no disponible"}')
fi
echo ""

# 6. Verificar uso de keychain/secrets manager
log_info "6. Verificando gestión de secretos..."
# KEYCHAIN_AVAILABLE está reservado para uso futuro
# KEYCHAIN_AVAILABLE=false
if [[ -f "$COMMON_SCRIPTS_DIR/../utils/keychain.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/../utils/keychain.sh"
	if keychain_available; then
		BACKEND=$(keychain_backend)
		log_success "  Keychain disponible (backend: $BACKEND)"
		AUDIT_REPORT+=("{\"category\": \"keychain\", \"status\": \"ok\", \"backend\": \"$BACKEND\"}")
		# KEYCHAIN_AVAILABLE=true
	else
		log_warn "  Keychain no disponible (instala secret-tool, security, o pass)"
		AUDIT_REPORT+=('{"category": "keychain", "status": "warning", "message": "No disponible"}')
	fi
else
	log_warn "  Script keychain.sh no encontrado"
	AUDIT_REPORT+=('{"category": "keychain", "status": "warning", "message": "Script no encontrado"}')
fi

# Verificar si se usan variables de entorno para tokens de Infisical
if grep -qiE "INFISICAL.*TOKEN" "$PROJECT_ROOT/.env" 2>/dev/null; then
	log_warn "  Tokens de Infisical encontrados en .env (considera usar keychain)"
	ISSUES_FOUND=$((ISSUES_FOUND + 1))
	AUDIT_REPORT+=(
		'{"category": "infisical-tokens", "status": "warning", "message": "Tokens en .env, considerar keychain"}'
	)
fi
echo ""

# 7. Verificar secretos próximos a expirar
log_info "7. Verificando expiración de secretos..."
if [[ -f "$SCRIPT_DIR/check-secrets-expiry.sh" ]]; then
	if bash "$SCRIPT_DIR/check-secrets-expiry.sh" --warn-only --days=30 >/dev/null 2>&1; then
		log_success "  No hay secretos próximos a expirar"
		AUDIT_REPORT+=('{"category": "secrets-expiry", "status": "ok"}')
	else
		log_warn "  Hay secretos próximos a expirar (ejecuta: make check-secrets-expiry)"
		ISSUES_FOUND=$((ISSUES_FOUND + 1))
		AUDIT_REPORT+=('{"category": "secrets-expiry", "status": "warning"}')
	fi
else
	log_warn "  Script check-secrets-expiry.sh no disponible"
fi
echo ""

# 8. Verificar dependencias vulnerables (básico)
log_info "8. Verificando dependencias..."
# Verificar Docker images con versiones conocidas problemáticas
if [[ -f "$ENV_FILE" ]]; then
	VULN_COUNT=0
	while IFS='=' read -r line; do
		if [[ "$line" =~ _VERSION= ]]; then
			VERSION=$(echo "$line" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
			# Verificar versiones muy antiguas (ejemplo básico)
			if echo "$VERSION" | grep -qE "^[0-9]\." && [[ $(echo "$VERSION" | cut -d'.' -f1) -lt 2 ]]; then
				VULN_COUNT=$((VULN_COUNT + 1))
			fi
		fi
	done < "$ENV_FILE"

	if [[ $VULN_COUNT -gt 0 ]]; then
		log_warn "  Se encontraron $VULN_COUNT versiones que pueden ser vulnerables"
		log_info "  Revisa las versiones de servicios en .env"
		ISSUES_FOUND=$((ISSUES_FOUND + 1))
		AUDIT_REPORT+=("{\"category\": \"dependencies\", \"status\": \"warning\", \"vulnerable_versions\": $VULN_COUNT}")
	else
		log_success "  No se detectaron versiones obviamente vulnerables"
		AUDIT_REPORT+=('{"category": "dependencies", "status": "ok"}')
	fi
fi
echo ""

# 9. Verificar configuración de Docker
log_info "9. Verificando configuración de Docker..."
if command -v docker >/dev/null 2>&1; then
	# Verificar que Docker no está ejecutándose como root sin restricciones
	if docker info 2>/dev/null | grep -q "rootless"; then
		log_success "  Docker ejecutándose en modo rootless"
		AUDIT_REPORT+=('{"category": "docker", "status": "ok", "mode": "rootless"}')
	else
		log_warn "  Docker puede estar ejecutándose como root (considera rootless)"
		AUDIT_REPORT+=('{"category": "docker", "status": "warning", "mode": "root"}')
	fi

	# Verificar red por defecto
	if docker network ls | grep -q "bridge"; then
		log_info "  Red bridge detectada"
	fi
else
	log_warn "  Docker no está disponible"
fi
echo ""

# 10. Verificar archivos con información sensible
log_info "10. Verificando archivos con información sensible..."
SENSITIVE_PATTERNS="*.pem *.key *.p12 *.pfx *.jks *.crt *.csr id_rsa id_dsa *.ppk"
FOUND_SENSITIVE=0

for pattern in $SENSITIVE_PATTERNS; do
	while IFS= read -r file; do
		[[ ! -f "$file" ]] && continue

		# Verificar permisos
		PERMS=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%OLp" "$file" 2>/dev/null || echo "???")
		if [[ "$PERMS" != "600" ]] && [[ "$PERMS" != "400" ]]; then
			log_warn "  $file tiene permisos $PERMS (recomendado: 600)"
			FOUND_SENSITIVE=$((FOUND_SENSITIVE + 1))
		fi
	done < <(find "$PROJECT_ROOT" -name "$pattern" -type f 2>/dev/null || true)
done

if [[ $FOUND_SENSITIVE -gt 0 ]]; then
	ISSUES_FOUND=$((ISSUES_FOUND + FOUND_SENSITIVE))
	AUDIT_REPORT+=("{\"category\": \"sensitive-files\", \"status\": \"warning\", \"count\": $FOUND_SENSITIVE}")
else
	log_success "  No se encontraron archivos sensibles con permisos incorrectos"
	AUDIT_REPORT+=('{"category": "sensitive-files", "status": "ok"}')
fi
echo ""

# Resumen
log_title "RESUMEN DE AUDITORÍA"
if [[ $ISSUES_FOUND -eq 0 ]]; then
	log_success "No se encontraron problemas de seguridad"
	FINAL_STATUS="ok"
else
	log_error "Se encontraron $ISSUES_FOUND problemas de seguridad"
	log_info "Revisa los puntos anteriores y corrige los problemas"
	FINAL_STATUS="issues_found"
fi

# Exportar reporte si se solicita
if [[ -n "$EXPORT_FILE" ]]; then
	mkdir -p "$(dirname "$EXPORT_FILE")" 2>/dev/null || true

	{
		echo "{"
		echo "  \"timestamp\": \"$(date -Iseconds)\","
		echo "  \"status\": \"$FINAL_STATUS\","
		echo "  \"issues_found\": $ISSUES_FOUND,"
		echo "  \"issues_critical\": $ISSUES_CRITICAL,"
		echo "  \"checks\": ["
		for i in "${!AUDIT_REPORT[@]}"; do
			if [[ $i -gt 0 ]]; then
				echo ","
			fi
			echo -n "    ${AUDIT_REPORT[$i]}"
		done
		echo ""
		echo "  ]"
		echo "}"
	} > "$EXPORT_FILE"

	log_info "Reporte exportado a: $EXPORT_FILE"
fi

if [[ $ISSUES_FOUND -eq 0 ]]; then
	exit 0
else
	exit 1
fi
