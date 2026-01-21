# TODO - Plan de Mejoras para dev-toolbox

> Basado en el análisis del proyecto realizado. Este documento organiza las mejoras pendientes en fases priorizadas.

**Estado General**: 🟢 Proyecto sólido - Mejoras incrementales necesarias
**Última actualización**: Enero 2025

---

## 📋 Índice

- [Fase 1: Prioridad Alta - Cobertura de Tests](#fase-1-prioridad-alta---cobertura-de-tests)
- [Fase 2: Prioridad Media - Robustez y Confiabilidad](#fase-2-prioridad-media---robustez-y-confiabilidad)
- [Fase 3: Prioridad Media-Baja - Features Avanzadas](#fase-3-prioridad-media-baja---features-avanzadas)
- [Fase 4: Prioridad Baja - Extensibilidad](#fase-4-prioridad-baja---extensibilidad)

---

## ✅ Tareas Completadas (Eliminadas del TODO)

Las siguientes fases y tareas han sido completadas y eliminadas de este documento:

### Fase 1: Documentación y Fundamentos ✅
- ✅ Mejora de README.md
- ✅ Guías de documentación (12 guías completas)
- ✅ Guía de contribución
- ✅ CHANGELOG.md
- ✅ Automatización de versionado
- ✅ Proceso de release
- ✅ Validación de prerrequisitos
- ✅ Manejo de servicios no encontrados
- ✅ Validación de red Docker

### Fase 2: Testing y Calidad ✅
- ✅ Setup de framework de testing (BATS)
- ✅ Tests para scripts de comandos
- ✅ Tests para scripts de setup
- ✅ Tests para scripts de utils
- ✅ Tests end-to-end
- ✅ Tests de compatibilidad
- ✅ Linting y formateo
- ✅ Documentación de código

### Fase 3: Performance ✅
- ✅ Paralelización de backups
- ✅ Caché de validaciones
- ✅ Optimización de aggregate-logs

### Fase 4: Seguridad y Versiones ✅
- ✅ Gestión de secretos mejorada (keychain)
- ✅ Auditoría de seguridad
- ✅ Base de datos de versiones
- ✅ Verificación de dependencias mejorada

### Fase 5: Logging y Windows ✅
- ✅ Logging a archivo con rotación automática
- ✅ Sanitización de logs
- ✅ Documentación de WSL
- ✅ Scripts PowerShell básicos

---

## Fase 1: Prioridad Alta - Cobertura de Tests

**Prioridad**: 🔴 Alta
**Duración estimada**: 4-6 semanas
**Objetivo**: Aumentar cobertura de tests de ~37% a > 80%

### 1.1 Tests para Comandos Principales Sin Cobertura

**Estado actual**: 30/82 scripts tienen tests (~37% cobertura)

#### Tarea 1.1.1: Tests para Comandos de Gestión
- [ ] Tests para `build.sh` (parcial - 5 tests básicos, agregar más casos)
- [ ] Tests para `rebuild.sh`
- [ ] Tests para `clean.sh`
- [ ] Tests para `prune.sh`
- [ ] Tests para `start.sh`
- [ ] Tests para `stop.sh`
- [ ] Tests para `restart.sh`

**Criterios de aceptación**:
- Cada comando tiene mínimo 5-8 tests
- Cubren casos exitosos, errores, y edge cases
- Tests no requieren entorno Docker real (mocks)

**Esfuerzo**: 1-2 semanas

---

#### Tarea 1.1.2: Tests para Comandos de Información
- [ ] Tests para `info.sh`
- [ ] Tests para `list-services.sh`
- [ ] Tests para `list-volumes.sh`
- [ ] Tests para `list-networks.sh`
- [ ] Tests para `list-images.sh`
- [ ] Tests para `list-states.sh`
- [ ] Tests para `config-show.sh`
- [ ] Tests para `env-show.sh`
- [ ] Tests para `env-edit.sh`

**Criterios de aceptación**:
- Tests verifican formato de salida
- Tests verifican manejo de errores
- Tests verifican casos con/sin servicios

**Esfuerzo**: 1 semana

---

#### Tarea 1.1.3: Tests para Comandos de Configuración
- [ ] Tests para `export-config.sh`
- [ ] Tests para `export-metrics.sh`
- [ ] Tests para `rotate-secrets.sh`
- [ ] Tests para `check-updates.sh`
- [ ] Tests para `check-versions.sh`
- [ ] Tests para `update-images.sh`
- [ ] Tests para `update-service-versions.sh`

**Criterios de aceptación**:
- Tests verifican exportación correcta
- Tests verifican validación de entrada
- Tests verifican manejo de errores

**Esfuerzo**: 1 semana

---

#### Tarea 1.1.4: Tests para Comandos de Operaciones
- [ ] Tests para `exec.sh`
- [ ] Tests para `shell.sh`
- [ ] Tests para `logs.sh`
- [ ] Tests para `test-connectivity.sh`
- [ ] Tests para `rollback.sh`
- [ ] Tests para `save-state.sh`
- [ ] Tests para `verify-installation.sh`

**Criterios de aceptación**:
- Tests verifican ejecución correcta
- Tests verifican validación de parámetros
- Tests verifican manejo de errores

**Esfuerzo**: 1 semana

---

### 1.2 Tests para Scripts de Utils Sin Cobertura

#### Tarea 1.2.1: Tests para Utils de Configuración
- [ ] Tests para `ensure-network.sh` (parcial - tests de integración, agregar unitarios)
- [ ] Tests para `detect-os.sh`
- [ ] Tests para `keychain.sh`
- [ ] Tests para `log-file-manager.sh`
- [ ] Tests para `verify-version.sh`
- [ ] Tests para `update-changelog.sh`
- [ ] Tests para `update-service-versions.sh`

**Criterios de aceptación**:
- Tests unitarios para cada función
- Tests de integración para flujos completos
- Tests verifican edge cases

**Esfuerzo**: 1 semana

---

### 1.3 Tests para Scripts de Setup y Backup

#### Tarea 1.3.1: Tests para Scripts de Setup
- [ ] Tests para `install-dependencies.sh`
- [ ] Tests para `install-pre-commit.sh`
- [ ] Tests para `load-toolbox.sh` (parcial - agregar más casos)

**Criterios de aceptación**:
- Tests verifican instalación correcta
- Tests verifican detección de dependencias
- Tests verifican manejo de errores

**Esfuerzo**: 3-4 días

---

#### Tarea 1.3.2: Tests para Scripts de Backup
- [ ] Tests para `backup-storage.sh`
- [ ] Tests para `restore-interactive.sh`
- [ ] Tests para `setup-backup-schedule.sh`

**Criterios de aceptación**:
- Tests verifican creación de backups
- Tests verifican restauración
- Tests verifican validación de archivos

**Esfuerzo**: 3-4 días

---

### 1.4 Mejora de Tests Existentes

#### Tarea 1.4.1: Agregar Casos Edge a Tests Existentes
- [ ] Agregar tests para casos de error en tests existentes
- [ ] Agregar tests para validación de entrada en tests existentes
- [ ] Agregar tests para límites y edge cases

**Criterios de aceptación**:
- Tests existentes cubren más casos
- Cobertura de código aumenta

**Esfuerzo**: 1 semana

---

## Fase 2: Prioridad Media - Robustez y Confiabilidad

**Prioridad**: 🟡 Media
**Duración estimada**: 3-4 semanas
**Objetivo**: Mejorar robustez y confiabilidad del sistema

### 2.1 Modo Dry-Run

#### Tarea 2.1.1: Implementar Dry-Run para Comandos Destructivos
- [ ] Agregar `--dry-run` a `clean.sh`
- [ ] Agregar `--dry-run` a `restore-all.sh`
- [ ] Agregar `--dry-run` a `rollback.sh`
- [ ] Agregar `--dry-run` a `update-images.sh`
- [ ] Agregar `--dry-run` a `prune.sh`
- [ ] Mostrar qué se haría sin ejecutar
- [ ] Validar que dry-run muestra acciones correctas

**Criterios de aceptación**:
- Todos los comandos destructivos tienen `--dry-run`
- Dry-run muestra acciones exactas que se ejecutarían
- Dry-run no ejecuta ninguna acción destructiva

**Esfuerzo**: 3-4 días

---

### 2.2 Retry Logic

#### Tarea 2.2.1: Implementar Retry con Backoff Exponencial
- [ ] Agregar retry para conexiones a Docker
- [ ] Agregar retry para conexiones a Infisical
- [ ] Agregar retry para operaciones de red
- [ ] Configurar número máximo de reintentos
- [ ] Implementar backoff exponencial
- [ ] Logs claros de reintentos

**Criterios de aceptación**:
- Comandos se recuperan de errores temporales
- Retry no es infinito
- Backoff exponencial funciona correctamente

**Esfuerzo**: 2-3 días

---

### 2.3 Timeouts

#### Tarea 2.3.1: Agregar Timeouts a Operaciones Largas
- [ ] Agregar timeout a `wait-for-service.sh`
- [ ] Agregar timeout a conexiones a APIs externas
- [ ] Agregar timeout a operaciones de Docker largas
- [ ] Mensajes claros cuando timeout ocurre
- [ ] Timeouts configurables por variable de entorno

**Criterios de aceptación**:
- Ningún comando puede colgarse indefinidamente
- Timeouts son razonables y configurables
- Mensajes de timeout son claros

**Esfuerzo**: 2 días

---

## Fase 3: Prioridad Media-Baja - Features Avanzadas

**Prioridad**: 🟢 Baja-Media
**Duración estimada**: 4-6 semanas
**Objetivo**: Agregar features avanzadas y optimizaciones

### 3.1 Monitoreo Avanzado

#### Tarea 3.1.1: Dashboard Mejorado
- [ ] Mejorar `make dashboard` con:
  - Métricas en tiempo real
  - Gráficos ASCII (opcional)
  - Historial de métricas
  - Alertas visuales
- [ ] Opción `--watch` para actualización continua
- [ ] Exportación de dashboard a HTML

**Criterios de aceptación**:
- Dashboard es más informativo
- Actualización en tiempo real funciona
- Dashboard es útil para monitoreo

**Esfuerzo**: 1 semana

---

### 3.2 Backup y Restore Avanzados

#### Tarea 3.2.1: Backup Incremental
- [ ] Implementar backups incrementales
- [ ] Detección de cambios desde último backup
- [ ] Compresión mejorada
- [ ] Verificación de integridad de backups
- [ ] Opción `--incremental` para activar

**Criterios de aceptación**:
- Backups incrementales funcionan correctamente
- Ahorro de espacio significativo
- Integridad verificada

**Esfuerzo**: 1-2 semanas

---

#### Tarea 3.2.2: Restore Selectivo
- [ ] Restaurar solo servicios específicos
- [ ] Restaurar solo volúmenes específicos
- [ ] Preview de qué se restaurará
- [ ] Validación antes de restaurar
- [ ] Opción `--service=SERVICE` para restaurar servicio específico

**Criterios de aceptación**:
- Restore selectivo funciona correctamente
- Preview es preciso
- Validación previene errores

**Esfuerzo**: 1 semana

---

### 3.3 Actualización Automática de Versiones

#### Tarea 3.3.1: Mejorar check-updates
- [ ] Mejorar `make check-updates` para:
  - Verificar versiones disponibles más precisamente
  - Sugerir actualizaciones con razones
  - Mostrar changelogs relevantes
  - Comparar versiones actuales vs disponibles
- [ ] Opción `--auto-update` para actualizar automáticamente (con confirmación)
- [ ] Integración con base de datos de versiones

**Criterios de aceptación**:
- Detecta actualizaciones disponibles correctamente
- Sugerencias son útiles y accionables
- Auto-update funciona de forma segura

**Esfuerzo**: 1 semana

---

## Fase 4: Prioridad Baja - Extensibilidad

**Prioridad**: 🔵 Baja
**Duración estimada**: 6-8 semanas
**Objetivo**: Preparar para integraciones futuras y extensibilidad

### 4.1 Integraciones

#### Tarea 4.1.1: Integración con Kubernetes
- [ ] Comandos básicos para Kubernetes
- [ ] Validación de configuraciones K8s
- [ ] Backup de recursos K8s
- [ ] Monitoreo de pods
- [ ] Detección automática de entorno (Docker vs K8s)

**Criterios de aceptación**:
- Funcionalidad básica funciona con K8s
- No rompe compatibilidad con Docker
- Comandos son consistentes entre Docker y K8s

**Esfuerzo**: 2-3 semanas

---

#### Tarea 4.1.2: Templates de CI/CD
- [ ] GitHub Actions templates mejorados
- [ ] GitLab CI templates
- [ ] Jenkins pipeline examples
- [ ] Comandos optimizados para CI
- [ ] Documentación de integración CI/CD

**Criterios de aceptación**:
- Templates funcionan out-of-the-box
- Documentación clara
- Ejemplos funcionan

**Esfuerzo**: 1 semana

---

### 4.2 Extensibilidad

#### Tarea 4.2.1: Sistema de Plugins
- [ ] Arquitectura de plugins
- [ ] API para plugins
- [ ] Ejemplos de plugins
- [ ] Documentación de desarrollo de plugins
- [ ] Sistema de carga de plugins

**Criterios de aceptación**:
- Plugins pueden agregarse fácilmente
- API es estable y documentada
- Ejemplos funcionan

**Esfuerzo**: 2-3 semanas

---

#### Tarea 4.2.2: Configuración Avanzada
- [ ] Archivo de configuración YAML/JSON
- [ ] Perfiles de configuración
- [ ] Override de configuración por proyecto
- [ ] Validación de configuración
- [ ] Migración desde .env a configuración avanzada

**Criterios de aceptación**:
- Configuración es flexible
- No rompe compatibilidad con .env
- Validación funciona correctamente

**Esfuerzo**: 1-2 semanas

---

## 📊 Resumen de Fases Pendientes

| Fase | Prioridad | Duración | Esfuerzo Total |
|------|-----------|----------|----------------|
| **Fase 1** | 🔴 Alta | 4-6 semanas | ~25-30 días |
| **Fase 2** | 🟡 Media | 3-4 semanas | ~10-12 días |
| **Fase 3** | 🟢 Baja-Media | 4-6 semanas | ~20-25 días |
| **Fase 4** | 🔵 Baja | 6-8 semanas | ~30-40 días |
| **TOTAL** | - | 17-24 semanas | ~85-107 días |

---

## 🎯 Priorización Recomendada

### Sprint 1-3 (6 semanas) - Cobertura de Tests
- Fase 1 completa
- Objetivo: Aumentar cobertura de ~37% a > 60%

### Sprint 4-5 (4 semanas) - Robustez
- Fase 2 completa
- Objetivo: Mejorar confiabilidad con dry-run, retry, timeouts

### Sprint 6-8 (6 semanas) - Features Avanzadas
- Fase 3 completa
- Objetivo: Dashboard mejorado, backups incrementales, restore selectivo

### Sprint 9+ (Ongoing) - Extensibilidad
- Fase 4 según necesidades
- Mantenimiento y mejoras incrementales

---

## 📝 Notas de Implementación

### Convenciones
- Todas las tareas deben tener tests asociados
- Documentación debe actualizarse con cada cambio
- Commits deben seguir `COMMIT_GUIDELINES.md`
- PRs deben pasar todos los tests y linters

### Métricas de Éxito
- Cobertura de tests > 80% (actual: ~37%)
- 0 warnings críticos de shellcheck
- Documentación completa y actualizada
- Todos los comandos tienen `--help` o documentación equivalente
- CI/CD pasa en todos los entornos soportados

---

## 🔄 Mantenimiento Continuo

### Tareas Recurrentes
- [ ] Revisar y actualizar dependencias mensualmente
- [ ] Actualizar documentación con cada release
- [ ] Revisar y cerrar issues antiguos trimestralmente
- [ ] Actualizar base de datos de versiones según nuevas releases
- [ ] Revisar y mejorar tests según feedback
- [ ] Actualizar métricas de cobertura mensualmente
- [ ] Revisar y actualizar `system-requirements.json` según nuevas versiones

---

## 📈 Progreso Actual

### Cobertura de Tests
- **Scripts analizados**: 82
- **Scripts con tests**: 30
- **Cobertura actual**: ~37%
- **Objetivo**: > 80%
- **Scripts sin tests**: 52

### Scripts Prioritarios para Tests
1. Comandos de gestión (build, rebuild, clean, start, stop)
2. Comandos de información (info, list-*)
3. Comandos de configuración (export-*, rotate-secrets)
4. Scripts de utils (ensure-network, keychain, log-file-manager)

---

*Última actualización: Enero 2025*
*Versión del plan: 2.0*
