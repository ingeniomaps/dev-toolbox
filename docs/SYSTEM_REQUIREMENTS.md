# Requisitos del Sistema

Esta guía documenta todos los requisitos del sistema para usar `dev-toolbox`, incluyendo versiones mínimas y recomendadas.

---

## 📋 Requisitos Obligatorios

### Docker

- **Versión mínima**: 20.10.0
- **Versión recomendada**: 24.0.0 o superior
- **Descripción**: Docker Engine o Docker Desktop
- **Instalación**: https://docs.docker.com/get-docker/

**Verificación**:
```bash
docker --version
# Debe mostrar >= 20.10.0
```

**Nota**: El daemon de Docker debe estar corriendo. En Linux: `sudo systemctl start docker`

---

### Docker Compose

- **Versión mínima**:
  - V2: 2.0.0 (preferido)
  - V1: 1.29.0 (soporte legacy)
- **Versión recomendada**: 2.20.0 o superior
- **Descripción**: Docker Compose V2 (integrado en Docker) o V1 (standalone)
- **Instalación**: https://docs.docker.com/compose/install/

**Verificación**:
```bash
# Docker Compose V2
docker compose version

# Docker Compose V1
docker-compose --version
```

**Nota**: Se recomienda usar Docker Compose V2 (`docker compose`) sobre V1.

---

### Bash

- **Versión mínima**: 4.0.0
- **Descripción**: Bash shell
- **Instalación**: Generalmente incluido en Linux/macOS

**Verificación**:
```bash
bash --version
```

**Nota**: En macOS, puede ser necesario instalar una versión más reciente usando Homebrew.

---

### Make

- **Versión mínima**: 4.0.0
- **Descripción**: GNU Make
- **Instalación**:
  - Linux: `sudo apt install make` (Debian/Ubuntu) o equivalente
  - macOS: `xcode-select --install` o `brew install make`
  - https://www.gnu.org/software/make/

**Verificación**:
```bash
make --version
```

---

## 🔧 Herramientas Opcionales

### jq

- **Versión mínima**: 1.6.0
- **Descripción**: Procesador JSON para línea de comandos
- **Uso**: Funcionalidades avanzadas (validación de versiones, métricas, etc.)
- **Fallback**: Si no está disponible, algunas funcionalidades avanzadas estarán deshabilitadas

**Instalación**:
```bash
# Linux (Debian/Ubuntu)
sudo apt install jq

# macOS
brew install jq

# Otras distribuciones
# https://stedolan.github.io/jq/download/
```

**Verificación**:
```bash
jq --version
```

---

### curl

- **Versión mínima**: 7.0.0
- **Descripción**: Cliente HTTP para descargas y operaciones de red
- **Uso**: Algunas operaciones de red y descargas
- **Fallback**: Si no está disponible, algunas operaciones de red pueden no funcionar

**Instalación**:
```bash
# Linux (Debian/Ubuntu)
sudo apt install curl

# macOS
brew install curl

# Generalmente incluido en sistemas Unix modernos
```

**Verificación**:
```bash
curl --version
```

---

### AWK

- **Versión mínima**: 4.0.0
- **Descripción**: Procesador de texto AWK (GNU Awk preferido)
- **Uso**: Procesamiento de texto y generación de reportes
- **Fallback**: Generalmente incluido en sistemas Unix

**Instalación**:
```bash
# Linux (Debian/Ubuntu)
sudo apt install gawk

# macOS
# Generalmente incluido
```

**Verificación**:
```bash
awk --version
```

---

### grep

- **Versión mínima**: 2.0.0
- **Descripción**: Herramienta de búsqueda de texto (GNU grep preferido)
- **Uso**: Búsqueda y filtrado de texto
- **Fallback**: Generalmente incluido en sistemas Unix

**Instalación**:
```bash
# Generalmente incluido en sistemas Unix
```

---

## 🌐 Servicios Externos Opcionales

### Infisical

- **Versión**: Cualquiera (si está instalado)
- **Descripción**: CLI de Infisical para gestión de secretos
- **Uso**: Gestión de secretos desde Infisical
- **Fallback**: Si no está disponible, se usan variables de entorno desde `.env`

**Instalación**: https://infisical.com/docs/cli/installation

**Verificación**:
```bash
infisical --version
```

**Nota**: Infisical es completamente opcional. El proyecto funciona perfectamente usando solo `.env` para secretos.

---

## 🖥️ Sistemas Operativos Soportados

### Linux

- **Distribuciones soportadas**: Ubuntu 20.04+, Debian 10+, CentOS 8+, Fedora 32+
- **Requisitos especiales**:
  - Docker debe estar instalado y el daemon corriendo
  - Usuario debe tener permisos para ejecutar Docker (agregar a grupo `docker`)

### macOS

- **Versiones soportadas**: macOS 10.15+ (Catalina o superior)
- **Requisitos especiales**:
  - Docker Desktop debe estar instalado y corriendo
  - Homebrew recomendado para herramientas adicionales

### Windows

- **Soporte**: WSL 2 (Windows Subsystem for Linux)
- **Requisitos**:
  - WSL 2 instalado y configurado
  - Docker Desktop para Windows con integración WSL habilitada
- **No soportado**: Windows nativo (cmd.exe, PowerShell sin WSL)

**Ver documentación**: [docs/WSL_SETUP.md](WSL_SETUP.md)

---

## ✅ Verificación de Requisitos

### Comando Automático

```bash
# Verificar todas las dependencias
make check-dependencies

# Modo estricto (falla si versiones < mínimas)
make check-dependencies -- --strict

# Sin verificar herramientas opcionales
make check-dependencies -- --skip-optional
```

### Verificación Manual

```bash
# Docker
docker --version  # >= 20.10.0

# Docker Compose
docker compose version  # >= 2.0.0 (V2)
# o
docker-compose --version  # >= 1.29.0 (V1)

# Bash
bash --version  # >= 4.0.0

# Make
make --version  # >= 4.0.0

# Opcionales
jq --version  # >= 1.6.0 (opcional)
curl --version  # >= 7.0.0 (opcional)
```

---

## 🔍 Solución de Problemas

### Docker no está corriendo

**Síntoma**: Error "Cannot connect to the Docker daemon"

**Solución**:
```bash
# Linux
sudo systemctl start docker
sudo systemctl enable docker

# macOS
# Abre Docker Desktop desde Applications

# Verificar
docker ps
```

### Versión de Docker muy antigua

**Síntoma**: Advertencia sobre versión < 20.10

**Solución**:
```bash
# Actualizar Docker según tu sistema
# Linux: Ver https://docs.docker.com/engine/install/
# macOS: Actualizar Docker Desktop desde la aplicación
```

### Docker Compose V1 detectado

**Síntoma**: Mensaje sobre usar Docker Compose V2

**Solución**:
```bash
# Docker Compose V2 está incluido en Docker Desktop 3.4+
# Si tienes Docker Desktop actualizado, usa:
docker compose version

# Si necesitas migrar de V1 a V2:
# https://docs.docker.com/compose/migrate/
```

### jq no disponible

**Síntoma**: Mensaje sobre funcionalidades avanzadas no disponibles

**Solución**:
```bash
# Instalar jq según tu sistema
sudo apt install jq  # Debian/Ubuntu
brew install jq      # macOS

# Verificar
jq --version
```

### Permisos de Docker

**Síntoma**: Error "permission denied" al ejecutar Docker

**Solución**:
```bash
# Agregar usuario al grupo docker
sudo usermod -aG docker $USER

# Cerrar sesión y volver a iniciar, o:
newgrp docker

# Verificar
docker ps
```

---

## 📚 Referencias

- **Docker**: https://docs.docker.com/
- **Docker Compose**: https://docs.docker.com/compose/
- **jq**: https://stedolan.github.io/jq/
- **Infisical**: https://infisical.com/docs/cli/installation
- **WSL Setup**: [docs/WSL_SETUP.md](WSL_SETUP.md)

---

## 📝 Notas

- **Versionado semántico**: Las versiones siguen formato `MAJOR.MINOR.PATCH`
- **Comparación de versiones**: El sistema compara versiones de manera estricta (>= mínimo)
- **Fallbacks**: Las herramientas opcionales tienen fallbacks cuando no están disponibles
- **Actualizaciones**: Se recomienda mantener todas las herramientas actualizadas

---

**Última actualización**: Enero 2025
