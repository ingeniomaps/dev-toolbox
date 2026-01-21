# Guía de Integración - dev-toolbox

> Guía completa para integrar dev-toolbox en tus proyectos como dependencia

**Tiempo estimado**: 15-30 minutos  
**Nivel**: Intermedio

---

## 📋 Tabla de Contenidos

- [Introducción](#introducción)
- [Requisitos Previos](#requisitos-previos)
- [Métodos de Integración](#métodos-de-integración)
- [Integración en Proyecto Nuevo](#integración-en-proyecto-nuevo)
- [Migración desde Proyecto Existente](#migración-desde-proyecto-existente)
- [Variables de Entorno](#variables-de-entorno)
- [Troubleshooting](#troubleshooting)
- [Mejores Prácticas](#mejores-prácticas)

---

## 🎯 Introducción

Esta guía te ayudará a integrar **dev-toolbox** en tus proyectos, ya sea un proyecto nuevo o uno existente. dev-toolbox puede ser incluido como dependencia de múltiples formas, dependiendo de tus necesidades.

### ¿Por qué integrar dev-toolbox?

- ✅ **Comandos consistentes** en todos tus proyectos
- ✅ **Automatización** de tareas repetitivas
- ✅ **Validación** automática de configuración
- ✅ **Backups y restauraciones** simplificadas
- ✅ **Monitoreo** integrado de servicios
- ✅ **Onboarding rápido** para nuevos desarrolladores

---

## 📦 Requisitos Previos

Antes de integrar dev-toolbox, asegúrate de tener:

### Software Requerido

- **Docker** (versión 20.10 o superior)
- **Docker Compose** (versión 1.29 o superior, o Docker Compose V2)
- **Bash** (versión 4.0 o superior)
- **Make** (GNU Make 3.81 o superior)
- **Git** (para clonar o usar como submódulo)

### Verificar Requisitos

```bash
# Verificar que todo esté instalado
docker --version
docker compose version  # o docker-compose --version
bash --version
make --version
git --version
```

---

## 🔗 Métodos de Integración

dev-toolbox puede integrarse en tu proyecto de tres formas diferentes:

### Método 1: Submódulo Git (Recomendado) ⭐

**Ideal para**: Proyectos que necesitan una versión específica y controlada de dev-toolbox.

**Ventajas**:
- ✅ Versión específica controlada por Git
- ✅ Fácil de actualizar con `git submodule update`
- ✅ No requiere tokens de acceso
- ✅ Versionado junto con tu proyecto

**Desventajas**:
- ⚠️ Requiere conocimiento de Git submódulos
- ⚠️ Los colaboradores deben inicializar submódulos

### Método 2: load-toolbox (Automático)

**Ideal para**: Proyectos que quieren la última versión o una versión específica automáticamente.

**Ventajas**:
- ✅ Actualización automática
- ✅ No requiere Git submódulos
- ✅ Puede especificar rama o tag

**Desventajas**:
- ⚠️ Requiere tokens de GitHub (GIT_USER, GIT_TOKEN)
- ⚠️ Depende de acceso al repositorio

### Método 3: Copia Directa (No Recomendado)

**Ideal para**: Solo si necesitas modificar dev-toolbox específicamente para tu proyecto.

**Ventajas**:
- ✅ Control total sobre el código

**Desventajas**:
- ❌ Difícil mantener actualizaciones
- ❌ No se beneficia de mejoras del proyecto principal
- ❌ Duplicación de código

---

## 🆕 Integración en Proyecto Nuevo

### Escenario: Proyecto desde Cero

Vamos a crear un proyecto nuevo e integrar dev-toolbox desde el inicio.

#### Paso 1: Crear Estructura del Proyecto

```bash
# Crear directorio del proyecto
mkdir mi-proyecto
cd mi-proyecto

# Inicializar Git
git init

# Crear estructura básica
mkdir -p src
touch docker-compose.yml
touch Makefile
touch .gitignore
```

#### Paso 2: Integrar dev-toolbox (Método 1: Submódulo)

```bash
# Agregar dev-toolbox como submódulo
git submodule add https://github.com/ingeniomaps/dev-toolbox.git .toolbox

# Inicializar submódulo
git submodule update --init --recursive
```

#### Paso 3: Configurar Makefile Principal

Crea o edita el `Makefile` de tu proyecto:

```makefile
# ============================================================================
# Makefile Principal del Proyecto
# ============================================================================

# Variables del proyecto
PROJECT_ROOT := $(CURDIR)
TOOLBOX_ROOT := .toolbox/

# Incluir dev-toolbox
include .toolbox/Makefile

# ============================================================================
# Comandos Específicos del Proyecto
# ============================================================================

.PHONY: setup
setup: ## Configura el proyecto completo
	@echo "🚀 Configurando proyecto..."
	@$(MAKE) init-env
	@$(MAKE) setup-env
	@echo "✅ Proyecto configurado correctamente"

.PHONY: start-project
start-project: ## Inicia el proyecto completo
	@echo "🚀 Iniciando proyecto..."
	@$(MAKE) validate
	@$(MAKE) start
	@echo "✅ Proyecto iniciado correctamente"

.PHONY: deploy
deploy: ## Despliega el proyecto (validación + backup + build + start)
	@echo "🚀 Desplegando proyecto..."
	@$(MAKE) validate
	@$(MAKE) backup-all
	@$(MAKE) build
	@$(MAKE) start
	@echo "✅ Proyecto desplegado correctamente"

.PHONY: test
test: ## Ejecuta tests del proyecto
	@echo "🧪 Ejecutando tests..."
	@# Aquí van tus comandos de test
	@echo "✅ Tests completados"
```

#### Paso 4: Crear docker-compose.yml

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:${POSTGRES_VERSION:-18}
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-mydb}
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
    ports:
      - "${POSTGRES_PORT:-5432}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - ${NETWORK_NAME:-dev-toolbox}

volumes:
  postgres_data:

networks:
  ${NETWORK_NAME:-dev-toolbox}:
    external: true
```

#### Paso 5: Crear .env-template

```bash
# Network
NETWORK_NAME=mi-proyecto
NETWORK_IP=172.20.0.0

# Services
POSTGRES_VERSION=18
POSTGRES_DB=mydb
POSTGRES_USER=postgres
POSTGRES_PASSWORD=changeme
POSTGRES_PORT=5432
```

#### Paso 6: Configurar .gitignore

```gitignore
# Entorno
.env
.env.local
.env.*.local

# Toolbox (si usas copia directa)
.toolbox/

# Docker
*.log

# IDE
.vscode/
.idea/
*.swp
*.swo
```

#### Paso 7: Inicializar y Verificar

```bash
# Inicializar entorno
make setup

# Verificar que todo funciona
make validate
make help-toolbox

# Iniciar servicios
make start
```

#### Paso 8: Commit Inicial

```bash
git add .
git commit -m "feat: inicializar proyecto con dev-toolbox"
```

### Ejemplo Completo: Proyecto Node.js + PostgreSQL

```bash
# Estructura final
mi-proyecto/
├── .toolbox/              # dev-toolbox (submódulo)
│   ├── Makefile
│   ├── makefiles/
│   └── scripts/
├── src/                   # Código fuente
│   └── index.js
├── .env-template          # Plantilla de variables
├── .gitignore
├── docker-compose.yml
├── Makefile               # Makefile principal
└── package.json
```

**Makefile del proyecto**:
```makefile
PROJECT_ROOT := $(CURDIR)
TOOLBOX_ROOT := .toolbox/
include .toolbox/Makefile

.PHONY: dev
dev: start
	@echo "✅ Entorno de desarrollo listo"
	@echo "📝 Ejecuta: npm install (si es necesario)"
```

**Uso**:
```bash
make setup      # Configura todo
make dev        # Inicia servicios
make validate   # Valida configuración
make backup-all # Hace backup
```

---

## 🔄 Migración desde Proyecto Existente

### Escenario: Proyecto con Docker Compose Existente

Vamos a migrar un proyecto que ya usa Docker Compose.

#### Paso 1: Evaluar Proyecto Actual

```bash
# Revisar estructura actual
ls -la
cat docker-compose.yml
cat Makefile  # si existe
```

#### Paso 2: Backup del Estado Actual

```bash
# Crear backup de configuración actual
mkdir -p .backup-migration
cp docker-compose.yml .backup-migration/
cp .env .backup-migration/ 2>/dev/null || true
cp Makefile .backup-migration/ 2>/dev/null || true
```

#### Paso 3: Integrar dev-toolbox

```bash
# Agregar como submódulo
git submodule add https://github.com/ingeniomaps/dev-toolbox.git .toolbox
git submodule update --init --recursive
```

#### Paso 4: Adaptar Makefile Existente

Si ya tienes un `Makefile`, incluye dev-toolbox:

```makefile
# ============================================================================
# Makefile Existente - Ahora con dev-toolbox
# ============================================================================

PROJECT_ROOT := $(CURDIR)
TOOLBOX_ROOT := .toolbox/

# Incluir dev-toolbox (agregar al inicio)
include .toolbox/Makefile

# ============================================================================
# Tus comandos existentes (mantener compatibilidad)
# ============================================================================

.PHONY: up
up: ## Inicia servicios (alias para start)
	@$(MAKE) start

.PHONY: down
down: ## Detiene servicios (alias para stop)
	@$(MAKE) stop

# Ahora también puedes usar:
# make validate
# make backup-all
# make metrics
# etc.
```

#### Paso 5: Adaptar docker-compose.yml

Asegúrate de que tu `docker-compose.yml` use variables de entorno:

**Antes**:
```yaml
services:
  postgres:
    image: postgres:15
    networks:
      - mynetwork
```

**Después**:
```yaml
services:
  postgres:
    image: postgres:${POSTGRES_VERSION:-15}
    networks:
      - ${NETWORK_NAME:-dev-toolbox}
```

#### Paso 6: Crear .env-template

Extrae las variables hardcodeadas a `.env-template`:

```bash
# .env-template
NETWORK_NAME=mi-proyecto
NETWORK_IP=172.20.0.0

POSTGRES_VERSION=15
POSTGRES_DB=mydb
POSTGRES_USER=postgres
POSTGRES_PASSWORD=changeme
POSTGRES_PORT=5432
```

#### Paso 7: Migrar Variables de Entorno

```bash
# Si ya tienes .env, verificar que tenga las variables necesarias
make init-env  # Crea .env desde template si no existe

# Agregar variables faltantes manualmente o usar:
make env-edit  # Abre .env en editor
```

#### Paso 8: Validar Migración

```bash
# Validar configuración
make validate

# Verificar que servicios se pueden iniciar
make start

# Verificar estado
make ps
make metrics
```

#### Paso 9: Actualizar Documentación

Actualiza tu `README.md`:

```markdown
## Desarrollo Local

### Requisitos
- Docker
- Docker Compose
- Make

### Configuración Inicial

```bash
# Clonar proyecto
git clone ...
git submodule update --init --recursive

# Configurar entorno
make setup

# Iniciar servicios
make start
```

### Comandos Disponibles

```bash
make help-toolbox  # Ver todos los comandos
make validate      # Validar configuración
make backup-all    # Backup de servicios
make metrics       # Ver métricas
```
```

### Ejemplo: Migración de Proyecto Laravel

**Antes**:
```bash
# Comandos manuales
docker-compose up -d
docker-compose exec app php artisan migrate
docker-compose exec app php artisan db:seed
```

**Después**:
```makefile
# Makefile con dev-toolbox
PROJECT_ROOT := $(CURDIR)
TOOLBOX_ROOT := .toolbox/
include .toolbox/Makefile

.PHONY: migrate
migrate: ## Ejecuta migraciones
	@$(MAKE) exec SERVICE=app COMMAND="php artisan migrate"

.PHONY: seed
seed: ## Ejecuta seeders
	@$(MAKE) exec SERVICE=app COMMAND="php artisan db:seed"

.PHONY: setup-laravel
setup-laravel: setup migrate seed ## Configura Laravel completo
	@echo "✅ Laravel configurado"
```

**Uso**:
```bash
make setup-laravel  # Todo en uno
make migrate        # Solo migraciones
make backup-all     # Backup de BD
```

---

## 🔧 Variables de Entorno

### Variables Requeridas

Estas variables **DEBEN** estar definidas en tu `.env`:

#### Red Docker

```bash
NETWORK_NAME=mi-proyecto        # Nombre de la red Docker
NETWORK_IP=172.20.0.0          # Rango IP de la red (formato: X.X.X.0)
```

#### Versiones de Servicios

```bash
# Formato: <SERVICIO>_VERSION=<version>
POSTGRES_VERSION=18
MONGO_VERSION=7.0
REDIS_VERSION=7-alpine
RABBITMQ_VERSION=3.12
```

### Variables Opcionales

#### Configuración General

```bash
# Prefijo para contenedores (opcional)
SERVICE_PREFIX=mi-proyecto

# Archivo de entorno (default: .env)
ENV_FILE=.env

# Logging
LOG_LEVEL=INFO                  # DEBUG, INFO, WARN, ERROR
LOG_FILE=                        # Ruta a archivo de log (vacío = no log a archivo)
```

#### Infisical (Gestión de Secretos)

```bash
INFISICAL_URL=https://app.infisical.com
INFISICAL_GLOBAL_TOKEN=your-global-token
INFISICAL_PROJECT_TOKEN=your-project-token
```

#### Git (Para load-toolbox)

```bash
GIT_USER=tu-usuario-github
GIT_TOKEN=tu-token-github
GIT_BRANCH=main                 # o un tag como v2.3.0
GIT_REPO=dev-toolbox            # default
TOOLBOX_TARGET=.toolbox         # default
```

#### Servicios Específicos

```bash
# PostgreSQL
POSTGRES_DB=mydb
POSTGRES_USER=postgres
POSTGRES_PASSWORD=changeme
POSTGRES_PORT=5432

# MongoDB
MONGO_DB=mydb
MONGO_USER=admin
MONGO_PASSWORD=changeme
MONGO_PORT=27017

# Redis
REDIS_PASSWORD=changeme
REDIS_PORT=6379
```

### Variables de Sistema (Automáticas)

Estas variables son establecidas automáticamente por dev-toolbox:

```bash
PROJECT_ROOT=/ruta/al/proyecto   # Raíz del proyecto
TOOLBOX_ROOT=.toolbox/           # Ruta al toolbox (si está en subdirectorio)
COMMON_SCRIPTS_DIR=...           # Ruta a scripts comunes
```

### Plantilla Completa (.env-template)

```bash
# ============================================================================
# Configuración de Red
# ============================================================================
NETWORK_NAME=mi-proyecto
NETWORK_IP=172.20.0.0

# ============================================================================
# Versiones de Servicios
# ============================================================================
POSTGRES_VERSION=18
MONGO_VERSION=7.0
REDIS_VERSION=7-alpine
RABBITMQ_VERSION=3.12

# ============================================================================
# Configuración de Servicios
# ============================================================================
POSTGRES_DB=mydb
POSTGRES_USER=postgres
POSTGRES_PASSWORD=changeme
POSTGRES_PORT=5432

MONGO_DB=mydb
MONGO_USER=admin
MONGO_PASSWORD=changeme
MONGO_PORT=27017

REDIS_PASSWORD=changeme
REDIS_PORT=6379

# ============================================================================
# Configuración Opcional
# ============================================================================
SERVICE_PREFIX=mi-proyecto
LOG_LEVEL=INFO

# ============================================================================
# Infisical (Opcional)
# ============================================================================
# INFISICAL_URL=https://app.infisical.com
# INFISICAL_GLOBAL_TOKEN=
# INFISICAL_PROJECT_TOKEN=
```

### Validar Variables

```bash
# Validar que todas las variables requeridas estén presentes
make validate

# Ver variables de entorno (sanitizadas)
make env-show

# Editar .env
make env-edit
```

---

## 🔍 Troubleshooting

### Problema: "make: .toolbox/Makefile: No such file or directory"

**Causa**: El submódulo no está inicializado o la ruta es incorrecta.

**Solución**:
```bash
# Si usas submódulos
git submodule update --init --recursive

# Verificar que existe
ls -la .toolbox/Makefile

# Si no existe, verificar ruta en Makefile
# TOOLBOX_ROOT debe apuntar a la ubicación correcta
```

### Problema: "Comandos no encontrados"

**Causa**: `TOOLBOX_ROOT` no está configurado correctamente.

**Solución**:
```makefile
# En tu Makefile, asegúrate de tener:
TOOLBOX_ROOT := .toolbox/  # o la ruta correcta
include .toolbox/Makefile
```

### Problema: "Variables de entorno no encontradas"

**Causa**: Falta archivo `.env` o variables requeridas.

**Solución**:
```bash
# Crear .env desde plantilla
make init-env

# Verificar variables faltantes
make validate

# Ver variables actuales
make env-show
```

### Problema: "Error al cargar submódulo"

**Causa**: Problemas con Git o permisos.

**Solución**:
```bash
# Eliminar y volver a agregar
git submodule deinit .toolbox
git rm .toolbox
git submodule add https://github.com/ingeniomaps/dev-toolbox.git .toolbox
git submodule update --init --recursive
```

### Problema: "Docker network not found"

**Causa**: La red Docker no existe.

**Solución**:
```bash
# Crear red manualmente
docker network create --subnet=172.20.0.0/16 mi-proyecto

# O usar el comando de dev-toolbox
make network-tool  # Crea la red desde .env
```

### Problema: "Permission denied" en scripts

**Causa**: Scripts sin permisos de ejecución.

**Solución**:
```bash
# Dar permisos de ejecución
chmod +x .toolbox/scripts/sh/**/*.sh

# O usar find
find .toolbox/scripts -name "*.sh" -exec chmod +x {} \;
```

### Problema: "load-toolbox requiere GIT_USER y GIT_TOKEN"

**Causa**: Variables de entorno no exportadas.

**Solución**:
```bash
# Exportar variables
export GIT_USER=tu-usuario
export GIT_TOKEN=tu-token

# Verificar
echo $GIT_USER
echo $GIT_TOKEN

# Ejecutar
make load-toolbox
```

### Problema: "Servicios no se inician"

**Causa**: Configuración incorrecta o puertos ocupados.

**Solución**:
```bash
# Validar configuración
make validate

# Verificar puertos
make check-ports

# Ver logs
make aggregate-logs

# Ver estado
make ps
```

### Problema: "Backup falla"

**Causa**: Permisos o rutas incorrectas.

**Solución**:
```bash
# Verificar que los servicios estén corriendo
make ps

# Verificar permisos de directorio de backups
ls -la backups/  # o donde estén los backups

# Ver logs detallados
make aggregate-logs SERVICE=postgres
```

### Problema: "Comandos de dev-toolbox no aparecen en help"

**Causa**: Makefile no incluye correctamente dev-toolbox.

**Solución**:
```makefile
# Verificar orden en Makefile
PROJECT_ROOT := $(CURDIR)
TOOLBOX_ROOT := .toolbox/
include .toolbox/Makefile  # Debe estar ANTES de tus comandos

# Verificar que no hay conflictos de nombres
# Tus comandos no deben tener el mismo nombre que los de dev-toolbox
```

---

## 💡 Mejores Prácticas

### 1. Versionado de Submódulos

```bash
# Usar tags específicos para versiones estables
git submodule add -b v2.3.0 https://github.com/ingeniomaps/dev-toolbox.git .toolbox

# O actualizar a versión específica
cd .toolbox
git checkout v2.3.0
cd ..
git add .toolbox
git commit -m "chore: actualizar dev-toolbox a v2.3.0"
```

### 2. Documentar Integración

Incluye en tu `README.md`:

```markdown
## Requisitos

- Docker 20.10+
- Docker Compose 1.29+
- Make 3.81+
- Git (con soporte para submódulos)

## Configuración

```bash
# Clonar con submódulos
git clone --recursive https://github.com/tu-usuario/tu-proyecto.git

# O si ya clonaste
git submodule update --init --recursive

# Configurar
make setup
```
```

### 3. CI/CD Integration

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: recursive
      
      - name: Setup environment
        run: make setup
      
      - name: Validate
        run: make validate
      
      - name: Check dependencies
        run: make check-dependencies
      
      - name: Run tests
        run: make test
```

### 4. Separar Comandos del Proyecto

```makefile
# Makefile bien organizado
PROJECT_ROOT := $(CURDIR)
TOOLBOX_ROOT := .toolbox/
include .toolbox/Makefile

# ============================================================================
# Comandos del Proyecto (separados claramente)
# ============================================================================

.PHONY: dev
dev: start
	@echo "✅ Desarrollo listo"

.PHONY: test
test:
	@echo "🧪 Tests..."
```

### 5. Mantener .env-template Actualizado

```bash
# Cuando agregues nuevas variables, actualiza .env-template
# Esto ayuda a nuevos desarrolladores
```

### 6. Usar Variables de Entorno Consistentemente

```yaml
# docker-compose.yml - SIEMPRE usar variables
services:
  postgres:
    image: postgres:${POSTGRES_VERSION}
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
```

### 7. Backup Regular

```bash
# Configurar backups automáticos
make setup-backup-schedule

# O manualmente antes de cambios importantes
make backup-all
```

---

## 📚 Recursos Adicionales

- [README Principal](../README.md) - Documentación general
- [Guía de Desarrollo](GUIA_DESARROLLO.md) - Crear nuevos scripts
- [Documentación de Helpers](HELPERS.md) - Referencia de helpers
- [Estándares Obligatorios](ESTANDARES_OBLIGATORIOS.md) - Estándares de calidad

---

## ✅ Checklist de Integración

Usa este checklist para verificar que la integración está completa:

- [ ] dev-toolbox agregado como submódulo o cargado con load-toolbox
- [ ] `Makefile` principal incluye `.toolbox/Makefile`
- [ ] Variables `PROJECT_ROOT` y `TOOLBOX_ROOT` configuradas
- [ ] `.env-template` creado con todas las variables necesarias
- [ ] `.env` creado desde template (`make init-env`)
- [ ] `docker-compose.yml` usa variables de entorno
- [ ] Validación exitosa (`make validate`)
- [ ] Servicios se inician correctamente (`make start`)
- [ ] Comandos de dev-toolbox disponibles (`make help-toolbox`)
- [ ] `.gitignore` actualizado (excluye `.env`, incluye `.toolbox/` si es copia)
- [ ] `README.md` actualizado con instrucciones de setup
- [ ] CI/CD configurado (si aplica)

---

**¿Problemas?** Revisa la sección [Troubleshooting](#-troubleshooting) o abre un issue en el repositorio.

**¿Sugerencias?** Las contribuciones son bienvenidas. Ver [Guía de Contribución](../README.md#-contribuir).

---

*Última actualización: 2025-01-27*
