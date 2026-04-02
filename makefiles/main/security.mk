# ============================================================================
# Comandos de Seguridad
# ============================================================================
# Validación de secretos y complejidad de contraseñas en .env
#
# Uso:
#   make secrets-check      - Patrones inseguros y valores por defecto en .env
#   make validate-passwords - Complejidad de variables tipo PASSWORD/SECRET/TOKEN
#
# Requisitos:
#   - .env en la raíz del proyecto (secrets-check; validate-passwords lo usa)
#
# Para generar contraseñas:
#   bash scripts/sh/utils/generate-password.sh [longitud]
# ============================================================================

# Rutas a scripts
COMMANDS_DIR := $(or $(TOOLBOX_ROOT),$(PROJECT_ROOT))scripts/sh/commands

.PHONY: secrets-check validate-passwords security-audit check-secrets-expiry rotate-secrets

# ============================================================================
# Validación de Secretos
# ============================================================================

secrets-check: ## Validación mejorada de secretos [security]
	@if [ ! -f "$(COMMANDS_DIR)/improved-secrets-check.sh" ]; then \
		$(call LOG_ERROR, Script improved-secrets-check.sh no encontrado en $(COMMANDS_DIR)); \
		exit 1; \
	fi
	@FORCE_COLOR=1 bash "$(COMMANDS_DIR)/improved-secrets-check.sh" "$(CURDIR)/.env"

# ============================================================================
# Validación de Contraseñas
# ============================================================================

validate-passwords: ## Valida complejidad de todas las contraseñas en .env [security]
	@if [ ! -f "$(COMMANDS_DIR)/validate-passwords.sh" ]; then \
		$(call LOG_ERROR, Script validate-passwords.sh no encontrado en $(COMMANDS_DIR)); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(COMMANDS_DIR)/validate-passwords.sh"

security-audit: ## Auditoría completa de seguridad [security]
	@if [ ! -f "$(COMMANDS_DIR)/security-audit.sh" ]; then \
		$(call LOG_ERROR, Script security-audit.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(COMMANDS_DIR)/security-audit.sh" $(if $(EXPORT),--export=$(EXPORT),)

check-secrets-expiry: ## Verifica secretos próximos a expirar [security]
	@if [ ! -f "$(COMMANDS_DIR)/check-secrets-expiry.sh" ]; then \
		$(call LOG_ERROR, Script check-secrets-expiry.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" \
		SECRETS_EXPIRY_DAYS="$(SECRETS_EXPIRY_DAYS)" \
		SECRETS_EXPIRY_WARN_ONLY="$(SECRETS_EXPIRY_WARN_ONLY)" \
		bash "$(COMMANDS_DIR)/check-secrets-expiry.sh" \
		$(if $(SECRETS_EXPIRY_DAYS),--days=$(SECRETS_EXPIRY_DAYS),) \
		$(if $(filter true,$(SECRETS_EXPIRY_WARN_ONLY)),--warn-only,) \
		$(if $(EXPORT),--export=$(EXPORT),)

rotate-secrets: ## Rota secretos automáticamente [security]
	@if [ ! -f "$(COMMANDS_DIR)/rotate-secrets.sh" ]; then \
		$(call LOG_ERROR, Script rotate-secrets.sh no encontrado); \
		exit 1; \
	fi
	@FORCE_COLOR=1 PROJECT_ROOT="$(CURDIR)" bash "$(COMMANDS_DIR)/rotate-secrets.sh" "$(SERVICE)"
