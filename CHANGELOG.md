# Changelog

Todos los cambios notables en este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/lang/es/).

---

## [Unreleased]

### Added
- Nuevas funcionalidades que aún no han sido liberadas

### Changed
- Cambios en funcionalidades existentes

### Deprecated
- Funcionalidades que serán eliminadas en futuras versiones

### Removed
- Funcionalidades eliminadas

### Fixed
- Correcciones de bugs

### Security
- Mejoras de seguridad

---

## [2.3.0] - 2025-01-27

### Added
- **Helpers comunes**: Sistema completo de helpers reutilizables
  - `init.sh` - Inicialización estándar de scripts (OBLIGATORIO)
  - `services.sh` - Detección y gestión de servicios Docker
  - `validation.sh` - Validación de argumentos y parámetros
  - `error-handling.sh` - Manejo de errores con cleanup y retry
  - `docker-compose.sh` - Interacción con Docker Compose (v1/v2)
- **11 comandos nuevos**:
  - `build` - Construye imágenes Docker
  - `rebuild` - Reconstruye y reinicia servicios
  - `env-show` - Muestra variables de entorno sanitizadas
  - `env-edit` - Abre .env en editor
  - `list-images` - Lista imágenes Docker del proyecto
  - `clean-volumes` - Limpia volúmenes no usados
  - `clean-images` - Limpia imágenes no usadas
  - `clean-networks` - Limpia redes no usadas
  - `rotate-secrets` - Rota secretos y actualiza .env
  - `export-config` - Exporta configuración a JSON/YAML
  - `export-metrics` - Exporta métricas a JSON/Prometheus
- **Documentación completa**:
  - `README.md` mejorado con arquitectura, casos de uso, instalación e integración
  - `docs/INTEGRATION_GUIDE.md` - Guía completa de integración
  - `docs/HELPERS.md` - Documentación de todos los helpers
  - `docs/GUIA_DESARROLLO.md` - Guía para crear nuevos scripts
  - `docs/ESTANDARES_OBLIGATORIOS.md` - Estándares de calidad
  - `CONTRIBUTING.md` - Guía de contribución
- **Tests automatizados**:
  - `test-init.sh` - Tests para `init.sh`
  - `test-services.sh` - Tests para `services.sh`
- **CI/CD**:
  - GitHub Actions workflow (`.github/workflows/ci.yml`)
  - Verificación automática de sintaxis, longitud de líneas, uso de helpers
  - Ejecución automática de tests

### Changed
- **Refactorización masiva**: Migración de scripts a usar helpers comunes
  - 30 scripts ahora usan `init.sh` (67% de scripts en `commands/`)
  - 16 scripts usan `services.sh` (36%)
  - 5 scripts usan `validation.sh` (11%)
  - 5 scripts usan `error-handling.sh` (11%)
  - 4 scripts usan `docker-compose.sh` (9%)
- **Reducción de duplicación**: ~81% menos código duplicado
- **Mejora de calidad**: Todos los scripts nuevos siguen estándares obligatorios
- **Logging unificado**: Todos los scripts usan sistema de logging centralizado

### Fixed
- Corrección de validación de versiones en `check-versions.sh`
- Mejora en detección de Docker Compose v1/v2
- Corrección de manejo de errores en varios scripts
- Validación mejorada de argumentos en múltiples comandos

### Security
- Sanitización de secretos en logs
- Validación mejorada de contraseñas
- Integración con Infisical para gestión de secretos

---

## [2.2.0] - 2024-12-XX

### Added
- Comando `check-updates` - Verifica actualizaciones disponibles
- Comando `check-version-compatibility` - Valida compatibilidad de versiones
- Comando `update-images` - Actualiza imágenes Docker
- Comando `rotate-secrets` - Rota secretos de forma segura
- Sistema de logging mejorado con niveles y colores

### Changed
- Mejora en detección automática de servicios desde `.env`
- Optimización de comandos de backup
- Mejora en mensajes de error y validación

### Fixed
- Corrección en manejo de redes Docker
- Mejora en validación de puertos
- Corrección de bugs en scripts de backup

---

## [2.1.0] - 2024-11-XX

### Added
- Comando `aggregate-logs` - Agrega logs de múltiples servicios
- Comando `alerts` - Sistema de alertas para servicios
- Comando `metrics` - Métricas de rendimiento
- Comando `save-state` - Guarda estado del sistema
- Comando `rollback` - Revierte a estado anterior
- Comando `restore-all` - Restaura todos los servicios desde backup

### Changed
- Reorganización de estructura de directorios
- Mejora en sistema de validación
- Optimización de comandos de monitoreo

---

## [2.0.0] - 2024-10-XX

### Added
- **Refactorización completa del proyecto**
- Sistema modular con Makefiles organizados por dominio
- Separación clara entre Makefiles (wrappers) y scripts Bash (lógica)
- Sistema de logging centralizado
- Helpers comunes para funciones reutilizables
- Comandos principales:
  - `validate` - Validación completa de configuración
  - `backup-all` - Backup de todos los servicios
  - `start` / `stop` - Gestión de servicios
  - `check-dependencies` - Verificación de prerrequisitos
  - `check-ports` - Verificación de puertos
  - `validate-ips` - Validación de IPs
  - `validate-passwords` - Validación de contraseñas
- Integración con Infisical para gestión de secretos
- Sistema de versionado semántico

### Changed
- **BREAKING**: Cambio completo de estructura de proyecto
- **BREAKING**: Nuevos nombres de comandos y estructura
- Migración de scripts antiguos a nueva estructura

### Removed
- Scripts y comandos obsoletos de versiones anteriores
- Código duplicado y no mantenido

---

## [1.0.0] - 2024-09-XX

### Added
- Versión inicial de dev-toolbox
- Comandos básicos de gestión de servicios Docker
- Validación de configuración básica
- Sistema de backups básico
- Integración con Docker Compose

---

## Tipos de Cambios

- **Added** - Para nuevas funcionalidades
- **Changed** - Para cambios en funcionalidades existentes
- **Deprecated** - Para funcionalidades que serán eliminadas
- **Removed** - Para funcionalidades eliminadas
- **Fixed** - Para correcciones de bugs
- **Security** - Para mejoras de seguridad

---

## Notas de Versión

### Versionado Semántico

Este proyecto sigue [Semantic Versioning](https://semver.org/lang/es/):
- **MAJOR** (X.0.0) - Cambios incompatibles en la API
- **MINOR** (0.X.0) - Nuevas funcionalidades compatibles hacia atrás
- **PATCH** (0.0.X) - Correcciones de bugs compatibles hacia atrás

### Proceso de Release

El proceso de release está automatizado. Ver [docs/RELEASE_PROCESS.md](docs/RELEASE_PROCESS.md) para detalles completos.

**Comando rápido**:
```bash
make release PART=patch
```

**Pasos automáticos**:
1. Ejecuta tests
2. Actualiza versión en `.version`, `.env`, `README.md`, `CHANGELOG.md`
3. Genera release notes desde `CHANGELOG.md`
4. Crea tag de Git: `vX.Y.Z`
5. Hace commit de cambios
6. Publica tag: `git push origin vX.Y.Z` (manual)
7. Crea release en GitHub (manual o automático con GitHub Actions)

---

*Para más información sobre el proyecto, ver [README.md](README.md)*
