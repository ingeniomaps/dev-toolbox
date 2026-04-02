#!/usr/bin/env bash
# ============================================================================
# Script: create-service.sh
# Ubicación: scripts/sh/setup/
# ============================================================================
# Crea la estructura base para un nuevo servicio en el proyecto.
#
# Uso:
#   ./scripts/sh/setup/create-service.sh <service-name>
#
# Parámetros:
#   $1 - Nombre del servicio a crear (ej: elasticsearch, rabbitmq)
#
# Variables de entorno:
#   PROJECT_ROOT - Raíz del proyecto (default: $(pwd))
#
# Retorno:
#   0 si la estructura se crea exitosamente
#   1 si hay errores
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

if [[ $# -lt 1 ]]; then
	log_error "Debes especificar el nombre del servicio"
	log_info "Uso: $0 <service-name>"
	exit 1
fi

readonly SERVICE_NAME="$1"
readonly SERVICE_DIR="$PROJECT_ROOT/containers/$SERVICE_NAME"

if [[ -z "$SERVICE_NAME" ]]; then
	log_error "El nombre del servicio no puede estar vacío"
	exit 1
fi

if [[ -d "$SERVICE_DIR" ]]; then
	log_error "El servicio '$SERVICE_NAME' ya existe en $SERVICE_DIR"
	exit 1
fi

log_info "Creando estructura para servicio '$SERVICE_NAME'..."

# Crear directorios
mkdir -p "$SERVICE_DIR"/{scripts,tests,config,docs}
log_success "Directorios creados"

# Crear docker-compose.yml básico
cat > "$SERVICE_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  SERVICE_NAME:
    image: SERVICE_NAME:latest
    container_name: ${SERVICE_PREFIX:+${SERVICE_PREFIX}-}SERVICE_NAME
    restart: ${SERVICE_RESTART_POLICY:-always}
    env_file:
      - ../.env
    networks:
      - ${NETWORK_NAME:-mynetwork}
    healthcheck:
      test: ["CMD-SHELL", "echo 'Healthcheck no configurado' || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 30s

networks:
  ${NETWORK_NAME:-mynetwork}:
    external: true
EOF
sed -i "s/SERVICE_NAME/$SERVICE_NAME/g" "$SERVICE_DIR/docker-compose.yml"
log_success "docker-compose.yml creado"

# Crear Makefile básico
cat > "$SERVICE_DIR/Makefile" << 'EOF'
# Makefile para SERVICE_NAME
SERVICE_DIR := $(PROJECT_ROOT)containers/SERVICE_NAME
SERVICE_ENV := $(PROJECT_ROOT).env
SERVICE_COMPOSE_CMD := docker compose --env-file "$(SERVICE_ENV)" -f "$(SERVICE_DIR)/docker-compose.yml"

# Nombres de contenedores
SERVICE_CONTAINER_NAME := $(shell if [ -n "$(SERVICE_PREFIX)" ]; then \
	echo "$(SERVICE_PREFIX)-SERVICE_NAME"; else echo "SERVICE_NAME"; fi)

# Comandos base
check-prerequisites: ## Verifica prerrequisitos [SERVICE_TAG]
	@command -v docker >/dev/null 2>&1 || { \
		echo "Error: Docker no está instalado"; \
		exit 1; \
	}

deploy-local: check-prerequisites ## Despliega el servicio localmente [SERVICE_TAG]
	@echo "Desplegando SERVICE_NAME..."
	@cd "$(SERVICE_DIR)" && $(SERVICE_COMPOSE_CMD) up -d
	@echo "✓ SERVICE_NAME desplegado"

down-SERVICE_NAME: check-prerequisites ## Detiene el servicio [SERVICE_TAG]
	@cd "$(SERVICE_DIR)" && $(SERVICE_COMPOSE_CMD) down

logs-SERVICE_NAME: check-prerequisites ## Ver logs del servicio [SERVICE_TAG]
	@cd "$(SERVICE_DIR)" && $(SERVICE_COMPOSE_CMD) logs -f

status-SERVICE_NAME: check-prerequisites ## Ver estado del servicio [SERVICE_TAG]
	@docker ps --filter "name=$(SERVICE_CONTAINER_NAME)" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

health-SERVICE_NAME: check-prerequisites ## Verificar salud del servicio [SERVICE_TAG]
	@docker inspect --format='{{.State.Health.Status}}' "$(SERVICE_CONTAINER_NAME)" 2>/dev/null || echo "no_healthcheck"
EOF
sed -i "s/SERVICE_NAME/$SERVICE_NAME/g" "$SERVICE_DIR/Makefile"
SERVICE_TAG=$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]')
sed -i "s/SERVICE_TAG/$SERVICE_TAG/g" "$SERVICE_DIR/Makefile"
log_success "Makefile creado"

# Crear README.md básico
cat > "$SERVICE_DIR/README.md" << EOF
# $SERVICE_NAME

Descripción del servicio $SERVICE_NAME.

## Inicio Rápido

\`\`\`bash
make deploy-local
\`\`\`

## Comandos Disponibles

- \`make deploy-local\` - Despliega el servicio localmente
- \`make down-$SERVICE_NAME\` - Detiene el servicio
- \`make logs-$SERVICE_NAME\` - Ver logs del servicio
- \`make status-$SERVICE_NAME\` - Ver estado del servicio
- \`make health-$SERVICE_NAME\` - Verificar salud del servicio

## Configuración

Edita \`docker-compose.yml\` para configurar el servicio.

## Documentación

Ver documentación adicional en \`docs/\`.
EOF
log_success "README.md creado"

# Crear .gitignore básico
cat > "$SERVICE_DIR/.gitignore" << 'EOF'
*.log
.env
.env.local
*.tmp
EOF
log_success ".gitignore creado"

# Crear .env-template básico
cat > "$SERVICE_DIR/.env-template" << EOF
# Configuración para $SERVICE_NAME
${SERVICE_NAME^^}_HOST=101.80.1.X
${SERVICE_NAME^^}_CPU_LIMIT=2.0
${SERVICE_NAME^^}_MEMORY_LIMIT=2g
${SERVICE_NAME^^}_RESTART_POLICY=always
EOF
log_success ".env-template creado"

echo ""
log_success "Estructura base creada para '$SERVICE_NAME' en $SERVICE_DIR"
echo ""
log_info "Próximos pasos:"
echo "  1. Edita $SERVICE_DIR/docker-compose.yml con la configuración del servicio"
echo "  2. Agrega comandos específicos en $SERVICE_DIR/Makefile"
echo "  3. Documenta el servicio en $SERVICE_DIR/README.md"
	echo "  4. Agrega el servicio al Makefile principal si es necesario" \
		""
echo ""
