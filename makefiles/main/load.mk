# ============================================================================
# Infisical y Carga del Toolbox
# ============================================================================
# Carga secretos desde Infisical y clona/actualiza dev-toolbox como dependencia.
#
# Uso:
#   make load-secrets    - Obtener variables de Infisical y exportarlas
#   make load-toolbox    - Clona o actualiza dev-toolbox en .toolbox
#
# Requisitos load-secrets:
#   - INFISICAL_URL, INFISICAL_GLOBAL_TOKEN, INFISICAL_PROJECT_TOKEN en el shell
#
# Requisitos load-toolbox:
#   - GIT_USER, GIT_TOKEN exportadas en el shell
#
# Variables opcionales (load-toolbox):
#   - GIT_BRANCH, GIT_REPO, TOOLBOX_TARGET (ver scripts/sh/setup/load-toolbox.sh)
# ============================================================================

.PHONY: load-secrets load-toolbox
SCRIPTS_UTILS := $(or $(TOOLBOX_ROOT),$(PROJECT_ROOT))scripts/sh/utils

load-secrets: ## Obtener variables de entorno de Infisical y exportarlas [load]
	@KEYCHAIN_SCRIPT="$(SCRIPTS_UTILS)/keychain.sh"; \
	if [ -f "$$KEYCHAIN_SCRIPT" ]; then \
		source "$$KEYCHAIN_SCRIPT" 2>/dev/null || true; \
		if keychain_available 2>/dev/null; then \
			BACKEND=$$(keychain_backend 2>/dev/null || echo "none"); \
			if [ "$$BACKEND" != "none" ]; then \
				echo "Usando keychain (backend: $$BACKEND) para tokens de Infisical..."; \
				INFISICAL_GLOBAL_TOKEN=$$(keychain_get infisical global-token 2>/dev/null || echo ""); \
				INFISICAL_PROJECT_TOKEN=$$(keychain_get infisical project-token 2>/dev/null || echo ""); \
			fi; \
		fi; \
	fi; \
	if [ -z "$${INFISICAL_GLOBAL_TOKEN:-}" ] && [ -z "$${INFISICAL_PROJECT_TOKEN:-}" ]; then \
		$(call LOG_WARN, Tokens de Infisical no encontrados. Usa keychain o variables de entorno); \
		$(call LOG_INFO, Para usar keychain: keychain_set infisical global-token <token>); \
		$(call LOG_INFO, O exporta: INFISICAL_GLOBAL_TOKEN y INFISICAL_PROJECT_TOKEN); \
		exit 1; \
	fi; \
	if [ -n "$${INFISICAL_GLOBAL_TOKEN:-}" ]; then \
		curl --silent --fail --request GET \
			--url "$${INFISICAL_URL}/api/v3/secrets/raw" \
			--header "Authorization: Bearer $$INFISICAL_GLOBAL_TOKEN" \
		| bash $(SCRIPTS_UTILS)/infisical-to-env.sh || true; \
	fi; \
	if [ -n "$${INFISICAL_PROJECT_TOKEN:-}" ]; then \
		curl --silent --fail --request GET \
			--url "$${INFISICAL_URL}/api/v3/secrets/raw" \
			--header "Authorization: Bearer $$INFISICAL_PROJECT_TOKEN" \
		| bash $(SCRIPTS_UTILS)/infisical-to-env.sh || true; \
	fi

load-toolbox: ## Clona o actualiza dev-toolbox en .toolbox; requiere GIT_USER y GIT_TOKEN [load]
	@bash $(or $(TOOLBOX_ROOT),$(PROJECT_ROOT))scripts/sh/setup/load-toolbox.sh
