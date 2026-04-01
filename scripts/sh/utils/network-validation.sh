#!/usr/bin/env bash
# ============================================================================
# Script: network-validation.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Funciones de validación para redes Docker.
#
# Uso:
#   source scripts/sh/utils/network-validation.sh
#
# Retorno:
#   N/A (librería para source)
# ============================================================================

# Función: Valida formato de IP base
#
# Verifica que la IP tenga formato válido (ej: 172.20.0.0)
# y que los primeros dos octetos sean válidos para subnet /16
#
# Parámetros:
#   $1 - IP base a validar
# Retorna: 0 si es válida, 1 si no
validate_ip_base() {
	local ip_base="$1"

	if [[ -z "$ip_base" ]]; then
		return 1
	fi

	# Verificar formato básico (4 octetos separados por punto)
	if ! [[ "$ip_base" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		return 1
	fi

	# Extraer octetos
	local octets
	IFS='.' read -ra octets <<< "$ip_base"

	# Verificar que todos los octetos están en rango válido (0-255)
	for octet in "${octets[@]}"; do
		if [[ $octet -lt 0 ]] || [[ $octet -gt 255 ]]; then
			return 1
		fi
	done

	# Verificar que no sea una IP reservada común
	# 127.x.x.x (localhost)
	if [[ ${octets[0]} -eq 127 ]]; then
		return 1
	fi

	# 169.254.x.x (link-local)
	if [[ ${octets[0]} -eq 169 ]] && [[ ${octets[1]} -eq 254 ]]; then
		return 1
	fi

	# 224-255.x.x.x (multicast/broadcast)
	if [[ ${octets[0]} -ge 224 ]]; then
		return 1
	fi

	return 0
}

# Función: Busca redes con configuraciones similares o conflictivas
#
# Busca todas las redes que podrían tener conflictos potenciales:
# - Mismo subnet exacto
# - Subnets que se solapan
# - Redes con nombres similares
#
# Parámetros:
#   $1 - Subnet a verificar (ej: "172.20.0.0/16")
#   $2 - Nombre de red (opcional, para excluir de resultados)
# Retorna: Lista de redes conflictivas (formato: nombre|subnet, una por línea)
find_conflicting_networks() {
	local target_subnet="$1"
	local exclude_network="${2:-}"
	local conflicts=()

	if [[ -z "$target_subnet" ]]; then
		return 1
	fi

	# Extraer IP base del subnet (ej: "172.20.0.0/16" -> "172.20.0.0")
	_target_ip=$(echo "$target_subnet" | cut -d'/' -f1)
	local target_ip="$_target_ip"
	unset _target_ip
	local target_octets
	IFS='.' read -ra target_octets <<< "$target_ip"

	# Buscar todas las redes existentes
	while IFS= read -r net_name || [[ -n "$net_name" ]]; do
		[[ -z "$net_name" ]] && continue
		[[ "$net_name" == "$exclude_network" ]] && continue

		local net_subnet
		net_subnet=$(get_network_subnet "$net_name")

		if [[ -z "$net_subnet" ]]; then
			continue
		fi

		# Verificar mismo subnet exacto
		if [[ "$net_subnet" == "$target_subnet" ]]; then
			conflicts+=("$net_name|$net_subnet|exact_match")
			continue
		fi

		# Verificar solapamiento de subnet (/16 con mismos primeros 2 octetos)
		_net_ip=$(echo "$net_subnet" | cut -d'/' -f1)
		local net_ip="$_net_ip"
		unset _net_ip
		local net_octets
		IFS='.' read -ra net_octets <<< "$net_ip"

		if [[ ${net_octets[0]} -eq ${target_octets[0]} ]] && \
		   [[ ${net_octets[1]} -eq ${target_octets[1]} ]]; then
			# Mismos primeros 2 octetos = potencial solapamiento
			conflicts+=("$net_name|$net_subnet|overlap")
		fi
	done < <(docker network ls --format "{{.Name}}" 2>/dev/null || true)

	# Imprimir resultados
	for conflict in "${conflicts[@]}"; do
		echo "$conflict"
	done

	return 0
}

# Función: Valida configuración de red completa antes de usar
#
# Realiza validaciones exhaustivas:
# 1. Formato de IP base
# 2. Validez de subnet calculado
# 3. Conflictos con redes existentes
# 4. Verificación de que Docker puede crear la red
#
# Parámetros:
#   $1 - Nombre de la red
#   $2 - IP base
# Retorna: 0 si todo es válido, 1 si hay problemas
validate_network_before_use() {
	local network_name="$1"
	local network_ip="$2"

	if [[ -z "$network_name" ]] || [[ -z "$network_ip" ]]; then
		return 1
	fi

	# Validar formato de IP base
	if ! validate_ip_base "$network_ip"; then
		log_error "IP base inválida: $network_ip"
		log_info "La IP debe tener formato válido (ej: 172.20.0.0)"
		log_info "No debe ser una IP reservada (127.x.x.x, 169.254.x.x, 224-255.x.x.x)"
		return 1
	fi

	# Calcular subnet esperado
	local networkParts
	IFS='.' read -ra networkParts <<< "$network_ip"
	_network_net=$(join . "${networkParts[@]:0:2}")
	local networkNet="$_network_net"
	unset _network_net
	local expected_subnet="${networkNet}.0.0/16"

	# Verificar conflictos potenciales ANTES de intentar crear
	local conflicts
	conflicts=$(find_conflicting_networks "$expected_subnet" "$network_name" 2>/dev/null || true)

	if [[ -n "$conflicts" ]]; then
		log_warn "Se detectaron posibles conflictos de red:"
		while IFS='|' read -r conflict_net conflict_subnet conflict_type; do
			[[ -z "$conflict_net" ]] && continue
			case "$conflict_type" in
				exact_match)
					log_error "  • $conflict_net: mismo subnet exacto ($conflict_subnet)"
					;;
				overlap)
					log_warn "  • $conflict_net: subnet solapado ($conflict_subnet)"
					;;
			esac
		done < <(echo "$conflicts")
		# No falla aquí, solo advierte - el código posterior manejará el conflicto
	fi

	return 0
}

# Función: Valida la configuración de una red existente
#
# Algoritmo:
#   1. Obtiene el subnet actual de la red usando get_network_subnet()
#   2. Compara el subnet actual con el esperado
#   3. Retorna éxito solo si coinciden exactamente
#
# Ejemplo:
#   validate_network_config "my-network" "172.20.0.0/16"
#   - Si la red tiene subnet "172.20.0.0/16" -> retorna 0 (éxito)
#   - Si la red tiene subnet "172.21.0.0/16" -> retorna 1 (diferente)
#
# Parámetros:
#   $1 - Nombre de la red
#   $2 - Subnet esperado (ej: "172.20.0.0/16")
# Retorna: 0 si la configuración es correcta, 1 si es diferente o no existe
validate_network_config() {
	local network_name="$1"
	local expected_subnet="$2"

	if [[ -z "$network_name" ]] || [[ -z "$expected_subnet" ]]; then
		return 1
	fi

	# Obtener subnet actual de la red
	local current_subnet
	current_subnet=$(get_network_subnet "$network_name")

	# Si no se pudo obtener subnet, la red no existe o hay error
	if [[ -z "$current_subnet" ]]; then
		return 1
	fi

	# Comparar subnets exactamente
	if [[ "$current_subnet" == "$expected_subnet" ]]; then
		return 0
	else
		return 1
	fi
}
