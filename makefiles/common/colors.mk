# ============================================================================
# Colores ANSI para Makefiles
# ============================================================================
# Define códigos de color ANSI para usar en mensajes de Makefiles.
# Uso: echo "$(COLOR_ERROR)mensaje de error$(COLOR_RESET)"
#
# NOTAS:
#   - Usar `:=` para asignación inmediata (más eficiente en Make)
#   - Siempre cerrar con COLOR_RESET al final del mensaje
#   - Los colores solo funcionan en terminales que soporten ANSI
# ============================================================================

# ============================================================================
# Control y Reset
# ============================================================================
COLOR_RESET := \033[0m

# ============================================================================
# Colores Semánticos (Recomendados para uso general)
# ============================================================================
COLOR_ERROR := \033[1;31m  # Rojo brillante para errores
COLOR_INFO  := \033[1;34m  # Azul brillante para información
COLOR_OK    := \033[1;32m  # Verde brillante para éxito
COLOR_WARN  := \033[1;33m  # Amarillo brillante para advertencias

# ============================================================================
# Colores Básicos (Intensidad Normal)
# ============================================================================
COLOR_BLACK   := \033[0;30m
COLOR_RED     := \033[0;31m
COLOR_GREEN   := \033[0;32m
COLOR_YELLOW  := \033[0;33m
COLOR_BLUE    := \033[0;34m
COLOR_PURPLE  := \033[0;35m
COLOR_CYAN    := \033[0;36m
COLOR_WHITE   := \033[0;37m

# ============================================================================
# Colores Brillantes (Intensidad Alta)
# ============================================================================
COLOR_BRIGHT_BLACK   := \033[1;30m
COLOR_BRIGHT_RED     := \033[1;31m
COLOR_BRIGHT_GREEN   := \033[1;32m
COLOR_BRIGHT_YELLOW  := \033[1;33m
COLOR_BRIGHT_BLUE    := \033[1;34m
COLOR_BRIGHT_PURPLE  := \033[1;35m
COLOR_BRIGHT_CYAN    := \033[1;36m
COLOR_BRIGHT_WHITE   := \033[1;37m

# ============================================================================
# Colores Especiales para Sistema de Ayuda
# ============================================================================
COLOR_TITLE      := \033[1m         # Negrita (sin color específico)
COLOR_CMD        := \033[36m        # Cyan (alias de COLOR_CYAN)
COLOR_DEPRECATED := \033[1;33m      # Amarillo brillante (alias de COLOR_WARN)

# ============================================================================
# Notas de Compatibilidad
# ============================================================================
# COLOR_INFO     = COLOR_BRIGHT_BLUE  (alias semántico)
# COLOR_OK       = COLOR_BRIGHT_GREEN (alias semántico)
# COLOR_WARN     = COLOR_BRIGHT_YELLOW (alias semántico)
# COLOR_ERROR    = COLOR_BRIGHT_RED   (alias semántico)
# COLOR_CMD      = COLOR_CYAN         (alias para comandos en ayuda)
# COLOR_DEPRECATED = COLOR_WARN       (alias para comandos obsoletos)
