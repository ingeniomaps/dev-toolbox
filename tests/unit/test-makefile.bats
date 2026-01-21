#!/usr/bin/env bats
# ============================================================================
# Test: test-makefile.bats
# Ubicación: tests/unit/
# ============================================================================
# Tests para verificar que todos los comandos make están definidos y funcionan.
#
# Uso:
#   bats tests/unit/test-makefile.bats
#
# Retorno:
#   0 si todos los tests pasaron
#   1 si algún test falló
# ============================================================================

load 'tests/unit/helpers.bash'

setup() {
	# Directorio del proyecto
	export TEST_PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
	export TEST_MAKEFILE="$TEST_PROJECT_ROOT/Makefile"

	# Cambiar al directorio del proyecto para ejecutar make
	cd "$TEST_PROJECT_ROOT" || exit 1

	# Lista de todos los comandos make documentados
	# Extraídos de los makefiles principales
	MAKE_COMMANDS=(
		# Comandos principales [main]
		"help-toolbox"
		"init-env"
		"setup-env"
		"export-config"
		"setup"
		"install-dependencies"
		"verify-installation"
		"rotate-logs"
		"start-required"
		"create-service"
		"info"
		"list-services"
		"list-volumes"
		"list-networks"
		"config-show"
		"install-pre-commit"
		"list-images"
		"env-show"
		"env-edit"
		"start"
		"stop"
		"up"
		"down"
		"shell"
		"exec"
		"ps"
		"logs"
		"restart"
		"clean"
		"clean-volumes"
		"clean-images"
		"clean-networks"
		"prune"
		"build"
		"rebuild"
		"save-state"
		"list-states"
		"rollback"

		# Validación [validation]
		"validate"
		"validate-ips"
		"check-ports"
		"check-versions-main"
		"check-dependencies"
		"validate-syntax"
		"status"
		"doctor"

		# Seguridad [security]
		"secrets-check"
		"validate-passwords"
		"security-audit"
		"rotate-secrets"

		# Infisical y herramientas [load]
		"load-secrets"
		"load-toolbox"

		# Gestión de versiones [tool]
		"update-service-versions"
		"check-version-compatibility"
		"show-version"
		"bump-version"
		"release"
		"check-updates"
		"update-toolbox"

		# Monitoreo [monitoring]
		"metrics"
		"aggregate-logs"
		"alerts"
		"dashboard"
		"test-connectivity"
		"export-metrics"

		# Backups [backup]
		"backup-all"
		"restore-all"
		"restore-interactive"
		"setup-backup-schedule"
		"update-images"

		# CI/CD [ci-cd]
		"ci-validate"
		"ci-test"
		"test"
		"test-unit"
		"test-integration"
		"install-bats"
		"lint"
		"lint-fix"
		"check-docs"

		# Comandos ocultos/tool
		"network-tool"
		"sleep-tool"
	)
}

# ============================================================================
# Tests de Existencia de Comandos
# ============================================================================

@test "Makefile existe" {
	assert_file_exists "$TEST_MAKEFILE"
}

@test "help-toolbox funciona" {
	run make help-toolbox
	assert_success "$output" "$status" "help-toolbox debería funcionar"
	assert_contains "$output" "Comandos" "help-toolbox debería mostrar comandos"
}

@test "Todos los comandos make están definidos" {
	local failed_commands=()

	for cmd in "${MAKE_COMMANDS[@]}"; do
		# Verificar que el comando está definido usando make -n (dry-run)
		# Esto verifica que existe sin ejecutarlo realmente
		run make -n "$cmd" 2>&1

		# Si el comando no existe, make retornará error con "No rule to make target"
		if [[ "$status" -ne 0 ]] && [[ "$output" == *"No rule to make target"* ]]; then
			failed_commands+=("$cmd")
		fi
	done

	if [[ ${#failed_commands[@]} -gt 0 ]]; then
		echo "❌ FAIL: Los siguientes comandos no están definidos:"
		printf "   %s\n" "${failed_commands[@]}"
		return 1
	fi
}

# ============================================================================
# Tests de Comandos Específicos
# ============================================================================

@test "check-dependencies funciona" {
	# Este comando debería funcionar siempre
	run make check-dependencies
	# Puede fallar si Docker no está disponible, pero el comando existe
	# Solo verificamos que no es "No rule to make target"
	if [[ "$status" -ne 0 ]]; then
		assert_not_contains "$output" "No rule to make target" \
			"check-dependencies debería estar definido"
	fi
}

@test "validate-syntax funciona" {
	# Este comando verifica la sintaxis del Makefile
	run make validate-syntax
	# Debería funcionar siempre que el Makefile sea válido
	assert_success "$output" "$status" "validate-syntax debería funcionar"
}

@test "status funciona" {
	# Este comando solo muestra el estado de contenedores
	run make status
	# Puede no haber contenedores, pero el comando debería ejecutarse
	# Solo verificamos que no es "No rule to make target"
	if [[ "$status" -ne 0 ]]; then
		assert_not_contains "$output" "No rule to make target" \
			"status debería estar definido"
	fi
}

@test "help-toolbox lista todos los comandos principales" {
	run make help-toolbox
	assert_success "$output" "$status" "help-toolbox debería funcionar"

	# Verificar que aparecen comandos principales
	assert_contains "$output" "init-env" "help-toolbox debería listar init-env"
	assert_contains "$output" "validate" "help-toolbox debería listar validate"
	assert_contains "$output" "start" "help-toolbox debería listar start"
	assert_contains "$output" "backup-all" "help-toolbox debería listar backup-all"
}

# ============================================================================
# Tests de Comandos con Parámetros Requeridos
# ============================================================================

@test "Comandos con parámetros requeridos muestran mensaje de error apropiado" {
	# shell requiere SERVICE
	run make shell
	assert_failure "$output" "$status" "shell sin SERVICE debería fallar"
	assert_contains "$output" "SERVICE" "shell debería mencionar SERVICE en el error"

	# exec requiere SERVICE y CMD
	run make exec
	assert_failure "$output" "$status" "exec sin parámetros debería fallar"
	assert_contains "$output" "SERVICE" "exec debería mencionar SERVICE en el error"

	# restore-interactive requiere SERVICE
	run make restore-interactive
	assert_failure "$output" "$status" "restore-interactive sin SERVICE debería fallar"
	assert_contains "$output" "SERVICE" "restore-interactive debería mencionar SERVICE en el error"

	# rollback requiere STATE
	run make rollback
	assert_failure "$output" "$status" "rollback sin STATE debería fallar"
	assert_contains "$output" "STATE" "rollback debería mencionar STATE en el error"

	# bump-version requiere PART
	run make bump-version
	assert_failure "$output" "$status" "bump-version sin PART debería fallar"
	assert_contains "$output" "PART" "bump-version debería mencionar PART en el error"
}

# ============================================================================
# Tests de Comandos que No Requieren Dependencias
# ============================================================================

@test "Comandos de información funcionan sin dependencias" {
	# Estos comandos deberían funcionar sin Docker o .env
	run make show-version
	# Puede fallar si no hay .version, pero el comando existe
	if [[ "$status" -ne 0 ]]; then
		assert_not_contains "$output" "No rule to make target" \
			"show-version debería estar definido"
	fi

	run make list-states
	# Puede no haber estados, pero el comando debería ejecutarse
	if [[ "$status" -ne 0 ]]; then
		assert_not_contains "$output" "No rule to make target" \
			"list-states debería estar definido"
	fi
}

# ============================================================================
# Tests de Alias
# ============================================================================

@test "Alias up apunta a start" {
	# up es un alias de start
	run make -n up
	assert_success "$output" "$status" "up debería estar definido"

	# Verificar que up llama a start
	run make -n up 2>&1
	assert_contains "$output" "start" "up debería llamar a start"
}

@test "Alias down apunta a stop" {
	# down es un alias de stop
	run make -n down
	assert_success "$output" "$status" "down debería estar definido"

	# Verificar que down llama a stop
	run make -n down 2>&1
	assert_contains "$output" "stop" "down debería llamar a stop"
}

# ============================================================================
# Tests de Categorías en help-toolbox
# ============================================================================

@test "help-toolbox muestra todas las categorías" {
	run make help-toolbox
	assert_success "$output" "$status" "help-toolbox debería funcionar"

	# Verificar que aparecen las categorías principales
	assert_contains "$output" "Comandos Principales" \
		"help-toolbox debería mostrar categoría 'Comandos Principales'"
	assert_contains "$output" "Validación de Configuración" \
		"help-toolbox debería mostrar categoría 'Validación de Configuración'"
	assert_contains "$output" "Gestión de Seguridad" \
		"help-toolbox debería mostrar categoría 'Gestión de Seguridad'"
	assert_contains "$output" "Monitoreo y Métricas" \
		"help-toolbox debería mostrar categoría 'Monitoreo y Métricas'"
	assert_contains "$output" "Backups y Restauraciones" \
		"help-toolbox debería mostrar categoría 'Backups y Restauraciones'"
	assert_contains "$output" "Integración CI/CD" \
		"help-toolbox debería mostrar categoría 'Integración CI/CD'"
}

# ============================================================================
# Tests de Comandos de CI/CD
# ============================================================================

@test "Comandos de CI/CD están definidos" {
	run make -n ci-validate
	assert_success "$output" "$status" "ci-validate debería estar definido"

	run make -n ci-test
	assert_success "$output" "$status" "ci-test debería estar definido"

	run make -n test
	assert_success "$output" "$status" "test debería estar definido"

	run make -n lint
	assert_success "$output" "$status" "lint debería estar definido"
}

# ============================================================================
# Tests de Comandos de Validación
# ============================================================================

@test "Comandos de validación están definidos" {
	run make -n validate
	assert_success "$output" "$status" "validate debería estar definido"

	run make -n validate-ips
	assert_success "$output" "$status" "validate-ips debería estar definido"

	run make -n check-ports
	assert_success "$output" "$status" "check-ports debería estar definido"

	run make -n doctor
	assert_success "$output" "$status" "doctor debería estar definido"
}

# ============================================================================
# Tests de Comandos de Servicios
# ============================================================================

@test "Comandos de servicios están definidos" {
	run make -n start
	assert_success "$output" "$status" "start debería estar definido"

	run make -n stop
	assert_success "$output" "$status" "stop debería estar definido"

	run make -n build
	assert_success "$output" "$status" "build debería estar definido"

	run make -n clean
	assert_success "$output" "$status" "clean debería estar definido"
}

# ============================================================================
# Tests de Comandos de Backup
# ============================================================================

@test "Comandos de backup están definidos" {
	run make -n backup-all
	assert_success "$output" "$status" "backup-all debería estar definido"

	run make -n restore-all
	assert_success "$output" "$status" "restore-all debería estar definido"

	run make -n update-images
	assert_success "$output" "$status" "update-images debería estar definido"
}

# ============================================================================
# Tests de Comandos de Monitoreo
# ============================================================================

@test "Comandos de monitoreo están definidos" {
	run make -n metrics
	assert_success "$output" "$status" "metrics debería estar definido"

	run make -n alerts
	assert_success "$output" "$status" "alerts debería estar definido"

	run make -n dashboard
	assert_success "$output" "$status" "dashboard debería estar definido"
}

# ============================================================================
# Tests de Comandos de Versiones
# ============================================================================

@test "Comandos de versiones están definidos" {
	run make -n show-version
	assert_success "$output" "$status" "show-version debería estar definido"

	run make -n check-updates
	assert_success "$output" "$status" "check-updates debería estar definido"

	run make -n update-toolbox
	assert_success "$output" "$status" "update-toolbox debería estar definido"
}

# ============================================================================
# Tests de Comandos de Seguridad
# ============================================================================

@test "Comandos de seguridad están definidos" {
	run make -n secrets-check
	assert_success "$output" "$status" "secrets-check debería estar definido"

	run make -n validate-passwords
	assert_success "$output" "$status" "validate-passwords debería estar definido"

	run make -n security-audit
	assert_success "$output" "$status" "security-audit debería estar definido"
}

# ============================================================================
# Tests de Comandos de Setup
# ============================================================================

@test "Comandos de setup están definidos" {
	run make -n setup
	assert_success "$output" "$status" "setup debería estar definido"

	run make -n install-dependencies
	assert_success "$output" "$status" "install-dependencies debería estar definido"

	run make -n verify-installation
	assert_success "$output" "$status" "verify-installation debería estar definido"
}

# ============================================================================
# Tests de Comandos Ocultos/Tool
# ============================================================================

@test "Comandos tool están definidos" {
	run make -n network-tool
	assert_success "$output" "$status" "network-tool debería estar definido"

	run make -n sleep-tool
	assert_success "$output" "$status" "sleep-tool debería estar definido"
}
