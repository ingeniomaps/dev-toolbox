# Requisitos y Configuración de Red Docker

Esta guía explica cómo funciona la configuración de redes Docker en `dev-toolbox` y los requisitos necesarios.

---

## 📋 Requisitos de Red

### Variables Requeridas en `.env`

Para que `dev-toolbox` pueda crear y gestionar redes Docker, necesitas definir estas variables en tu archivo `.env`:

```bash
# Nombre de la red Docker
NETWORK_NAME=toolbox-network

# Dirección IP base para calcular el subnet
# Formato: X.Y.0.0 (primeros 2 octetos definen el subnet /16)
NETWORK_IP=172.20.0.0
```

### Formato de IP Base

La variable `NETWORK_IP` debe seguir estas reglas:

1. **Formato**: `X.Y.0.0` (4 octetos separados por punto)
2. **Rango válido**:
   - Octetos 1-4: 0-255
   - Primer octeto: No puede ser 127 (localhost), 224-255 (multicast/broadcast)
   - Segundo octeto: No puede ser 254 si el primero es 169 (link-local)
3. **Cálculo de subnet**: Se usa `/16` (primeros 2 octetos)
   - Ejemplo: `172.20.0.0` → subnet `172.20.0.0/16`
   - Esto permite hasta 65,534 hosts en la red

### Ejemplos Válidos

```bash
# Subnet privado clase A
NETWORK_IP=10.0.0.0      # → subnet: 10.0.0.0/16

# Subnet privado clase B
NETWORK_IP=172.20.0.0    # → subnet: 172.20.0.0/16
NETWORK_IP=172.25.0.0    # → subnet: 172.25.0.0/16

# Subnet privado clase C
NETWORK_IP=192.168.0.0   # → subnet: 192.168.0.0/16
```

### Ejemplos Inválidos

```bash
# ❌ Localhost
NETWORK_IP=127.0.0.1

# ❌ Link-local (auto-asignado)
NETWORK_IP=169.254.0.0

# ❌ Multicast/Broadcast
NETWORK_IP=224.0.0.0
NETWORK_IP=255.255.255.0

# ❌ Formato incorrecto
NETWORK_IP=172.20        # Faltan octetos
NETWORK_IP=172.20.0      # Faltan octetos
```

---

## 🔧 Funcionamiento

### Cómo Funciona `ensure-network.sh`

El script `ensure-network.sh` realiza las siguientes operaciones:

1. **Validación previa**:
   - Verifica que Docker esté instalado y corriendo
   - Valida formato de `NETWORK_IP`
   - Verifica que la IP no sea reservada
   - Busca conflictos potenciales con redes existentes

2. **Verificación de red existente**:
   - Si la red existe, valida que el subnet coincida con el esperado
   - Si no coincide, muestra advertencia con opciones

3. **Detección de conflictos**:
   - Busca redes con el mismo subnet exacto
   - Detecta subnets que se solapan (mismos primeros 2 octetos)
   - Lista contenedores conectados si los hay

4. **Creación/Validación**:
   - Si la red no existe, la crea con el subnet calculado
   - Si existe con configuración correcta, retorna éxito
   - Verifica la configuración después de crear

### Comportamiento con Conflictos

Cuando se detecta un conflicto (mismo subnet o solapamiento):

1. **Subnet exacto duplicado**:
   - ❌ Error: No se puede crear otra red con el mismo subnet
   - 💡 Solución: Usa la red existente o cambia `NETWORK_IP`

2. **Subnet solapado**:
   - ⚠️ Advertencia: Mismos primeros 2 octetos
   - 💡 Solución: Cambia a un subnet diferente

3. **Red existe con configuración diferente**:
   - ⚠️ Advertencia: La red existe pero subnet no coincide
   - 💡 Soluciones:
     - Recrear con `--recreate`
     - Actualizar `NETWORK_IP` para coincidir
     - Usar la red existente cambiando `NETWORK_IP`

---

## 🚀 Uso

### Comando Básico

```bash
# Crear o verificar red
make network-tool

# O directamente
./scripts/sh/utils/ensure-network.sh
```

### Opciones

```bash
# Recrear red si existe con configuración diferente
make network-tool RECREATE=true

# O directamente
./scripts/sh/utils/ensure-network.sh --recreate
```

### Verificar Red Actual

```bash
# Listar redes Docker
docker network ls

# Inspeccionar red específica
docker network inspect toolbox-network

# Ver contenedores conectados
docker network inspect toolbox-network | jq '.[0].Containers'
```

---

## ⚠️ Solución de Problemas

### Error: "IP base inválida"

**Causa**: `NETWORK_IP` tiene formato incorrecto o es una IP reservada.

**Solución**:
```bash
# Verifica el formato en .env
cat .env | grep NETWORK_IP

# Usa un formato válido:
NETWORK_IP=172.20.0.0  # ✅ Válido
NETWORK_IP=172.20.0    # ❌ Inválido (falta octeto)
NETWORK_IP=127.0.0.1   # ❌ Inválido (localhost)
```

### Error: "CONFLICTO DE SUBNET DETECTADO"

**Causa**: Ya existe una red con el mismo subnet.

**Solución 1: Usar la red existente**
```bash
# Lista redes existentes
docker network ls

# Actualiza NETWORK_NAME en .env para usar la red existente
NETWORK_NAME=nombre-red-existente
```

**Solución 2: Cambiar subnet**
```bash
# Cambia NETWORK_IP a un subnet diferente
NETWORK_IP=172.21.0.0  # Cambia el segundo octeto

# Verifica que no haya conflictos
make network-tool
```

**Solución 3: Eliminar red existente (si no está en uso)**
```bash
# Verifica contenedores conectados
docker network inspect nombre-red

# Si no hay contenedores, elimina la red
docker network rm nombre-red

# Crea nueva red
make network-tool
```

### Error: "La red tiene contenedores conectados"

**Causa**: Intentas recrear una red que tiene contenedores usando esa red.

**Solución**:
```bash
# 1. Detén los contenedores conectados
docker stop $(docker ps -q --filter network=nombre-red)

# 2. Elimina la red
docker network rm nombre-red

# 3. Recrea la red
make network-tool

# 4. Reinicia los contenedores (se reconectarán automáticamente)
docker-compose up -d
```

### Advertencia: "Configuración de red diferente detectada"

**Causa**: La red existe pero el subnet no coincide con lo esperado.

**Opciones**:

1. **Actualizar .env para coincidir con la red existente**:
   ```bash
   # Obtén el subnet actual
   docker network inspect nombre-red | grep Subnet
   # Resultado: "Subnet": "172.20.0.0/16"

   # Actualiza .env
   NETWORK_IP=172.20.0.0
   ```

2. **Recrear la red**:
   ```bash
   make network-tool RECREATE=true
   ```

---

## 📝 Mejores Prácticas

### 1. Elegir un Subnet Único

Usa subnets que no entren en conflicto con:
- Redes Docker existentes
- Redes de tu host (si usas bridge)
- Otras redes virtuales

**Recomendación**: Usa rangos privados clase B:
- `172.20.0.0` a `172.30.0.0` (menos común que 192.168.x.x)
- Evita `172.17.x.x` (usado por Docker por defecto)

### 2. Documentar Configuración

Agrega comentarios en `.env`:
```bash
# Red Docker para el proyecto
# Subnet: 172.20.0.0/16 (permite hasta 65,534 hosts)
NETWORK_NAME=toolbox-network
NETWORK_IP=172.20.0.0
```

### 3. Verificar Antes de Cambiar

Si necesitas cambiar la configuración de red:
1. Verifica contenedores conectados
2. Detén servicios si es necesario
3. Cambia configuración
4. Recrea red
5. Reinicia servicios

### 4. Usar Múltiples Proyectos

Si tienes múltiples proyectos:
- Usa diferentes subnets para cada proyecto
- Usa nombres de red descriptivos por proyecto
- Ejemplo:
  ```bash
  # Proyecto 1
  NETWORK_NAME=proyecto1-network
  NETWORK_IP=172.20.0.0

  # Proyecto 2
  NETWORK_NAME=proyecto2-network
  NETWORK_IP=172.21.0.0
  ```

---

## 🔗 Referencias

- **Docker Networking**: https://docs.docker.com/network/
- **Docker Bridge Networks**: https://docs.docker.com/network/bridge/
- **RFC 1918** (Private IP Address Ranges):
  - 10.0.0.0/8
  - 172.16.0.0/12
  - 192.168.0.0/16

---

## 📞 Ayuda

Si encuentras problemas:

1. Verifica logs: `make network-tool` mostrará errores detallados
2. Inspecciona red: `docker network inspect nombre-red`
3. Verifica Docker: `docker info`
4. Consulta documentación: `make help-toolbox`
5. Abre un issue en el repositorio

---

**Última actualización**: Enero 2025
