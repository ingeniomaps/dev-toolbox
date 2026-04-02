# Tests - dev-toolbox

> Framework de testing usando BATS (Bash Automated Testing System)

---

## 📋 Estructura

```
tests/
├── unit/              # Tests unitarios
│   ├── helpers.bash   # Helpers comunes para tests unitarios
│   └── *.bats         # Tests unitarios
├── integration/       # Tests de integración
│   ├── helpers.bash   # Helpers comunes para tests de integración
│   └── *.bats         # Tests de integración
└── README.md          # Este archivo
```

---

## 🚀 Inicio Rápido

### Instalar BATS

```bash
# Opción 1: Usar script de instalación
make install-bats

# Opción 2: Instalación manual
bash scripts/sh/setup/install-bats.sh
```

### Ejecutar Tests

```bash
# Todos los tests
make test

# Solo tests unitarios
make test-unit

# Solo tests de integración
make test-integration

# Test específico
bats tests/unit/test-validation.bats
```

---

## 📝 Escribir Tests

### Test Unitario

```bash
#!/usr/bin/env bats
load 'tests/unit/helpers.bash'

@test "mi función funciona correctamente" {
    source "$TEST_COMMON_DIR/mi-helper.sh"
    
    result=$(mi_funcion "input")
    assert_equals "expected" "$result"
}
```

### Test de Integración

```bash
#!/usr/bin/env bats
load 'tests/integration/helpers.bash'

@test "servicio se inicia correctamente" {
    container=$(start_test_service "test-service" "alpine:latest" "sleep 3600")
    
    wait_for_service "$container" 30
    assert_success "$output" "$status"
    
    stop_test_service "$container"
}
```

### Test End-to-End (E2E)

```bash
#!/usr/bin/env bats
load 'tests/integration/helpers.bash'

@test "make setup ejecuta configuración completa" {
    skip_if_no_docker
    
    cd "$TEST_PROJECT_ROOT_FOR_TEST"
    
    # Ejecutar comando make real
    run make setup PROJECT_ROOT="$TEST_PROJECT_ROOT_FOR_TEST" 2>&1 || true
    
    # Verificar que se ejecutó
    assert_contains "$output" "CONFIGURACIÓN\|Paso" \
        "Debería mostrar pasos de configuración"
}
```

---

## 🛠️ Helpers Disponibles

### Helpers Unitarios (`tests/unit/helpers.bash`)

- `create_temp_file(content)` - Crea archivo temporal
- `create_temp_dir()` - Crea directorio temporal
- `create_test_env_file(content)` - Crea archivo .env de prueba
- `assert_file_exists(file, message)` - Verifica archivo existe
- `assert_file_not_exists(file, message)` - Verifica archivo no existe
- `assert_dir_exists(dir, message)` - Verifica directorio existe
- `assert_contains(haystack, needle, message)` - Verifica substring
- `assert_not_contains(haystack, needle, message)` - Verifica no contiene
- `assert_equals(expected, actual, message)` - Verifica igualdad
- `assert_not_equals(expected, actual, message)` - Verifica desigualdad
- `assert_success(output, exit_code, message)` - Verifica éxito
- `assert_failure(output, exit_code, message)` - Verifica fallo

### Helpers de Integración (`tests/integration/helpers.bash`)

- `start_test_service(name, image, command)` - Inicia servicio Docker
- `stop_test_service(container_name)` - Detiene servicio Docker
- `wait_for_service(container_name, max_wait)` - Espera servicio listo
- `cleanup_test_containers()` - Limpia contenedores de test
- `cleanup_test_networks()` - Limpia redes de test

---

## 🔧 Variables de Entorno de Test

Los helpers configuran automáticamente:

- `TEST_PROJECT_ROOT` - Raíz del proyecto
- `TEST_COMMON_DIR` - Directorio de helpers comunes
- `TEST_SCRIPTS_DIR` - Directorio de scripts
- `TEST_TMP_DIR` - Directorio temporal para tests
- `TEST_ENV_FILE` - Archivo .env de prueba
- `TEST_NETWORK_NAME` - Nombre de red de test (solo integración)
- `TEST_NETWORK_IP` - IP de red de test (solo integración)

---

## 📚 Ejemplos

Ver tests de ejemplo en:

### Tests Unitarios

#### Scripts de Comandos
- `tests/unit/test-validation.bats` - Tests para validation.sh (10 tests)
- `tests/unit/test-check-ports.bats` - Tests para check-ports.sh (5 tests)
- `tests/unit/test-check-version-compatibility.bats` - Tests para check-version-compatibility.sh (8 tests)
- `tests/unit/test-validate-ips.bats` - Tests para validate-ips.sh (8 tests)
- `tests/unit/test-improved-secrets-check.bats` - Tests para improved-secrets-check.sh (7 tests)
- `tests/unit/test-metrics.bats` - Tests para metrics.sh (5 tests)
- `tests/unit/test-alerts.bats` - Tests para alerts.sh (5 tests)
- `tests/unit/test-backup-all.bats` - Tests para backup-all.sh (6 tests)
- `tests/unit/test-restore-all.bats` - Tests para restore-all.sh (8 tests)

#### Scripts de Setup
- `tests/unit/test-init-env.bats` - Tests para init-env.sh (9 tests)
- `tests/unit/test-setup.bats` - Tests para setup.sh (4 tests)
- `tests/unit/test-load-toolbox.bats` - Tests para load-toolbox.sh (8 tests)
- `tests/unit/test-create-service.bats` - Tests para create-service.sh (10 tests)

#### Scripts de Utils
- `tests/unit/test-generate-password.bats` - Tests para generate-password.sh (7 tests)
- `tests/unit/test-validate-password-complexity.bats` - Tests para validate-password-complexity.sh (9 tests)
- `tests/unit/test-replace-env-var.bats` - Tests para replace-env-var.sh (8 tests)
- `tests/unit/test-replace-domains.bats` - Tests para replace-domains.sh (7 tests)
- `tests/unit/test-wait-for-service.bats` - Tests para wait-for-service.sh (8 tests)

### Tests de Integración

#### Tests de Funcionalidad
- `tests/integration/test-network.bats` - Tests para ensure-network.sh (4 tests)

#### Tests End-to-End (E2E)
- `tests/integration/test-setup-e2e.bats` - Tests E2E para `make setup` (6 tests)
- `tests/integration/test-validate-e2e.bats` - Tests E2E para `make validate` (6 tests)
- `tests/integration/test-backup-restore-e2e.bats` - Tests E2E para `make backup-all` y `restore-all` (6 tests)
- `tests/integration/test-metrics-alerts-e2e.bats` - Tests E2E para `make metrics` y `alerts` (7 tests)
- `tests/integration/test-doctor-e2e.bats` - Tests E2E para `make doctor` (7 tests)

#### Tests de Compatibilidad
- `tests/integration/test-compatibility-docker-compose.bats` - Tests de compatibilidad Docker Compose V1/V2 (8 tests)
- `tests/integration/test-compatibility-os.bats` - Tests de compatibilidad sistemas operativos (8 tests)
- `tests/integration/test-compatibility-bash.bats` - Tests de compatibilidad versiones de Bash (11 tests)

**Total: 124 tests unitarios + 59 tests de integración = 183 tests**

---

## 🔄 Tests de Compatibilidad

Los tests de compatibilidad verifican que el proyecto funciona correctamente en diferentes entornos:

### Docker Compose
- **V1 (`docker-compose`)**: Tests verifican que el proyecto detecta y usa Docker Compose V1 cuando V2 no está disponible
- **V2 (`docker compose`)**: Tests verifican que el proyecto detecta y usa Docker Compose V2 (preferido)

### Sistemas Operativos
- **Linux**: Tests verifican funcionamiento en sistemas Linux
- **macOS**: Tests verifican funcionamiento en sistemas macOS (Darwin)

### Versiones de Bash
- **Bash 4.x**: Tests verifican compatibilidad con Bash 4.0+
- **Bash 5.x**: Tests verifican compatibilidad con Bash 5.0+
- **Características modernas**: Tests verifican que características de Bash 4+ funcionan correctamente

### CI/CD
Los tests de compatibilidad se ejecutan automáticamente en GitHub Actions en múltiples entornos:
- Ubuntu (Linux)
- macOS
- Diferentes versiones de Bash

---

## 🎯 Mejores Prácticas

1. **Usar helpers**: Siempre usa los helpers en lugar de escribir lógica repetitiva
2. **Limpiar recursos**: Los helpers limpian automáticamente, pero verifica en teardown
3. **Tests aislados**: Cada test debe ser independiente
4. **Nombres descriptivos**: Usa nombres claros para los tests
5. **Mensajes claros**: Proporciona mensajes descriptivos en aserciones

---

## 🔗 Referencias

- [BATS Documentation](https://bats-core.readthedocs.io/)
- [BATS GitHub](https://github.com/bats-core/bats-core)

---

*Última actualización: 2025-01-27*
