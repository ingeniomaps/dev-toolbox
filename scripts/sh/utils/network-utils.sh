#!/usr/bin/env bash
# ============================================================================
# Script: network-utils.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Funciones utilitarias para trabajar con redes Docker.
#
# Retorno:
#   N/A (librería para source)
# ============================================================================

# Función: Unir elementos de un array con un separador
# Uso: join "." "101" "80" -> "101.80"
# Parámetros:
#   $1 - Separador
#   $2... - Elementos a unir
join() {
	local IFS="$1"
	shift
	echo "$*"
}

# Función: Obtiene el subnet de una red Docker existente
#
# Algoritmo:
#   1. Usa docker network inspect para obtener información JSON de la red
#   2. Extrae el campo "Subnet" usando grep con lookbehind positivo
#   3. Retorna el primer subnet encontrado (una red puede tener múltiples subnets)
#
# Ejemplo:
#   get_network_subnet "my-network"
#   Resultado: "172.20.0.0/16"
#
# Parámetros:
#   $1 - Nombre de la red
# Retorna: Subnet de la red (ej: "172.20.0.0/16") o cadena vacía si no existe
get_network_subnet() {
	local network_name="$1"

	if [[ -z "$network_name" ]]; then
		echo ""
		return 1
	fi

	# Obtener subnet de la red desde JSON de docker network inspect
	# Busca el patrón "Subnet": "172.20.0.0/16" y extrae solo el valor
	docker network inspect "$network_name" 2>/dev/null | \
		grep -oP '"Subnet":\s*"\K[^"]+' | head -1 || echo ""
}

# Función: Verifica si una red tiene contenedores conectados
#
# Algoritmo:
#   Docker siempre incluye el objeto "Containers" en network inspect, incluso
#   si está vacío. Para verificar si realmente tiene contenedores, buscamos
#   el patrón "Containers": { ... } donde hay contenido dentro de las llaves.
#
#   El patrón regex busca:
#   - "Containers": seguido de espacios
#   - { seguido de al menos un carácter que no sea }
#   - Al menos otro carácter antes del }
#
# Ejemplo:
#   network_has_containers "my-network"
#   Retorna: 0 si tiene contenedores, 1 si está vacía
#
# Parámetros:
#   $1 - Nombre de la red
# Retorna: 0 si tiene contenedores, 1 si no
network_has_containers() {
	local network_name="$1"

	if [[ -z "$network_name" ]]; then
		return 1
	fi

	# Verificar si el objeto Containers tiene contenido
	# El objeto siempre existe, pero puede estar vacío: "Containers": {}
	# Buscamos el patrón que indica que hay contenido dentro de las llaves
	if docker network inspect "$network_name" 2>/dev/null | \
		grep -q '"Containers":\s*{[^}]*[^}]'; then
		return 0
	fi

	return 1
}

# Función: Lista contenedores conectados a una red
#
# Parámetros:
#   $1 - Nombre de la red
# Retorna: Lista de nombres de contenedores (una por línea)
network_list_containers() {
	local network_name="$1"

	if [[ -z "$network_name" ]]; then
		return 1
	fi

	docker network inspect "$network_name" 2>/dev/null | \
		jq -r '.[0].Containers // {} | keys[]' 2>/dev/null || \
	docker network inspect "$network_name" 2>/dev/null | \
		grep -oP '"Containers":\s*\{[^}]*\}' | \
		grep -oP '"[^"]+":' | \
		sed 's/":$//' | \
		sed 's/^"//' || true
}
