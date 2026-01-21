# Configuración de Logging

Esta guía explica cómo configurar y usar el sistema de logging a archivo en `dev-toolbox`, incluyendo rotación automática, límites de tamaño y limpieza de logs antiguos.

---

## 📋 Configuración Básica

### Variables de Entorno

El sistema de logging puede configurarse mediante variables de entorno:

```bash
# Directorio base para logs (default: PROJECT_ROOT/logs)
export LOG_DIR=logs

# Tamaño máximo de archivo en MB antes de rotar (default: 10)
export LOG_MAX_SIZE=10

# Días de retención de logs antiguos (default: 30)
export LOG_RETENTION_DAYS=30

# Número máximo de archivos rotados a mantener (default: 5)
export LOG_MAX_FILES=5

# Comprimir logs rotados (default: false)
export LOG_COMPRESS=false

# Archivo de log específico para un script
export LOG_FILE=logs/my-script.log
```

### Archivo de Configuración Centralizada

Crea un archivo `.logging-config` en la raíz del proyecto para configuración centralizada:

```bash
# .logging-config
LOG_DIR=logs
LOG_MAX_SIZE=10
LOG_RETENTION_DAYS=30
LOG_MAX_FILES=5
LOG_COMPRESS=false
```

El archivo se carga automáticamente cuando se usa el sistema de logging.

---

## 🚀 Uso Básico

### Habilitar Logging a Archivo en un Script

```bash
#!/usr/bin/env bash
source "$COMMON_SCRIPTS_DIR/init.sh"
init_script

# Configurar archivo de log (opcional)
export LOG_FILE="logs/my-script.log"

# Usar funciones de logging normalmente
log_info "Este mensaje se escribirá en el archivo de log"
log_error "Los errores también se registran"
```

### Usar Helper de Log File Manager

```bash
#!/usr/bin/env bash
source "$COMMON_SCRIPTS_DIR/init.sh"
source "$UTILS_DIR/log-file-manager.sh"

# Configurar archivo de log con rotación automática
LOG_FILE=$(setup_log_file "logs/my-script.log" "my-script")

# Usar logging normalmente - la rotación es automática
log_info "Mensaje de log"
```

---

## 🔄 Rotación de Logs

### Rotación Automática

El sistema rota logs automáticamente cuando:

1. **Excede tamaño máximo**: Si el archivo excede `LOG_MAX_SIZE` MB
2. **Al iniciar script**: Si `LOG_ROTATE_ON_INIT=true` (default: true)
3. **Durante ejecución**: Verificación periódica cada 100 líneas

### Formato de Archivos Rotados

Cuando un log se rota, se crea un archivo con timestamp:

```
logs/
├── my-script.log              # Archivo actual
├── my-script.log.20250120_143022  # Archivo rotado
├── my-script.log.20250119_120045  # Archivo rotado anterior
└── my-script.log.20250118_095123  # Archivo rotado más antiguo
```

Si `LOG_COMPRESS=true`, los archivos rotados se comprimen:

```
logs/
├── my-script.log
├── my-script.log.20250120_143022.gz
└── my-script.log.20250119_120045.gz
```

### Rotar Manualmente

```bash
# Rotar todos los logs (contenedores y archivos)
make rotate-logs

# Solo logs de contenedores Docker
make rotate-logs LOG_ROTATE_OPTS="--containers-only"

# Solo archivos de log del sistema
make rotate-logs LOG_ROTATE_OPTS="--files-only"

# Especificar días de retención
make rotate-logs LOG_RETENTION_DAYS=7

# O directamente
./scripts/sh/utils/rotate-logs.sh 7
```

---

## 🧹 Limpieza de Logs Antiguos

### Limpieza Automática

Los logs antiguos se eliminan automáticamente cuando:

- Se ejecuta `make rotate-logs`
- Los archivos son más antiguos que `LOG_RETENTION_DAYS`
- Se mantiene solo `LOG_MAX_FILES` archivos rotados

### Limpiar Manualmente

```bash
# Limpiar logs antiguos
make clean-logs

# Especificar días de retención
make clean-logs LOG_RETENTION_DAYS=7

# O usar el helper directamente
source scripts/sh/utils/log-file-manager.sh
cleanup_old_logs "logs/"
```

---

## 📊 Configuración Avanzada

### Configurar por Script

Cada script puede tener su propia configuración:

```bash
#!/usr/bin/env bash
# Configuración específica del script
export LOG_FILE="logs/backup-all.log"
export LOG_MAX_SIZE=50  # 50 MB para este script
export LOG_ROTATE_ON_INIT=true

source "$COMMON_SCRIPTS_DIR/init.sh"
init_script
```

### Configurar para Todo el Proyecto

Crea `.logging-config` en la raíz:

```bash
# .logging-config
# Configuración global para todos los scripts

# Directorio de logs
LOG_DIR=logs

# Tamaño máximo antes de rotar (en MB)
LOG_MAX_SIZE=10

# Días de retención
LOG_RETENTION_DAYS=30

# Máximo archivos rotados
LOG_MAX_FILES=5

# Comprimir logs rotados (ahorra espacio)
LOG_COMPRESS=false
```

### Ejemplo de Configuración para Producción

```bash
# .logging-config (producción)
LOG_DIR=/var/log/dev-toolbox
LOG_MAX_SIZE=100
LOG_RETENTION_DAYS=90
LOG_MAX_FILES=10
LOG_COMPRESS=true
```

---

## 🔧 Funciones Disponibles

### Helper: log-file-manager.sh

```bash
source scripts/sh/utils/log-file-manager.sh

# Obtener directorio de logs configurado
log_dir=$(get_log_dir)

# Configurar archivo de log
log_file=$(setup_log_file "logs/script.log" "script-name")

# Rotar si es necesario
rotate_log_if_needed "logs/script.log"

# Limpiar logs antiguos
deleted_count=$(cleanup_old_logs "logs/")

# Obtener configuración
get_log_config
echo "Max size: ${LOG_MAX_SIZE_MB}MB"
echo "Retention: ${LOG_RETENTION_DAYS} days"
```

---

## 📝 Ejemplos de Uso

### Ejemplo 1: Script con Logging Automático

```bash
#!/usr/bin/env bash
source "$COMMON_SCRIPTS_DIR/init.sh"
init_script

# El archivo de log se configurará automáticamente si LOG_FILE está definido
export LOG_FILE="logs/my-script.log"

log_info "Iniciando script..."
# ... código del script ...
log_success "Script completado"
```

### Ejemplo 2: Script con Configuración Personalizada

```bash
#!/usr/bin/env bash
# Configuración específica
export LOG_MAX_SIZE=20
export LOG_RETENTION_DAYS=7
export LOG_FILE="logs/custom-script.log"

source "$COMMON_SCRIPTS_DIR/init.sh"
source "$UTILS_DIR/log-file-manager.sh"

# Setup explícito
setup_log_file "$LOG_FILE" "custom-script"

log_info "Script con configuración personalizada"
```

### Ejemplo 3: Rotación Programada

Agrega a crontab para rotación automática:

```bash
# Rotar logs diariamente a las 2 AM
0 2 * * * cd /ruta/al/proyecto && make rotate-logs
```

O usa systemd timer (Linux):

```ini
# /etc/systemd/system/rotate-logs.service
[Unit]
Description=Rotate dev-toolbox logs
After=network.target

[Service]
Type=oneshot
WorkingDirectory=/ruta/al/proyecto
ExecStart=/usr/bin/make rotate-logs
```

---

## ⚠️ Solución de Problemas

### Error: "No se puede escribir en archivo de log"

**Causa**: Permisos insuficientes o directorio no existe.

**Solución**:
```bash
# Crear directorio de logs
mkdir -p logs

# Verificar permisos
chmod 755 logs

# Verificar permisos de escritura
touch logs/test.log && rm logs/test.log
```

### Logs no se están rotando

**Causa**: `LOG_MAX_SIZE` muy grande o rotación deshabilitada.

**Solución**:
```bash
# Verificar tamaño actual
ls -lh logs/*.log

# Reducir tamaño máximo
export LOG_MAX_SIZE=5  # 5 MB

# Habilitar rotación al iniciar
export LOG_ROTATE_ON_INIT=true
```

### Logs ocupan mucho espacio

**Solución**:
```bash
# Configurar retención más corta
export LOG_RETENTION_DAYS=7

# Habilitar compresión
export LOG_COMPRESS=true

# Limpiar manualmente
make clean-logs LOG_RETENTION_DAYS=7
```

### Múltiples scripts escriben al mismo log

**Solución**: Usar archivos de log separados por script:

```bash
# Script 1
export LOG_FILE="logs/script1.log"

# Script 2
export LOG_FILE="logs/script2.log"
```

---

## 📖 Referencias

- **Sistema de Logging**: `scripts/sh/common/logging.sh`
- **Log File Manager**: `scripts/sh/utils/log-file-manager.sh`
- **Rotación de Logs**: `scripts/sh/utils/rotate-logs.sh`
- **Makefile**: `make rotate-logs`, `make clean-logs`

---

## 🔗 Comandos Make

```bash
# Rotar todos los logs
make rotate-logs

# Limpiar logs antiguos
make clean-logs

# Configurar variables
make rotate-logs LOG_RETENTION_DAYS=7 LOG_DIR=/var/log
```

---

**Última actualización**: Enero 2025
