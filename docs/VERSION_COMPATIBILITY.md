# Compatibilidad de Versiones de Servicios

Esta guía explica cómo funciona la validación de versiones de servicios y qué versiones son compatibles o tienen problemas conocidos.

---

## 📋 Base de Datos de Versiones

El sistema usa una base de datos JSON (`config/version-compatibility.json`) que contiene:

- **Versiones mínimas recomendadas**: Versiones recomendadas para producción
- **Versiones mínimas soportadas**: Versiones mínimas que funcionan (con advertencias)
- **Versiones máximas estables**: Últimas versiones estables conocidas
- **Problemas conocidos**: Versiones específicas con problemas documentados
- **Fechas de EOL**: Fechas de fin de soporte para versiones principales
- **Requisitos**: Dependencias o requisitos especiales para ciertas versiones

---

## 🔍 Servicios Soportados

El sistema valida los siguientes servicios:

### Bases de Datos

- **PostgreSQL** (`postgres`, `postgresql`)
  - Mínimo recomendado: 14.0.0
  - Mínimo soportado: 12.0.0
  - Detecta versiones fuera de soporte y próximas a EOL

- **MongoDB** (`mongo`, `mongodb`)
  - Mínimo recomendado: 6.0.0
  - Mínimo soportado: 5.0.0
  - Requisitos especiales para MongoDB 8 (mongosh)

- **MySQL** (`mysql`)
  - Mínimo recomendado: 8.0.0
  - Mínimo soportado: 5.7.0
  - Detecta versiones EOL

- **Redis** (`redis`)
  - Mínimo recomendado: 6.0.0
  - Mínimo soportado: 5.0.0
  - Detecta versiones fuera de soporte

- **Elasticsearch** (`elasticsearch`)
  - Mínimo recomendado: 8.0.0
  - Mínimo soportado: 7.17.0

### Sistemas de Mensajería

- **RabbitMQ** (`rabbitmq`)
  - Mínimo recomendado: 3.12.0
  - Mínimo soportado: 3.11.0

- **Kafka** (`kafka`)
  - Mínimo recomendado: 3.6.0
  - Mínimo soportado: 3.5.0

### Servidores Web

- **Nginx** (`nginx`)
  - Mínimo recomendado: 1.20.0
  - Mínimo soportado: 1.18.0

### Lenguajes de Programación

- **Node.js** (`node`)
  - Mínimo recomendado: 20.0.0 (LTS)
  - Mínimo soportado: 18.0.0 (LTS)
  - Detecta versiones fuera de soporte LTS

- **Python** (`python`)
  - Mínimo recomendado: 3.11.0
  - Mínimo soportado: 3.9.0
  - Detecta versiones EOL

---

## 🚀 Uso

### Comando Básico

```bash
# Verificar versión de un servicio
make check-version-compatibility SERVICE=postgres NEW_VERSION=16.1

# O directamente
./scripts/sh/commands/check-version-compatibility.sh postgres 16.1
```

### Salida en JSON

```bash
./scripts/sh/commands/check-version-compatibility.sh postgres 16.1 --json
```

### Validación Estricta

```bash
# Falla en warnings también
VERSION_CHECK_STRICT=true make check-version-compatibility SERVICE=postgres NEW_VERSION=12.0
```

---

## 📊 Tipos de Validaciones

### 1. Versión Muy Antigua

Si la versión es menor que `min_supported`:

```
[ERROR] Versión 12.0 es muy antigua. Versión mínima soportada: 14.0.0
```

### 2. Versión Muy Nueva (Beta/RC)

Si la versión es significativamente mayor que `max_stable`:

```
[WARN] Versión 18.0 parece ser una versión beta o release candidate no estable
```

### 3. Problemas Conocidos

Versiones específicas con problemas documentados:

```json
"known_issues": {
  "13.0.0": {
    "severity": "warning",
    "message": "PostgreSQL 13 está en mantenimiento, considera actualizar a >= 14"
  }
}
```

### 4. Fin de Soporte (EOL)

Detección de versiones fuera de soporte o próximas a EOL:

```
[ERROR] Versión 12.0 está fuera de soporte (EOL: 2024-11-14, hace 75 días)
[WARN] Versión 15.0 se acerca al fin de soporte (EOL: 2027-11-11, en 45 días)
```

### 5. Versión No Recomendada

Versiones anteriores a la recomendada:

```
[WARN] Versión 13.0 es anterior a la recomendada (14.0.0)
```

### 6. Requisitos Especiales

Requisitos específicos para ciertas versiones:

```
[INFO] PostgreSQL 17 requiere Docker >= 20.10
[INFO] MongoDB 8 requiere mongosh (no mongo shell)
```

---

## ⚙️ Configuración

### Personalizar Base de Datos

Crea tu propio archivo de configuración:

```bash
# Copiar base de datos
cp config/version-compatibility.json config/version-compatibility.local.json

# Especificar ruta personalizada
VERSION_DB_PATH=config/version-compatibility.local.json \
  make check-version-compatibility SERVICE=postgres NEW_VERSION=16.1
```

### Agregar Nuevos Servicios

Edita `config/version-compatibility.json`:

```json
{
  "services": {
    "mi-servicio": {
      "min_recommended": "2.0.0",
      "min_supported": "1.5.0",
      "max_stable": "2.5.0",
      "known_issues": {
        "1.0.0": {
          "severity": "error",
          "message": "Versión 1.0 tiene bug crítico de seguridad"
        }
      },
      "eol_dates": {
        "1": "2024-12-31"
      }
    }
  }
}
```

---

## 📝 Ejemplos

### Ejemplo 1: Versión Compatible

```bash
$ make check-version-compatibility SERVICE=postgres NEW_VERSION=16.1

[INFO] Verificando compatibilidad de postgres versión 16.1...
[SUCCESS] Versión 16.1 de postgres es compatible
```

### Ejemplo 2: Versión con Advertencia

```bash
$ make check-version-compatibility SERVICE=postgres NEW_VERSION=13.0

[INFO] Verificando compatibilidad de postgres versión 13.0...
[WARN] PostgreSQL 13 está en mantenimiento, considera actualizar a >= 14
[WARN] Versión 13.0 se acerca al fin de soporte (EOL: 2025-11-13, en 45 días)
[SUCCESS] Versión 13.0 de postgres es compatible (con advertencias)
```

### Ejemplo 3: Versión con Error

```bash
$ make check-version-compatibility SERVICE=postgres NEW_VERSION=12.0

[INFO] Verificando compatibilidad de postgres versión 12.0...
[ERROR] PostgreSQL 12 está fuera de soporte, se recomienda actualizar a >= 14
[ERROR] Versión 12.0 está fuera de soporte (EOL: 2024-11-14, hace 75 días)
[ERROR] Versión 12.0 de postgres tiene problemas de compatibilidad
```

### Ejemplo 4: Servicio No en Base de Datos

```bash
$ make check-version-compatibility SERVICE=mi-servicio NEW_VERSION=1.0.0

[INFO] Verificando compatibilidad de mi-servicio versión 1.0.0...
[INFO] Servicio mi-servicio no tiene validación específica en la base de datos
[INFO] Se asume que la versión 1.0.0 es compatible
[SUCCESS] Versión 1.0.0 de mi-servicio es compatible
```

---

## 🔧 Validación Integrada

La validación de versiones se ejecuta automáticamente en:

- `make validate` - Valida todas las versiones en `.env`
- `make doctor` - Diagnóstico completo del sistema
- `make check-versions` - Verifica versiones específicas

### Validación en Paralelo

```bash
# Validar todas las versiones en paralelo
make validate --parallel
```

---

## 📚 Estructura de la Base de Datos

```json
{
  "services": {
    "servicio": {
      "min_recommended": "X.Y.Z",      // Versión mínima recomendada
      "min_supported": "X.Y.Z",        // Versión mínima soportada
      "max_stable": "X.Y.Z",           // Última versión estable
      "known_issues": {                // Problemas conocidos
        "version": {
          "severity": "error|warning",
          "message": "Descripción del problema"
        }
      },
      "requirements": {                // Requisitos especiales
        "version": {
          "docker": ">= 20.10",
          "message": "Descripción del requisito"
        }
      },
      "eol_dates": {                   // Fechas de fin de soporte
        "major": "YYYY-MM-DD"
      }
    }
  }
}
```

---

## ⚠️ Solución de Problemas

### Error: "jq no está disponible"

**Solución**: Instalar jq
```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq
```

### Error: "Base de datos de versiones no encontrada"

**Causa**: El archivo `config/version-compatibility.json` no existe.

**Solución**:
```bash
# Verificar que el archivo existe
ls -l config/version-compatibility.json

# O especificar ruta personalizada
VERSION_DB_PATH=/ruta/al/archivo.json make check-version-compatibility ...
```

### Versión no se detecta correctamente

**Causa**: Formato de versión no estándar.

**Solución**: El script maneja formatos comunes:
- `16.1` ✅
- `16.1-alpine` ✅
- `8.0.0` ✅
- `v8.0.0` ⚠️ (se recomienda sin prefijo)

---

## 🔗 Referencias

- **Base de datos**: `config/version-compatibility.json`
- **Script**: `scripts/sh/commands/check-version-compatibility.sh`
- **Makefile**: `make check-version-compatibility`

---

## 📖 Agregar Nuevos Servicios

Para agregar validación de un nuevo servicio:

1. Edita `config/version-compatibility.json`
2. Agrega la entrada del servicio en `services`
3. Define versiones mínimas, problemas conocidos, etc.
4. Prueba con: `make check-version-compatibility SERVICE=nombre NEW_VERSION=x.y.z`

---

**Última actualización**: Enero 2025
