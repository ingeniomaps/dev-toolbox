# Cobertura de Tests

Esta guía explica cómo funciona el sistema de cobertura de tests y cómo usarlo.

---

## 📊 Sistema de Cobertura

El sistema analiza automáticamente qué scripts tienen tests correspondientes y calcula el porcentaje de cobertura.

### Características

- **Análisis automático**: Detecta scripts y sus tests correspondientes
- **Múltiples formatos**: Texto, JSON, HTML
- **Umbral configurable**: Falla si cobertura < mínimo (default: 80%)
- **Reportes detallados**: Lista scripts con y sin tests
- **Conteo de tests**: Muestra número de tests por archivo

---

## 🚀 Uso

### Comando Básico

```bash
# Calcular cobertura (texto)
make test-coverage

# O directamente
./scripts/sh/utils/calculate-coverage.sh
```

### Generar Reporte HTML

```bash
# Generar reporte HTML
make coverage-report

# El reporte se guarda en coverage/coverage.html
```

### Formato JSON

```bash
# Salida en JSON
./scripts/sh/utils/calculate-coverage.sh --format=json

# Guardar en archivo
./scripts/sh/utils/calculate-coverage.sh --format=json --output=coverage.json
```

### Umbral Personalizado

```bash
# Falla si cobertura < 90%
COVERAGE_MIN=90 make test-coverage

# O con parámetro
./scripts/sh/utils/calculate-coverage.sh --min=90
```

---

## 📈 Interpretación de Resultados

### Salida en Texto

```
==========================================
  Reporte de Cobertura de Tests
==========================================

📊 Estadísticas Generales:
  Total de scripts:     81
  Scripts con tests:    30
  Scripts sin tests:    51
  Cobertura:           37%
  Mínimo requerido:    80%

❌ Cobertura insuficiente (< 80%)

📝 Scripts sin tests (51):
  - scripts/sh/commands/script1.sh
  - scripts/sh/commands/script2.sh
  ...

✅ Scripts con tests (30):
  - scripts/sh/commands/script3.sh (8 tests)
  - scripts/sh/commands/script4.sh (5 tests)
  ...
```

### Salida en JSON

```json
{
  "coverage": {
    "total_scripts": 81,
    "tested_scripts": 30,
    "untested_scripts": 51,
    "coverage_percent": 37,
    "min_required": 80,
    "meets_requirement": false
  },
  "tested_scripts": [
    {
      "script": "scripts/sh/commands/script.sh",
      "test_file": "tests/unit/test-script.bats",
      "test_count": 8
    }
  ],
  "untested_scripts": [
    "scripts/sh/commands/script1.sh"
  ]
}
```

### Reporte HTML

El reporte HTML incluye:
- Estadísticas visuales con gráficos
- Tabla de scripts sin tests
- Tabla de scripts con tests y número de casos
- Barra de progreso de cobertura
- Indicador de estado (✅/❌)

---

## 🔍 Cómo Funciona

### Detección de Scripts

El sistema busca scripts en:
- `scripts/sh/commands/` - Comandos principales
- `scripts/sh/utils/` - Utilidades
- `scripts/sh/setup/` - Scripts de configuración
- `scripts/sh/backup/` - Scripts de backup
- `scripts/sh/common/` - Scripts comunes (principales)

### Detección de Tests

Para cada script, busca tests en:
1. `tests/unit/test-<nombre>.bats` (exacto)
2. Variaciones de nombre (con guiones/guiones bajos)
3. `tests/integration/test-<nombre>.bats`

### Cálculo de Cobertura

```
Cobertura = (Scripts con tests / Total de scripts) × 100
```

---

## 📝 Agregar Tests para Nuevos Scripts

### Convención de Nombres

Para que el sistema detecte tu test:

1. **Script**: `scripts/sh/commands/mi-comando.sh`
2. **Test**: `tests/unit/test-mi-comando.bats`

### Ejemplo

```bash
#!/usr/bin/env bats
load 'tests/unit/helpers.bash'

@test "mi-comando funciona correctamente" {
    run bash "$TEST_COMMANDS_DIR/mi-comando.sh" --help
    assert_success
    assert_output --partial "Uso:"
}
```

---

## ⚙️ Integración en CI/CD

### GitHub Actions

```yaml
- name: Check test coverage
  run: |
    make test-coverage COVERAGE_MIN=80
    # Falla si cobertura < 80%
```

### Generar Artefacto

```yaml
- name: Generate coverage report
  run: make coverage-report

- name: Upload coverage report
  uses: actions/upload-artifact@v3
  with:
    name: coverage-report
    path: coverage/coverage.html
```

---

## 🎯 Objetivos de Cobertura

### Cobertura Actual

- **Total de scripts**: 81+
- **Scripts con tests**: 30+
- **Cobertura**: ~37%
- **Objetivo**: > 80%

### Prioridades

1. **Alta**: Comandos principales (`validate.sh`, `backup-all.sh`, etc.)
2. **Media**: Utilidades (`generate-password.sh`, `replace-env-var.sh`, etc.)
3. **Baja**: Scripts de setup y helpers internos

---

## 🔧 Solución de Problemas

### Error: "Script calculate-coverage.sh no encontrado"

**Causa**: El script no está en la ubicación esperada.

**Solución**:
```bash
# Verificar que existe
ls -l scripts/sh/utils/calculate-coverage.sh

# O especificar ruta completa
PROJECT_ROOT=$(pwd) bash scripts/sh/utils/calculate-coverage.sh
```

### Cobertura no detecta mi test

**Causa**: El nombre del test no coincide con el script.

**Solución**:
- Verificar que el test se llama `test-<nombre-script>.bats`
- Usar guiones en lugar de guiones bajos
- Verificar que está en `tests/unit/` o `tests/integration/`

### Reporte HTML no se genera

**Causa**: El directorio `coverage/` no existe o no tiene permisos.

**Solución**:
```bash
mkdir -p coverage
chmod 755 coverage
make coverage-report
```

---

## 📚 Referencias

- **Script**: `scripts/sh/utils/calculate-coverage.sh`
- **Makefile**: `make test-coverage`, `make coverage-report`
- **Tests**: `tests/unit/`, `tests/integration/`
- **Documentación de Tests**: `tests/README.md`

---

## 📖 Mejores Prácticas

1. **Agregar tests al crear nuevos scripts**
2. **Mantener cobertura > 80%**
3. **Revisar reporte HTML regularmente**
4. **Integrar en CI/CD para validación automática**
5. **Priorizar tests para comandos críticos**

---

**Última actualización**: Enero 2025
