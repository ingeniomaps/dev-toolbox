# Helpers Comunes - Documentación Completa

> Documentación completa de todos los helpers disponibles en `scripts/sh/common/`

## 📚 Índice

- [init.sh](#initsh) - Inicialización de scripts
- [services.sh](#servicessh) - Gestión de servicios Docker
- [validation.sh](#validationsh) - Validación de argumentos
- [error-handling.sh](#error-handlingsh) - Manejo de errores
- [docker-compose.sh](#docker-composesh) - Interacción con Docker Compose
- [logging.sh](#loggingsh) - Sistema de logging
- [colors.sh](#colorssh) - Colores ANSI

---

## init.sh

**Ubicación**: `scripts/sh/common/init.sh`  
**Propósito**: Inicialización estándar de scripts

### Uso Básico

```bash
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"

# Cargar helpers comunes
if [[ -f "$COMMON_SCRIPTS_DIR/init.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/init.sh"
	init_script
fi
```

### Funciones

#### `init_script()`

Inicializa rutas, carga logging y establece variables comunes.

**Variables exportadas**:
- `SCRIPT_DIR` - Directorio del script actual
- `COMMON_SCRIPTS_DIR` - Directorio de scripts comunes
- `PROJECT_ROOT` - Raíz del proyecto (normalizada)

#### `get_project_root()`

Obtiene PROJECT_ROOT de forma consistente.

**Retorna**: Ruta del proyecto sin trailing slash

#### `get_common_dir()`

Obtiene COMMON_SCRIPTS_DIR de forma consistente.

**Retorna**: Ruta al directorio de scripts comunes

### Ejemplo Completo

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMMON_SCRIPTS_DIR="$SCRIPT_DIR/../common"

# Cargar helpers comunes
if [[ -f "$COMMON_SCRIPTS_DIR/init.sh" ]]; then
	source "$COMMON_SCRIPTS_DIR/init.sh"
	init_script
fi

# Ahora puedes usar PROJECT_ROOT, logging, etc.
log_info "Script ejecutándose desde: $PROJECT_ROOT"
```

---

## services.sh

**Ubicación**: `scripts/sh/common/services.sh`  
**Propósito**: Detección y gestión de servicios Docker

### Uso Básico

```bash
source "$COMMON_SCRIPTS_DIR/services.sh"
SERVICES_LIST=$(detect_services_from_env "$ENV_FILE")
```

### Funciones

#### `detect_services_from_env(env_file)`

Detecta servicios desde variables `*_VERSION` en .env.

**Parámetros**:
- `$1` - Ruta al archivo .env (default: `$PROJECT_ROOT/.env`)

**Retorna**: Lista de servicios separados por espacios

**Ejemplo**:
```bash
SERVICES_LIST=$(detect_services_from_env "$PROJECT_ROOT/.env")
# Resultado: "postgres mongo redis"
```

#### `get_container_name(service, prefix)`

Obtiene nombre de contenedor con prefijo si está definido.

**Parámetros**:
- `$1` - Nombre del servicio
- `$2` - Prefijo opcional (default: `$SERVICE_PREFIX`)

**Retorna**: Nombre del contenedor

**Ejemplo**:
```bash
CONTAINER_NAME=$(get_container_name "postgres")
# Resultado: "postgres" o "myapp-postgres" si SERVICE_PREFIX está definido
```

#### `is_container_running(container_name)`

Verifica si un contenedor está corriendo.

**Parámetros**:
- `$1` - Nombre del contenedor

**Retorna**: 0 si está corriendo, 1 si no

**Ejemplo**:
```bash
if is_container_running "$CONTAINER_NAME"; then
	log_success "Contenedor está corriendo"
fi
```

#### `get_service_version(service, env_file)`

Obtiene versión de un servicio desde .env.

**Parámetros**:
- `$1` - Nombre del servicio
- `$2` - Ruta al archivo .env (default: `$PROJECT_ROOT/.env`)

**Retorna**: Versión del servicio o cadena vacía

**Ejemplo**:
```bash
VERSION=$(get_service_version "postgres" "$ENV_FILE")
# Resultado: "15.0" si POSTGRES_VERSION=15.0 en .env
```

#### `service_exists(service, command_type, project_root)`

Verifica si un servicio existe (tiene contenedor o comando make disponible).

**Parámetros**:
- `$1` - Nombre del servicio
- `$2` - Tipo de comando a verificar (backup, restore, up, etc.) (opcional)
- `$3` - PROJECT_ROOT para verificar comandos make (opcional)

**Retorna**: 0 si existe, 1 si no

**Ejemplo**:
```bash
if service_exists "postgres" "backup" "$PROJECT_ROOT"; then
	log_info "Servicio postgres existe"
fi
```

**Nota**: Esta función verifica:
1. Si el contenedor existe (corriendo o detenido)
2. Si el comando make está disponible (si se especifica `command_type`)
3. Si está definido en .env

---

## validation.sh

**Ubicación**: `scripts/sh/common/validation.sh`  
**Propósito**: Validación de argumentos, parámetros, archivos y prerrequisitos

### Uso Básico

```bash
source "$COMMON_SCRIPTS_DIR/validation.sh"
validate_required_args 2 "$0 <service> <command>" "$@"
```

### Funciones

#### `validate_required_args(min_args, usage_msg, ...)`

Valida que se hayan proporcionado los argumentos requeridos.

**Parámetros**:
- `$1` - Número mínimo de argumentos requeridos
- `$2` - Mensaje de uso (opcional)
- `$@` - Argumentos a validar

**Retorna**: 0 si válido, 1 si inválido

**Ejemplo**:
```bash
if ! validate_required_args 2 "$0 <service> <command>" "$@"; then
	exit 1
fi
```

#### `validate_optional_args(name, value, type)`

Valida argumentos opcionales con tipos.

**Parámetros**:
- `$1` - Nombre del argumento
- `$2` - Valor del argumento
- `$3` - Tipo esperado: `string`, `number`, `port`, `ip`, `email`, `url`, `file`, `dir`

**Retorna**: 0 si válido, 1 si inválido

**Ejemplo**:
```bash
validate_optional_args "PORT" "$PORT" "port"
validate_optional_args "EMAIL" "$EMAIL" "email"
```

#### `validate_env_var(var_name, error_msg, suggestion)`

Valida que una variable de entorno esté definida.

**Parámetros**:
- `$1` - Nombre de la variable
- `$2` - Mensaje de error opcional
- `$3` - Sugerencia de solución opcional

**Ejemplo**:
```bash
validate_env_var "NETWORK_NAME" "NETWORK_NAME debe estar definida" \
	"Ejecuta 'make init-env' o define NETWORK_NAME en .env"
```

#### `validate_env_file(env_file, error_msg)`

Valida que el archivo `.env` exista.

**Parámetros**:
- `$1` - Ruta al archivo .env (opcional, default: PROJECT_ROOT/.env)
- `$2` - Mensaje de error personalizado (opcional)

**Ejemplo**:
```bash
if ! validate_env_file "$ENV_FILE"; then
	exit 1
fi
```

#### `validate_env_vars_in_file(env_file, required_vars, error_msg)`

Valida que variables requeridas estén definidas en `.env`.

**Parámetros**:
- `$1` - Ruta al archivo .env (opcional)
- `$2` - Lista de variables requeridas separadas por espacios o comas
- `$3` - Mensaje de error personalizado (opcional)

**Ejemplo**:
```bash
validate_env_vars_in_file "$ENV_FILE" "NETWORK_NAME NETWORK_IP"
```

#### `validate_prerequisites(prerequisites, required_vars)`

Valida prerrequisitos comunes (Docker, .env, variables).

**Parámetros**:
- `$1` - Lista de prerrequisitos: `docker`, `docker-compose`, `env-file`, `env-vars`
- `$2` - Variables requeridas en .env (si `env-vars` está en la lista)

**Ejemplo**:
```bash
validate_prerequisites "docker docker-compose env-file" ""
validate_prerequisites "env-vars" "NETWORK_NAME NETWORK_IP"
```

#### `validate_file_exists(file_path, name)` / `validate_dir_exists(dir_path, name)`

Valida existencia de archivos/directorios.

**Ejemplo**:
```bash
validate_file_exists "$ENV_FILE" "Archivo .env"
```

#### `validate_number(value, name)` / `validate_port(port, name)` / `validate_ip(ip, name)`

Valida tipos de datos específicos.

**Ejemplo**:
```bash
validate_port "8080" "PORT"
validate_ip "192.168.1.1" "NETWORK_IP"
```

---

## error-handling.sh

**Ubicación**: `scripts/sh/common/error-handling.sh`  
**Propósito**: Manejo de errores común

### Uso Básico

```bash
source "$COMMON_SCRIPTS_DIR/error-handling.sh"
setup_error_trap
register_cleanup cleanup_function
```

### Funciones

#### `setup_error_trap()`

Configura trap para cleanup automático.

**Ejemplo**:
```bash
setup_error_trap
# Ahora cleanup_on_exit se ejecutará automáticamente al salir
```

#### `register_cleanup(func)`

Registra una función de cleanup.

**Ejemplo**:
```bash
cleanup_temp_files() {
	rm -f /tmp/temp-*
}
register_cleanup cleanup_temp_files
```

#### `handle_error(msg, exit_code, show_trace)`

Maneja errores con mensaje y código de salida.

**Parámetros**:
- `$1` - Mensaje de error
- `$2` - Código de salida (default: 1)
- `$3` - Mostrar stack trace (default: false)

**Ejemplo**:
```bash
handle_error "Operación falló" 1 true
```

#### `retry_command(max_attempts, cmd, ...)`

Reintenta un comando con backoff exponencial.

**Ejemplo**:
```bash
retry_command 3 docker pull "image:tag"
```

#### `safe_exec(cmd, ...)`

Ejecuta comando de forma segura con manejo de errores.

**Ejemplo**:
```bash
safe_exec docker ps
```

---

## docker-compose.sh

**Ubicación**: `scripts/sh/common/docker-compose.sh`  
**Propósito**: Interacción con Docker Compose

### Uso Básico

```bash
source "$COMMON_SCRIPTS_DIR/docker-compose.sh"
DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
```

### Funciones

#### `get_docker_compose_cmd()`

Detecta y retorna el comando de docker compose disponible.

**Retorna**: `"docker compose"` o `"docker-compose"`

**Ejemplo**:
```bash
DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
$DOCKER_COMPOSE_CMD up -d
```

#### `docker_compose_up(project_dir, compose_file, ...)`

Ejecuta docker compose up.

**Parámetros**:
- `$1` - Directorio del proyecto (opcional, default: `PROJECT_ROOT`)
- `$2` - Archivo compose (opcional)
- `$@` - Argumentos adicionales

**Ejemplo**:
```bash
docker_compose_up "$PROJECT_ROOT" "docker-compose.yml" "-d"
```

#### `docker_compose_down(project_dir, compose_file, ...)`

Ejecuta docker compose down.

#### `docker_compose_ps(project_dir, compose_file)`

Lista contenedores de docker compose.

#### `docker_compose_logs(project_dir, compose_file, ...)`

Muestra logs de docker compose.

#### `docker_compose_exec(service, cmd, project_dir, compose_file)`

Ejecuta comando en contenedor.

**Ejemplo**:
```bash
docker_compose_exec "postgres" "psql -U user -d db" "$PROJECT_ROOT"
```

#### `docker_compose_build(project_dir, compose_file, ...)`

Construye imágenes.

#### `docker_compose_pull(project_dir, compose_file)`

Descarga imágenes.

---

## logging.sh

**Ubicación**: `scripts/sh/common/logging.sh`  
**Propósito**: Sistema de logging con niveles

### Funciones Principales

- `log_debug()` - Mensajes de depuración
- `log_info()` - Mensajes informativos
- `log_success()` - Mensajes de éxito
- `log_warn()` - Advertencias
- `log_error()` - Errores
- `log_step()` - Pasos de proceso
- `log_title()` - Títulos

**Ejemplo**:
```bash
log_info "Procesando..."
log_success "Completado"
log_error "Error encontrado"
```

---

## colors.sh

**Ubicación**: `scripts/sh/common/colors.sh`  
**Propósito**: Colores ANSI para terminal

### Variables Disponibles

- `COLOR_RESET` - Reset de color
- `COLOR_BRIGHT_RED` - Rojo brillante
- `COLOR_BRIGHT_GREEN` - Verde brillante
- `COLOR_BRIGHT_YELLOW` - Amarillo brillante
- `COLOR_BRIGHT_BLUE` - Azul brillante
- Y más...

**Nota**: Se carga automáticamente con `logging.sh` o `init.sh`.

---

## 📖 Más Información

Para más detalles sobre cada helper, consulta los comentarios en los archivos fuente en `scripts/sh/common/`.
