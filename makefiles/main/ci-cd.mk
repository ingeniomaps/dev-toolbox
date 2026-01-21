# ============================================================================
# Integración CI/CD
# ============================================================================
# Comandos para validación y tests en entornos CI/CD.
#
# Uso:
#   make ci-validate
#   make ci-test
#   make test
#
# Retorno:
#   0 si todas las validaciones/tests pasan
#   1 si hay errores
# ============================================================================

_ROOT := $(or $(TOOLBOX_ROOT),$(PROJECT_ROOT))
TESTS_DIR := $(_ROOT)scripts/sh/tests
SETUP_DIR := $(_ROOT)scripts/sh/setup

.PHONY: ci-validate ci-test test test-unit test-integration install-bats \
	lint lint-fix check-docs test-coverage coverage-report validate-pre-commit

ci-validate: check-dependencies ## Validación para CI/CD [ci-cd]
	@$(call LOG_STEP, Validación para CI/CD...);
	@$(MAKE) check-dependencies;
	@$(MAKE) validate;
	@$(MAKE) validate-syntax;
	@$(MAKE) secrets-check;
	@$(call LOG_SUCCESS, Validación CI/CD completada);

ci-test: check-dependencies ## Tests para CI/CD [ci-cd]
	@$(call LOG_STEP, Ejecutando tests para CI/CD...);
	@if [ -f "$(TESTS_DIR)/test-makefile.sh" ]; then \
		$(MAKE) test; \
	else \
		$(call LOG_WARN, Tests no disponibles script no encontrado); \
		$(call LOG_INFO, Saltando tests...); \
	fi
	@$(call LOG_SUCCESS, Tests CI/CD completados);

test: check-dependencies ## Ejecuta todos los tests (unitarios e integración) [ci-cd]
	@$(call LOG_STEP, Ejecutando tests...);
	@if command -v bats >/dev/null 2>&1; then \
		$(MAKE) test-unit; \
		$(MAKE) test-integration; \
	elif [ -f "$(TOOLBOX_ROOT).bats/bin/bats" ]; then \
		export PATH="$(TOOLBOX_ROOT).bats/bin:$$PATH"; \
		$(MAKE) test-unit; \
		$(MAKE) test-integration; \
	else \
		$(call LOG_WARN, BATS no está instalado); \
		$(call LOG_INFO, Instalando BATS...); \
		$(MAKE) install-bats; \
		export PATH="$(TOOLBOX_ROOT).bats/bin:$$PATH"; \
		$(MAKE) test-unit; \
		$(MAKE) test-integration; \
	fi
	@$(call LOG_SUCCESS, Todos los tests completados);

test-unit: check-dependencies ## Ejecuta tests unitarios [ci-cd]
	@$(call LOG_STEP, Ejecutando tests unitarios...);
	@BATS_CMD=$$(command -v bats 2>/dev/null || echo "$(TOOLBOX_ROOT).bats/bin/bats"); \
	if [ ! -x "$$BATS_CMD" ]; then \
		$(call LOG_ERROR, BATS no está instalado. Ejecuta: make install-bats); \
		exit 1; \
	fi; \
	if [ -d "$(TOOLBOX_ROOT)tests/unit" ]; then \
		$$BATS_CMD "$(TOOLBOX_ROOT)tests/unit" || exit 1; \
		$(call LOG_SUCCESS, Tests unitarios completados); \
	else \
		$(call LOG_WARN, No hay tests unitarios en tests/unit/); \
	fi

test-integration: check-dependencies ## Ejecuta tests de integración [ci-cd]
	@$(call LOG_STEP, Ejecutando tests de integración...);
	@BATS_CMD=$$(command -v bats 2>/dev/null || echo "$(TOOLBOX_ROOT).bats/bin/bats"); \
	if [ ! -x "$$BATS_CMD" ]; then \
		$(call LOG_ERROR, BATS no está instalado. Ejecuta: make install-bats); \
		exit 1; \
	fi; \
	if [ -d "$(TOOLBOX_ROOT)tests/integration" ]; then \
		$$BATS_CMD "$(TOOLBOX_ROOT)tests/integration" || exit 1; \
		$(call LOG_SUCCESS, Tests de integración completados); \
	else \
		$(call LOG_WARN, No hay tests de integración en tests/integration/); \
	fi

install-bats: ## Instala BATS (Bash Automated Testing System) [ci-cd]
	@if [ ! -f "$(SETUP_DIR)/install-bats.sh" ]; then \
		$(call LOG_ERROR, Script install-bats.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(SETUP_DIR)/install-bats.sh"

lint: check-dependencies ## Ejecuta linters (shellcheck y shfmt) [ci-cd]
	@if [ ! -f "$(_ROOT)scripts/sh/utils/lint.sh" ]; then \
		$(call LOG_ERROR, Script lint.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(_ROOT)scripts/sh/utils/lint.sh" --check-only

lint-fix: check-dependencies ## Ejecuta linters y aplica correcciones automáticas [ci-cd]
	@if [ ! -f "$(_ROOT)scripts/sh/utils/lint.sh" ]; then \
		$(call LOG_ERROR, Script lint.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(_ROOT)scripts/sh/utils/lint.sh" --fix

check-docs: ## Verifica documentación de scripts [ci-cd]
	@if [ ! -f "$(_ROOT)scripts/sh/utils/check-documentation.sh" ]; then \
		$(call LOG_ERROR, Script check-documentation.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(_ROOT)scripts/sh/utils/check-documentation.sh"

test-coverage: check-dependencies ## Calcula cobertura de tests [ci-cd]
	@$(call LOG_STEP, Calculando cobertura de tests...);
	@if [ ! -f "$(_ROOT)scripts/sh/utils/calculate-coverage.sh" ]; then \
		$(call LOG_ERROR, Script calculate-coverage.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" \
		COVERAGE_MIN="$(COVERAGE_MIN)" \
		bash "$(_ROOT)scripts/sh/utils/calculate-coverage.sh" \
		--format=text --min="$(or $(COVERAGE_MIN),80)"

coverage-report: check-dependencies ## Genera reporte de cobertura (HTML) [ci-cd]
	@$(call LOG_STEP, Generando reporte de cobertura...);
	@if [ ! -f "$(_ROOT)scripts/sh/utils/calculate-coverage.sh" ]; then \
		$(call LOG_ERROR, Script calculate-coverage.sh no encontrado); \
		exit 1; \
	fi
	@mkdir -p "$(CURDIR)/coverage"
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" \
		COVERAGE_MIN="$(or $(COVERAGE_MIN),80)" \
		bash "$(_ROOT)scripts/sh/utils/calculate-coverage.sh" \
		--format=html --output="$(CURDIR)/coverage/coverage.html" --min="$(or $(COVERAGE_MIN),80)"
	@$(call LOG_SUCCESS, Reporte generado en coverage/coverage.html)
