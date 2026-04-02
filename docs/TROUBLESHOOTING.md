# Troubleshooting - Solución de Problemas Comunes

> Guía de solución a errores y problemas comunes en dev-toolbox

---

## 📋 Tabla de Contenidos

- [Errores de Archivo .env](#errores-de-archivo-env)
- [Errores de Variables de Entorno](#errores-de-variables-de-entorno)
- [Errores de Docker](#errores-de-docker)
- [Errores de Servicios](#errores-de-servicios)
- [Errores de Validación](#errores-de-validación)
- [Errores de Permisos](#errores-de-permisos)
- [Errores de Red](#errores-de-red)
- [Errores de Scripts](#errores-de-scripts)

---

## 🔧 Errores de Archivo .env

### Error: "Archivo .env no encontrado"

**Mensaje**:
```
[ERROR] Archivo .env no encontrado: /ruta/al/proyecto/.env
💡 Sugerencia: Ejecuta 'make init-env' para crear el archivo .env
```

**Causa**: El archivo `.env` no existe en la raíz del proyecto.

**Solución**:
```bash
# Crear .env desde plantilla
make init-env

# Verificar que se creó
ls -la .env

# Ver contenido
cat .env
```

**Prevención**: Siempre ejecuta `make init-env` después de clonar el proyecto.

---

### Error: ".env existe pero está vacío"

**Mensaje**:
```
[WARN] Archivo .env está vacío
```

**Causa**: El archivo `.env` existe pero no tiene contenido.

**Solución**:
```bash
# Recrear desde plantilla (forzar)
make init-env FORCE=true

# O editar manualmente
make env-edit
```

---

## 🔑 Errores de Variables de Entorno

### Error: "Variables faltantes en .env"

**Mensaje**:
```
[ERROR] Variables faltantes en .env: NETWORK_NAME NETWORK_IP
💡 Sugerencia: Agrega las variables faltantes a .env
   Ejemplo: echo 'VARIABLE=valor' >> .env
   O ejecuta 'make init-env' para crear desde plantilla
```

**Causa**: Faltan variables requeridas en el archivo `.env`.

**Solución**:
```bash
# Ver qué variables faltan
make validate

# Agregar variables faltantes manualmente
echo "NETWORK_NAME=mi-proyecto" >> .env
echo "NETWORK_IP=172.20.0.0" >> .env

# O recrear desde plantilla
make init-env FORCE=true
```

**Variables Requeridas Mínimas**:
- `NETWORK_NAME` - Nombre de la red Docker
- `NETWORK_IP` - Rango IP de la red (formato: X.X.X.0)

---

### Error: "Variable X no está definida"

**Mensaje**:
```
[ERROR] Variable POSTGRES_VERSION no está definida
💡 Sugerencia: Define POSTGRES_VERSION en .env o como variable de entorno
```

**Causa**: Una variable de entorno requerida no está definida.

**Solución**:
```bash
# Opción 1: Agregar a .env
echo "POSTGRES_VERSION=18" >> .env

# Opción 2: Exportar como variable de entorno
export POSTGRES_VERSION=18
make start SERVICE=postgres

# Opción 3: Usar make con variable
make start SERVICE=postgres POSTGRES_VERSION=18
```

---

## 🐳 Errores de Docker

### Error: "Docker no está instalado o no está en PATH"

**Mensaje**:
```
[ERROR] Docker no está instalado o no está en PATH
💡 Sugerencia: Instala Docker desde https://docs.docker.com/get-docker/
```

**Causa**: Docker no está instalado o no está en el PATH del sistema.

**Solución**:
```bash
# Verificar si Docker está instalado
docker --version

# Si no está instalado, instalar según tu OS:
# Linux: https://docs.docker.com/engine/install/
# macOS: https://docs.docker.com/desktop/install/mac-install/
# Windows: https://docs.docker.com/desktop/install/windows-install/

# Verificar que Docker está corriendo
docker ps
```

---

### Error: "Docker Compose no está instalado"

**Mensaje**:
```
[ERROR] Docker Compose no está instalado o no está en PATH
💡 Sugerencia: Instala Docker Compose desde https://docs.docker.com/compose/install/
```

**Causa**: Docker Compose no está instalado o no está en el PATH.

**Solución**:
```bash
# Verificar versión
docker compose version
# o
docker-compose --version

# Si no está instalado:
# Docker Compose V2 viene con Docker Desktop
# Para Linux: https://docs.docker.com/compose/install/linux/
```

---

### Error: "Cannot connect to the Docker daemon"

**Mensaje**:
```
Cannot connect to the Docker daemon. Is the docker daemon running?
```

**Causa**: El servicio Docker no está corriendo.

**Solución**:
```bash
# Linux: Iniciar servicio Docker
sudo systemctl start docker
sudo systemctl enable docker

# macOS/Windows: Iniciar Docker Desktop desde aplicaciones

# Verificar que está corriendo
docker ps
```

---

## 🚀 Errores de Servicios

### Error: "No hay servicios disponibles para iniciar"

**Mensaje**:
```
[WARN] No hay servicios disponibles para iniciar
💡 Sugerencia: Agrega variables *_VERSION en .env
   Ejemplo: POSTGRES_VERSION=18
```

**Causa**: No se encontraron servicios configurados en `.env`.

**Solución**:
```bash
# Agregar servicios a .env
echo "POSTGRES_VERSION=18" >> .env
echo "MONGO_VERSION=7.0" >> .env

# O especificar servicios manualmente
make start SERVICES="postgres mongo"

# Verificar servicios configurados
make list-services
```

---

### Error: "Servicio X no está configurado"

**Mensaje**:
```
[WARN] Comando up-postgres no disponible (puede que el servicio no esté configurado)
```

**Causa**: El servicio no tiene un target en el Makefile o no está en `docker-compose.yml`.

**Solución**:
```bash
# Verificar que el servicio está en docker-compose.yml
grep -A 5 "postgres:" docker-compose.yml

# Verificar que tiene variable *_VERSION en .env
grep "POSTGRES_VERSION" .env

# Verificar comandos disponibles
make help-toolbox | grep postgres
```

---

### Error: "Contenedor ya está corriendo"

**Mensaje**:
```
Error response from daemon: container is already running
```

**Causa**: El contenedor ya está iniciado.

**Solución**:
```bash
# Ver estado de contenedores
make ps

# Reiniciar servicio
make restart SERVICE=postgres

# O detener y volver a iniciar
make stop SERVICE=postgres
make start SERVICE=postgres
```

---

## ✅ Errores de Validación

### Error: "Puerto X ya está en uso"

**Mensaje**:
```
[ERROR] Puerto 5432 ya está en uso
```

**Causa**: Otro proceso está usando el puerto requerido.

**Solución**:
```bash
# Ver qué proceso usa el puerto
sudo lsof -i :5432
# o
sudo netstat -tulpn | grep 5432

# Opción 1: Detener el proceso
sudo kill -9 <PID>

# Opción 2: Cambiar puerto en .env
echo "POSTGRES_PORT=5433" >> .env

# Validar puertos
make check-ports
```

---

### Error: "IP inválida"

**Mensaje**:
```
[ERROR] IP debe ser una IPv4 válida: 192.168.1.999
```

**Causa**: El formato de IP no es válido.

**Solución**:
```bash
# Verificar formato de IP en .env
grep "NETWORK_IP\|.*_IP\|.*_HOST" .env

# Corregir formato (cada octeto debe ser 0-255)
# ❌ MAL: NETWORK_IP=192.168.1.999
# ✅ BIEN: NETWORK_IP=192.168.1.0

# Validar IPs
make validate-ips
```

---

### Error: "Contraseña no cumple requisitos"

**Mensaje**:
```
[ERROR] Contraseña no cumple requisitos de complejidad
```

**Causa**: La contraseña no cumple con los requisitos mínimos.

**Solución**:
```bash
# Ver requisitos de contraseña
make validate-passwords

# Generar contraseña segura
bash scripts/sh/utils/generate-password.sh

# Actualizar en .env
bash scripts/sh/utils/replace-env-var.sh .env POSTGRES_PASSWORD "nueva-contraseña-segura"
```

---

## 🔐 Errores de Permisos

### Error: "Permission denied" en scripts

**Mensaje**:
```
bash: scripts/sh/commands/start.sh: Permission denied
```

**Causa**: Los scripts no tienen permisos de ejecución.

**Solución**:
```bash
# Dar permisos de ejecución
chmod +x scripts/sh/commands/*.sh
chmod +x scripts/sh/utils/*.sh
chmod +x scripts/sh/setup/*.sh

# O usar find
find scripts/sh -name "*.sh" -exec chmod +x {} \;
```

---

### Error: "Permission denied" en Docker

**Mensaje**:
```
Got permission denied while trying to connect to the Docker daemon socket
```

**Causa**: El usuario no tiene permisos para acceder a Docker.

**Solución**:
```bash
# Opción 1: Agregar usuario al grupo docker (Linux)
sudo usermod -aG docker $USER
# Cerrar sesión y volver a iniciar

# Opción 2: Usar sudo (no recomendado)
sudo docker ps

# Opción 3: Verificar permisos del socket
ls -la /var/run/docker.sock
```

---

## 🌐 Errores de Red

### Error: "Network not found"

**Mensaje**:
```
Error response from daemon: network dev-toolbox not found
```

**Causa**: La red Docker no existe.

**Solución**:
```bash
# Crear red manualmente
docker network create --subnet=172.20.0.0/16 dev-toolbox

# O usar el comando de dev-toolbox
make network-tool

# Verificar redes
docker network ls
```

---

### Error: "Network already exists with different configuration"

**Mensaje**:
```
⚠️  CONFIGURACIÓN DE RED DIFERENTE DETECTADA
La red 'dev-toolbox' existe pero con configuración diferente:
  • Subnet actual:   172.20.0.0/16
  • Subnet esperado: 101.80.0.0/16
```

**Causa**: La red existe pero con configuración diferente (subnet).

**Solución**:
```bash
# Opción 1: Recrear automáticamente (recomendado)
make network-tool RECREATE=true

# Opción 2: Recrear con confirmación interactiva
./scripts/sh/utils/ensure-network.sh --recreate

# Opción 3: Actualizar .env para usar la configuración actual
# Ver subnet actual:
docker network inspect dev-toolbox | grep Subnet
# Actualizar NETWORK_IP en .env para que coincida

# Opción 4: Eliminar manualmente y recrear
docker network rm dev-toolbox
make network-tool
```

**Nota**: Si la red tiene contenedores conectados, el script pedirá confirmación antes de eliminarla.

---

## 📜 Errores de Scripts

### Error: "Script X no encontrado"

**Mensaje**:
```
[ERROR] Script start.sh no encontrado en /ruta/scripts/sh/commands/
```

**Causa**: El script no existe o la ruta es incorrecta.

**Solución**:
```bash
# Verificar que el script existe
ls -la scripts/sh/commands/start.sh

# Verificar estructura del proyecto
ls -la scripts/sh/

# Verificar PROJECT_ROOT
echo $PROJECT_ROOT

# Reinstalar dev-toolbox si es necesario
make load-toolbox
```

---

### Error: "Sintaxis inválida en script"

**Mensaje**:
```
scripts/sh/commands/start.sh: line 50: syntax error near unexpected token
```

**Causa**: Error de sintaxis en el script.

**Solución**:
```bash
# Verificar sintaxis
bash -n scripts/sh/commands/start.sh

# Ver línea específica
sed -n '50p' scripts/sh/commands/start.sh

# Verificar con shellcheck (si está instalado)
shellcheck scripts/sh/commands/start.sh
```

---

### Error: "Variable no definida" (set -u)

**Mensaje**:
```
scripts/sh/commands/start.sh: line 50: VARIABLE: unbound variable
```

**Causa**: Se usa una variable no definida con `set -u`.

**Solución**:
```bash
# Opción 1: Definir la variable
export VARIABLE=valor

# Opción 2: Usar valor por defecto en el script
# Cambiar: $VARIABLE
# Por: ${VARIABLE:-valor_por_defecto}

# Opción 3: Verificar que la variable está en .env
grep VARIABLE .env
```

---

## 🔍 Diagnóstico General

### Comando de Diagnóstico Completo

```bash
# Ejecutar diagnóstico completo
make validate
make check-dependencies
make check-ports
make validate-ips
make validate-passwords

# Ver información del sistema
make info

# Ver estado de servicios
make ps
make list-services
```

### Verificar Logs

```bash
# Logs de un servicio específico
make logs SERVICE=postgres

# Logs agregados de todos los servicios
make aggregate-logs

# Ver logs de Docker
docker logs <container-name>
```

### Verificar Configuración

```bash
# Ver variables de entorno (sanitizadas)
make env-show

# Ver configuración completa
make config-show

# Ver versión
make show-version
```

---

## 📚 Recursos Adicionales

- [Guía de Integración](INTEGRATION_GUIDE.md) - Troubleshooting de integración
- [Guía de Desarrollo](GUIA_DESARROLLO.md) - Crear y depurar scripts
- [Documentación de Helpers](HELPERS.md) - Funciones de validación disponibles

---

## 💡 Consejos Generales

1. **Siempre valida antes de ejecutar**:
   ```bash
   make validate
   ```

2. **Revisa los logs**:
   ```bash
   make aggregate-logs
   ```

3. **Verifica dependencias**:
   ```bash
   make check-dependencies
   ```

4. **Usa modo verbose para debugging**:
   ```bash
   VERBOSE=1 make start SERVICE=postgres
   ```

5. **Revisa la documentación**:
   ```bash
   make help-toolbox
   ```

---

*Última actualización: 2025-01-27*
