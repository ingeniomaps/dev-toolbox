#!/usr/bin/env bash
# ============================================================================
# Script: detect-os.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Helper para detectar el sistema operativo y el entorno de ejecución.
# Detecta Linux, macOS, Windows (nativo y WSL), y proporciona información
# sobre compatibilidad.
#
# Uso:
#   source scripts/sh/utils/detect-os.sh
#   detect_os
#   is_wsl
#   is_windows_native
#   require_unix
#
# Funciones:
#   detect_os()          - Detecta OS y establece variables OS_TYPE, OS_NAME
#   is_wsl()             - Verifica si está ejecutándose en WSL
#   is_windows_native()  - Verifica si está ejecutándose en Windows nativo
#   require_unix()       - Verifica que el OS sea compatible (Linux/macOS/WSL)
#   get_os_name()        - Obtiene nombre amigable del OS
#   get_wsl_info()       - Obtiene información sobre WSL si está disponible
#
# Variables exportadas:
#   OS_TYPE     - Tipo de OS: linux, darwin, windows, wsl
#   OS_NAME     - Nombre del OS: Linux, macOS, Windows, WSL
#   IS_WSL      - true/false si está en WSL
#   IS_WINDOWS  - true/false si está en Windows (nativo o WSL)
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Detectar sistema operativo
detect_os() {
	local uname_s
	uname_s=$(uname -s 2>/dev/null || echo "Unknown")

	# Detectar WSL
	if [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
		export OS_TYPE="wsl"
		export OS_NAME="WSL"
		export IS_WSL=true
		export IS_WINDOWS=false  # WSL se comporta como Linux para nuestros propósitos
		return 0
	fi

	# Detectar Windows nativo (Git Bash, MSYS2, etc.)
	case "$uname_s" in
		MINGW*|MSYS*|CYGWIN*)
			export OS_TYPE="windows"
			export OS_NAME="Windows"
			export IS_WSL=false
			export IS_WINDOWS=true
			return 0
			;;
		Linux)
			export OS_TYPE="linux"
			export OS_NAME="Linux"
			export IS_WSL=false
			export IS_WINDOWS=false
			return 0
			;;
		Darwin)
			export OS_TYPE="darwin"
			export OS_NAME="macOS"
			export IS_WSL=false
			export IS_WINDOWS=false
			return 0
			;;
		*)
			export OS_TYPE="unknown"
			export OS_NAME="Unknown"
			export IS_WSL=false
			export IS_WINDOWS=false
			return 1
			;;
	esac
}

# Verifica si está ejecutándose en WSL
is_wsl() {
	if [[ -z "${IS_WSL:-}" ]]; then
		detect_os
	fi
	[[ "${IS_WSL:-}" == "true" ]]
}

# Verifica si está ejecutándose en Windows nativo
is_windows_native() {
	if [[ -z "${IS_WINDOWS:-}" ]]; then
		detect_os
	fi
	[[ "${IS_WINDOWS:-}" == "true" ]]
}

# Verifica que el OS sea compatible con Unix (Linux/macOS/WSL)
require_unix() {
	if [[ -z "${OS_TYPE:-}" ]]; then
		detect_os
	fi

	case "${OS_TYPE:-}" in
		linux|darwin|wsl)
			return 0
			;;
		windows)
			return 1
			;;
		*)
			return 1
			;;
	esac
}

# Obtiene nombre amigable del OS
get_os_name() {
	if [[ -z "${OS_NAME:-}" ]]; then
		detect_os
	fi
	echo "${OS_NAME:-Unknown}"
}

# Obtiene información sobre WSL
get_wsl_info() {
	if ! is_wsl; then
		return 1
	fi

	local wsl_version=""
	local distro_name=""

	# Detectar versión de WSL
	if command -v wsl.exe >/dev/null 2>&1; then
		wsl_version=$(wsl.exe --version 2>/dev/null | head -1 || echo "WSL")
	else
		wsl_version="WSL1 o WSL2 (no determinado)"
	fi

	# Detectar distribución
	if [[ -f /etc/os-release ]]; then
		distro_name=$(grep "^PRETTY_NAME=" /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "Linux")
	else
		distro_name="Linux"
	fi

	echo "WSL: $wsl_version sobre $distro_name"
}

# Inicializar detección al cargar
detect_os
