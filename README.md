# Dev Toolbox

[![Version](https://img.shields.io/badge/version-2.3.1-blue.svg)](.version)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-blue.svg)](.github/workflows/ci.yml)

> Framework de herramientas de desarrollo para automatizar y estandarizar la gestión de entornos de desarrollo con Docker.

---

## 📋 Tabla de Contenidos

- [¿Qué es dev-toolbox?](#-qué-es-dev-toolbox)
- [Arquitectura](#-arquitectura)
- [Casos de Uso](#-casos-de-uso)
- [Instalación](#-instalación)
- [Integración en Proyectos](#-integración-en-proyectos)
- [Comandos Principales](#-comandos-principales)
- [Documentación](#-documentación)
- [CI/CD](#-cicd)
- [Contribuir](#-contribuir)

---

## 🎯 ¿Qué es dev-toolbox?

**dev-toolbox** es un framework de herramientas de desarrollo diseñado para automatizar y estandarizar la gestión de entornos de desarrollo con Docker. Proporciona una capa de abstracción sobre Docker/Docker Compose mediante Makefiles y scripts Bash, ofreciendo comandos consistentes para validación, monitoreo, backups, seguridad y CI/CD.

### Propósito Principal

1. **Estandarización de workflows**: Unifica comandos comunes de desarrollo (`make validate`, `make backup-all`, `make metrics`) independientemente del proyecto específico.

2. **Automatización de tareas repetitivas**:
   - Validación de configuración (.env, IPs, puertos, versiones)
   - Gestión de backups y restauraciones
   - Monitoreo de servicios Docker
   - Gestión de secretos (Infisical)
   - Rollback de estados del sistema

3. **Abstracción de complejidad**: Oculta la complejidad de Docker/Docker Compose detrás de comandos simples y consistentes.

4. **Reutilización entre proyectos**: Puede ser incluido como dependencia en múltiples proyectos, proporcionando las mismas herramientas en todos.

5. **Onboarding rápido**: Nuevos desarrolladores pueden empezar rápidamente con `make setup` en lugar de aprender comandos Docker específicos.

### Beneficios

- ✅ **Productividad**: Comandos consistentes que funcionan igual en todos los proyectos
- ✅ **Mantenibilidad**: Código centralizado que beneficia a todos los proyectos
- ✅ **Calidad**: Validaciones exhaustivas y manejo robusto de errores
- ✅ **Escalabilidad**: Genérico y configurable, detecta servicios automáticamente
- ✅ **Seguridad**: Gestión de secretos e integración con Infisical

---

## 🏗️ Arquitectura

### Estructura del Proyecto

```
dev-toolbox/
├── makefiles/              # Makefiles organizados por dominio
│   ├── main/               # Makefiles principales (services, backup, validation, etc.)
│   └── common/             # Funciones comunes (logging, colors)
├── scripts/
│   └── sh/
│       ├── commands/       # Comandos directos (validate, metrics, backup-all, etc.)
│       ├── setup/          # Configuración inicial (init-env, setup, load-toolbox)
│       ├── backup/         # Backups y restauraciones
│       ├── utils/          # Utilidades auxiliares
│       ├── common/         # Helpers compartidos (init, services, validation, etc.)
│       └── tests/          # Tests automatizados
├── docs/                   # Documentación completa
├── .github/workflows/      # CI/CD con GitHub Actions
└── Makefile                # Punto de entrada principal
```

### Principios de Diseño

#### 1. Separación de Responsabilidades

- **Makefiles**: Wrappers ligeros que delegan a scripts `.sh`
- **Scripts Bash**: Contienen la lógica de negocio
- **Helpers Comunes**: Funciones reutilizables centralizadas

#### 2. Modularidad

Cada Makefile maneja un dominio específico:
- `services.mk` - Gestión de servicios Docker
- `backup.mk` - Backups y restauraciones
- `validation.mk` - Validación de configuración
- `monitoring.mk` - Monitoreo y métricas
- `security.mk` - Seguridad y secretos

#### 3. Genéricidad

- **Sin hardcoding**: Detecta servicios desde `*_VERSION` en `.env`
- **Configurable**: Funciona con cualquier servicio (postgres, mongo, redis, etc.)
- **Extensible**: Fácil agregar nuevos comandos siguiendo patrones establecidos

### Flujo de Ejecución

```
Usuario ejecuta: make validate
         │
         ├─> Makefile (wrapper)
         │   └─> Llama a scripts/sh/commands/validate.sh
         │
         ├─> Script Bash
         │   ├─> Carga init.sh (inicialización)
         │   ├─> Carga helpers necesarios (validation.sh, services.sh)
         │   └─> Ejecuta lógica de validación
         │
         └─> Resultado: Validación completa con logging estructurado
```

### Diagrama de Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                    Usuario / Desarrollador                  │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ make <comando>
                        │
        ┌───────────────▼───────────────┐
        │      Makefile (Wrapper)       │
        │  - services.mk                │
        │  - backup.mk                  │
        │  - validation.mk              │
        │  - monitoring.mk               │
        └───────────────┬───────────────┘
                        │
                        │ bash scripts/sh/commands/<comando>.sh
                        │
        ┌───────────────▼───────────────┐
        │      Scripts Bash              │
        │  - commands/                  │
        │  - setup/                     │
        │  - backup/                    │
        └───────────────┬───────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
┌───────▼──────┐ ┌──────▼──────┐ ┌─────▼──────┐
│  Helpers     │ │  Services   │ │  Docker    │
│  Comunes     │ │  Detection   │ │  Compose   │
│              │ │              │ │            │
│ - init.sh    │ │ - services.sh│ │ - docker   │
│ - logging.sh │ │              │ │ - compose  │
│ - validation │ │              │ │            │
└──────────────┘ └──────────────┘ └────────────┘
```

---

## 💡 Casos de Uso

### Caso 1: Validación de Configuración

**Problema**: Antes de iniciar servicios, necesitas verificar que la configuración sea correcta.

**Solución con dev-toolbox**:
```bash
# Validación completa
make validate

# Validaciones específicas
make check-ports      # Verifica que los puertos estén disponibles
make validate-ips     # Valida formato de IPs
make validate-passwords  # Verifica complejidad de contraseñas
```

**Resultado**: Detecta problemas antes de iniciar servicios, ahorrando tiempo y evitando errores.

### Caso 2: Gestión de Backups

**Problema**: Necesitas hacer backups regulares de bases de datos y volúmenes Docker.

**Solución con dev-toolbox**:
```bash
# Backup de todos los servicios
make backup-all

# Backup de un servicio específico
make backup SERVICE=postgres

# Restaurar desde backup
make restore-all

# Configurar backups automáticos
make setup-backup-schedule
```

**Resultado**: Backups automatizados y consistentes, con restauración simple.

### Caso 3: Monitoreo de Servicios

**Problema**: Necesitas monitorear el estado y rendimiento de servicios Docker.

**Solución con dev-toolbox**:
```bash
# Ver estado de todos los servicios
make ps

# Métricas de rendimiento
make metrics

# Logs agregados
make aggregate-logs

# Alertas de servicios
make alerts
```

**Resultado**: Visibilidad completa del estado del sistema en un solo comando.

### Caso 4: Gestión de Secretos

**Problema**: Necesitas gestionar secretos de forma segura sin hardcodearlos.

**Solución con dev-toolbox**:
```bash
# Cargar secretos desde Infisical
make load-secrets

# Rotar secretos
make rotate-secrets

# Verificar que no hay secretos expuestos
make secrets-check
```

**Resultado**: Gestión segura de secretos con integración a Infisical.

### Caso 5: Onboarding de Nuevos Desarrolladores

**Problema**: Nuevos desarrolladores necesitan configurar el entorno rápidamente.

**Solución con dev-toolbox**:
```bash
# Configuración completa en 3 comandos
make init-env      # Crea .env desde plantilla
make setup-env      # Valida y configura
make start          # Inicia servicios
```

**Resultado**: Onboarding de minutos en lugar de horas.

### Caso 6: CI/CD Integration

**Problema**: Necesitas validar configuración y ejecutar tests en CI/CD.

**Solución con dev-toolbox**:
```yaml
# .github/workflows/ci.yml
- name: Validate configuration
  run: make validate

- name: Check dependencies
  run: make check-dependencies

- name: Run tests
  run: make test
```

**Resultado**: Validación automática en cada commit/PR.

---

## 📦 Instalación

### Requisitos Previos

- **Sistema Operativo**: Linux, macOS, o **WSL (Windows Subsystem for Linux)** en Windows
  - ⚠️ **Windows nativo no es compatible directamente** (ver [docs/WSL_SETUP.md](docs/WSL_SETUP.md) para usar WSL)
  - Scripts PowerShell básicos disponibles como alternativa limitada (ver [scripts/powershell/README.md](scripts/powershell/README.md))
- **Docker** (versión 20.10 o superior)
- **Docker Compose** (versión 1.29 o superior, o Docker Compose V2)
- **Bash** (versión 4.0 o superior)
- **Make** (GNU Make 3.81 o superior)
- **Git** (para clonar el repositorio)

### Instalación Paso a Paso

#### 1. Clonar el Repositorio

```bash
git clone https://github.com/ingeniomaps/dev-toolbox.git
cd dev-toolbox
```

#### 2. Verificar Dependencias

```bash
make check-dependencies
```

Este comando verifica que Docker, Docker Compose y otras herramientas estén instaladas y funcionando.

#### 3. Inicializar el Entorno

```bash
# Crear archivo .env desde plantilla
make init-env

# Configurar y validar entorno completo
make setup-env
```

El comando `init-env` crea un archivo `.env` desde `.env-template` con valores por defecto. El comando `setup-env` valida la configuración y asegura que todo esté listo.

#### 4. Verificar Instalación

```bash
# Ver todos los comandos disponibles
make help-toolbox

# Verificar que los servicios se pueden iniciar
make validate
```

#### 5. (Opcional) Instalar como Dependencia en Otro Proyecto

Ver sección [Integración en Proyectos](#-integración-en-proyectos).

### Verificación de Instalación

```bash
# Verificar versión
make show-version

# Verificar instalación completa
make verify-installation
```

---

## 🔗 Integración en Proyectos

### Método 1: Como Submódulo Git (Recomendado)

Ideal para proyectos que necesitan una versión específica de dev-toolbox.

#### Paso 1: Agregar como Submódulo

```bash
cd tu-proyecto
git submodule add https://github.com/ingeniomaps/dev-toolbox.git .toolbox
git submodule update --init --recursive
```

#### Paso 2: Incluir Makefiles

En el `Makefile` de tu proyecto:

```makefile
# Incluir dev-toolbox
include .toolbox/Makefile

# Tu proyecto puede usar todos los comandos de dev-toolbox
# make validate, make backup-all, make metrics, etc.
```

#### Paso 3: Configurar Variables

En tu `.env` o `Makefile`:

```makefile
# Ruta al toolbox
TOOLBOX_ROOT := .toolbox/
PROJECT_ROOT := $(CURDIR)
```

#### Paso 4: Usar Comandos

```bash
# Todos los comandos de dev-toolbox están disponibles
make validate
make backup-all
make metrics
make help-toolbox
```

### Método 2: Usando load-toolbox (Automático)

Ideal para proyectos que quieren la última versión o una versión específica.

#### Paso 1: Configurar Variables

```bash
export GIT_USER=tu-usuario
export GIT_TOKEN=tu-token-github
export GIT_BRANCH=main  # o un tag específico como v2.3.0
```

#### Paso 2: Cargar Toolbox

```bash
# Si ya tienes dev-toolbox en tu proyecto
make load-toolbox

# O desde otro proyecto que incluye dev-toolbox
cd otro-proyecto
make -f .toolbox/Makefile load-toolbox
```

Esto clonará o actualizará dev-toolbox en `.toolbox/`.

#### Paso 3: Incluir en Makefile

```makefile
# Incluir dev-toolbox
-include .toolbox/Makefile

# Si no existe, cargarlo automáticamente
ifneq ($(wildcard .toolbox/Makefile),)
    include .toolbox/Makefile
else
    $(info Toolbox no encontrado. Ejecuta: make load-toolbox)
endif
```

### Método 3: Copia Directa (No Recomendado)

Solo si necesitas modificar dev-toolbox específicamente para tu proyecto.

```bash
cp -r dev-toolbox/* tu-proyecto/.toolbox/
```

**Nota**: Esto hace difícil mantener actualizaciones. Preferir métodos 1 o 2.

### Ejemplo Completo de Integración

#### Estructura del Proyecto

```
mi-proyecto/
├── .env
├── .toolbox/          # dev-toolbox como submódulo
│   ├── Makefile
│   ├── makefiles/
│   └── scripts/
├── Makefile           # Makefile principal del proyecto
├── docker-compose.yml
└── src/
```

#### Makefile del Proyecto

```makefile
# Variables del proyecto
PROJECT_ROOT := $(CURDIR)
TOOLBOX_ROOT := .toolbox/

# Incluir dev-toolbox
include .toolbox/Makefile

# Comandos específicos del proyecto
.PHONY: start-project
start-project: ## Inicia el proyecto completo
	@echo "Iniciando proyecto..."
	@$(MAKE) validate
	@$(MAKE) start
	@echo "Proyecto iniciado correctamente"

.PHONY: deploy
deploy: ## Despliega el proyecto
	@$(MAKE) validate
	@$(MAKE) backup-all
	@$(MAKE) build
	@$(MAKE) start
```

#### Uso

```bash
# Comandos de dev-toolbox disponibles
make validate
make backup-all
make metrics

# Comandos específicos del proyecto
make start-project
make deploy
```

### Variables de Entorno Importantes

Al integrar dev-toolbox, estas variables son importantes:

```bash
# Ruta al toolbox (si está en subdirectorio)
TOOLBOX_ROOT=.toolbox/

# Raíz del proyecto
PROJECT_ROOT=$(pwd)

# Archivo de entorno
ENV_FILE=.env

# Prefijo para contenedores (opcional)
SERVICE_PREFIX=mi-proyecto
```

### Troubleshooting

#### Problema: "make: .toolbox/Makefile: No such file or directory"

**Solución**:
```bash
# Si usas submódulos
git submodule update --init --recursive

# Si usas load-toolbox
make load-toolbox
```

#### Problema: "Comandos no encontrados"

**Solución**: Verifica que `TOOLBOX_ROOT` esté configurado correctamente en tu Makefile.

#### Problema: "Variables de entorno no encontradas"

**Solución**: Asegúrate de tener un archivo `.env` con las variables necesarias. Usa `make init-env` para crear uno desde la plantilla.

---

## 🔧 Comandos Principales

### Configuración Inicial

```bash
make init-env              # Crea .env desde plantilla
make setup-env             # Configuración completa (init + validate)
make check-dependencies    # Verifica prerrequisitos
```

### Gestión de Servicios

```bash
make start SERVICE=postgres    # Inicia un servicio
make stop SERVICE=postgres     # Detiene un servicio
make restart SERVICE=postgres  # Reinicia un servicio
make ps                        # Lista todos los servicios
make build                     # Construye imágenes
make rebuild                   # Reconstruye y reinicia
```

### Validación

```bash
make validate                 # Valida configuración completa
make check-ports              # Verifica puertos disponibles
make validate-ips            # Valida formato de IPs
make validate-passwords      # Verifica complejidad de contraseñas
make check-versions          # Verifica versiones de servicios
```

### Backups y Restauraciones

```bash
make backup-all              # Backup de todos los servicios
make backup SERVICE=postgres # Backup de un servicio
make restore-all             # Restaura desde backups
make list-states             # Lista estados guardados
make rollback                # Revierte a un estado anterior
```

### Monitoreo

```bash
make metrics                 # Muestra métricas de servicios
make aggregate-logs          # Agrega logs de todos los servicios
make alerts                  # Verifica alertas de servicios
make info                    # Información detallada del sistema
```

### Limpieza

```bash
make clean                   # Limpia contenedores detenidos
make clean-volumes          # Limpia volúmenes no usados
make clean-images           # Limpia imágenes no usadas
make clean-networks         # Limpia redes no usadas
make prune                  # Limpieza completa del sistema
```

### Ver Todos los Comandos

```bash
make help-toolbox           # Muestra todos los comandos disponibles con ayuda
```

---

## 📚 Documentación

### Para Desarrolladores

- **[Guía de Integración](docs/INTEGRATION_GUIDE.md)** - Cómo integrar dev-toolbox en tus proyectos
- **[Guía de Desarrollo](docs/GUIA_DESARROLLO.md)** - Cómo crear nuevos scripts siguiendo las mejores prácticas
- **[Documentación de Helpers](docs/HELPERS.md)** - Referencia completa de todos los helpers disponibles
- **[Estándares Obligatorios](docs/ESTANDARES_OBLIGATORIOS.md)** - Estándares de calidad para scripts nuevos
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Solución a problemas comunes
- **[Configuración WSL](docs/WSL_SETUP.md)** - Guía completa para usar dev-toolbox en Windows con WSL
- **[Requisitos de Red](docs/NETWORK_REQUIREMENTS.md)** - Configuración y requisitos de redes Docker
- **[Configuración de Logging](docs/LOGGING_CONFIG.md)** - Sistema de logging a archivo con rotación automática
- **[Compatibilidad de Versiones](docs/VERSION_COMPATIBILITY.md)** - Validación de versiones de servicios
- **[Cobertura de Tests](docs/TEST_COVERAGE.md)** - Sistema de métricas y cobertura de tests
- **[Requisitos del Sistema](docs/SYSTEM_REQUIREMENTS.md)** - Versiones mínimas y herramientas requeridas
- **[Análisis del Proyecto](ANALISIS_PROYECTO.md)** - Propósito, beneficios, fortalezas y debilidades
- **[TODO](TODO.md)** - Plan de mejoras y tareas pendientes

### Helpers Comunes

El proyecto incluye helpers reutilizables en `scripts/sh/common/`:

- **`init.sh`** ⚠️ **OBLIGATORIO** - Inicialización estándar de scripts
- **`services.sh`** - Detección y gestión de servicios Docker
- **`validation.sh`** - Validación de argumentos y parámetros
- **`error-handling.sh`** - Manejo de errores con cleanup y retry
- **`docker-compose.sh`** - Interacción con Docker Compose
- **`logging.sh`** - Sistema de logging con niveles
- **`colors.sh`** - Colores ANSI para terminal

📖 **Ver documentación completa**: [docs/HELPERS.md](docs/HELPERS.md)

### Estándares Obligatorios

⚠️ **IMPORTANTE**: Todos los scripts nuevos DEBEN seguir estos estándares:

1. ✅ **Usar `init.sh`** - Es obligatorio para inicialización
2. ✅ **Líneas ≤ 120 caracteres** - Usar continuaciones cuando sea necesario
3. ✅ **Logging unificado** - Usar `log_info`, `log_error`, etc. (no `echo`)
4. ✅ **Header completo** - Incluir descripción, uso, parámetros, variables, retorno
5. ✅ **`set -euo pipefail`** - Manejo estricto de errores
6. ✅ **Validar argumentos** - Usar `validation.sh` cuando sea apropiado

📖 **Ver guía completa**: [docs/GUIA_DESARROLLO.md](docs/GUIA_DESARROLLO.md)

---

## 🧪 CI/CD

El proyecto incluye configuración de CI/CD con GitHub Actions que verifica:

- ✅ Sintaxis de scripts bash
- ✅ Longitud de líneas (≤ 120 caracteres)
- ✅ Uso de `init.sh` en scripts nuevos
- ✅ Tests de helpers
- ✅ Linting con ShellCheck y shfmt
- ✅ Tests unitarios e integración

### Linting y Formateo

```bash
# Ejecutar linters
make lint

# Aplicar correcciones automáticas
make lint-fix

# Instalar pre-commit hooks
make install-pre-commit
```

Los linters verifican:
- **ShellCheck**: Análisis estático de scripts Bash
- **shfmt**: Formateo consistente de código
- **Pre-commit hooks**: Verificación automática antes de commits
- ✅ Sintaxis de Makefiles
- ✅ Estructura de directorios

Ver: [.github/workflows/ci.yml](.github/workflows/ci.yml)

### Uso en CI/CD de Otros Proyectos

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Checkout dev-toolbox
        uses: actions/checkout@v3
        with:
          repository: ingeniomaps/dev-toolbox
          path: .toolbox
      - name: Validate configuration
        run: make -f .toolbox/Makefile validate
      - name: Check dependencies
        run: make -f .toolbox/Makefile check-dependencies
```

---

## 🤝 Contribuir

Las contribuciones son bienvenidas. Por favor:

1. Lee la [Guía de Contribución](CONTRIBUTING.md) - Guía completa para contribuir
2. Revisa los [Estándares Obligatorios](docs/ESTANDARES_OBLIGATORIOS.md)
3. Asegúrate de que los tests pasen: `bash scripts/sh/tests/test-*.sh`
4. Verifica la calidad del código: `bash scripts/sh/utils/check-code-quality.sh`
5. Crea un Pull Request con una descripción clara

📖 **Ver guía completa**: [CONTRIBUTING.md](CONTRIBUTING.md)

---

## 📖 Más Información

- [Análisis del Proyecto](ANALISIS_PROYECTO.md)
- [Documentación de Helpers](docs/HELPERS.md)
- [Estándares Obligatorios](docs/ESTANDARES_OBLIGATORIOS.md)
- [Changelog](CHANGELOG.md) - Historial de cambios
- [TODO](TODO.md)

---

**Versión**: 2.3.1
**Licencia**: MIT
**Mantenido por**: [IngenioMaps](https://github.com/ingeniomaps)

---

## 🚀 Proceso de Release

Para crear un nuevo release:

```bash
# Release completo (tests + bump + tag + release notes)
make release PART=patch

# Ver proceso completo
make release PART=minor

# Simular sin hacer cambios
make release PART=patch DRY_RUN=1
```

📖 **Ver guía completa**: [docs/RELEASE_PROCESS.md](docs/RELEASE_PROCESS.md)
