#!/usr/bin/env bash
# ============================================================================
# Script: network-ensure.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Función principal para crear/verificar redes Docker.
#
# Uso:
#   source scripts/sh/utils/network-ensure.sh
#
# Retorno:
#   N/A (librería para source)
# ============================================================================

# Función: Comprueba si una red de Docker existe; la crea si no existe
#
# Algoritmo completo:
#   1. Valida parámetros (nombre de red e IP base)
#   2. Verifica que Docker esté instalado y corriendo
#   3. Calcula subnet esperado desde IP base (ej: "172.20.0.0" -> "172.20.0.0/16")
#   4. Verifica si la red ya existe:
#      a. Si existe y tiene la configuración correcta -> éxito
#      b. Si existe con configuración diferente:
#         - Muestra advertencia con opciones
#         - Si --recreate está activo, elimina y recrea (con confirmación si hay contenedores)
#         - Si no, muestra sugerencias y falla
#   5. Si no existe, crea la red con el subnet calculado
#
# Cálculo de subnet:
#   - Toma los primeros 2 octetos de la IP base
#   - Crea subnet /16 (ej: "172.20.0.0" -> "172.20.0.0/16")
#   - Esto permite hasta 65534 hosts en la red
#
# Ejemplo:
#   ensure_docker_network "my-network" "172.20.0.0"
#   - Calcula subnet: "172.20.0.0/16"
#   - Si la red no existe: crea "my-network" con subnet "172.20.0.0/16"
#   - Si existe con subnet diferente: muestra advertencia
#
# Parámetros:
#   $1 - Nombre de la red (ej: "toolbox-network")
#   $2 - Dirección IP base para calcular subnet (ej: "172.20.0.0")
#   $3 - Si es "true", recrea la red si existe con configuración diferente
# Retorna:
#   0 si la red existe o se creó correctamente
#   1 si hubo un error al crear la red o configuración conflictiva
ensure_docker_network() {
	local networkName="$1"
	local networkIp="$2"
	local recreate="${3:-false}"

	# Validar parámetros
	if [[ -z "$networkName" ]]; then
		log_error "ensure_docker_network: se requiere el nombre de la red"
		return 1
	fi

	if [[ -z "$networkIp" ]]; then
		log_error "ensure_docker_network: se requiere la dirección IP base"
		return 1
	fi

	# Verificar que Docker está disponible
	if ! command -v docker >/dev/null 2>&1; then
		log_error "Docker no está instalado o no está en el PATH"
		log_info "💡 Sugerencia: Instala Docker desde https://docs.docker.com/get-docker/"
		return 1
	fi

	# Verificar que Docker está corriendo
	if ! docker info >/dev/null 2>&1; then
		log_error "Docker no está corriendo. Inicia el servicio Docker y vuelve a intentar"
		log_info "💡 Sugerencia:"
		log_info "   Linux: sudo systemctl start docker"
		log_info "   macOS/Windows: Inicia Docker Desktop desde aplicaciones"
		return 1
	fi

	# Validar configuración de red ANTES de proceder
	if ! validate_network_before_use "$networkName" "$networkIp"; then
		log_error "Configuración de red inválida. Corrige los errores anteriores"
		return 1
	fi

	# Calcular subnet esperado desde IP base
	# Ejemplo: "172.20.0.0" -> ["172", "20", "0", "0"] -> "172.20" -> "172.20.0.0/16"
	local networkParts
	IFS='.' read -ra networkParts <<< "$networkIp"
	_network_net=$(join . "${networkParts[@]:0:2}")
	local networkNet="$_network_net"
	unset _network_net
	local expected_subnet="${networkNet}.0.0/16"

	# Verificar si la red ya existe
	if docker network ls -q -f "name=^${networkName}$" | grep -q .; then
		log_info "La red $networkName ya existe"

		# Validar configuración de la red existente
		if validate_network_config "$networkName" "$expected_subnet"; then
			log_success "La red $networkName tiene la configuración correcta (subnet: $expected_subnet)"
			return 0
		else
			local current_subnet
			current_subnet=$(get_network_subnet "$networkName")

			log_separator
			log_warn "⚠️  CONFIGURACIÓN DE RED DIFERENTE DETECTADA"
			log_separator
			echo "" >&2
			log_error "La red '$networkName' existe pero con configuración diferente:"
			echo "  • Subnet actual:   ${current_subnet:-desconocido}" >&2
			echo "  • Subnet esperado:  $expected_subnet" >&2
			echo "" >&2

			# Verificar si tiene contenedores conectados y listarlos
			if network_has_containers "$networkName"; then
				log_warn "⚠️  La red tiene contenedores conectados:"
				local containers
				containers=$(network_list_containers "$networkName" 2>/dev/null || true)
				if [[ -n "$containers" ]]; then
					while IFS= read -r container; do
						[[ -z "$container" ]] && continue
						echo "     • $container" >&2
					done < <(echo "$containers")
				fi
				echo "" >&2
				log_warn "Recrear la red desconectará estos contenedores y pueden dejar de funcionar."
				echo "" >&2
			fi

			if [[ "$recreate" == "true" ]]; then
				log_info "Modo --recreate activado. Recreando la red..."
				echo "" >&2

				# Verificar contenedores antes de eliminar
				if network_has_containers "$networkName"; then
					log_warn "ADVERTENCIA: La red tiene contenedores conectados."
					printf '%b' "${COLOR_WARN:-}¿Continuar y eliminar la red? (s/N): ${COLOR_RESET:-}"
					read -r CONFIRM

					if [[ "$CONFIRM" != "s" ]] && [[ "$CONFIRM" != "S" ]]; then
						log_info "Operación cancelada"
						return 1
					fi
				fi

				# Eliminar red existente
				if docker network rm "$networkName" 2>/dev/null; then
					log_success "Red $networkName eliminada"
				else
					log_error "No se pudo eliminar la red $networkName"
					log_info "💡 Sugerencia: Detén los contenedores conectados primero"
					return 1
				fi
			else
				log_info "Opciones para resolver el conflicto:"
				echo "  1. Recrear la red automáticamente:" >&2
				echo "     make network-tool RECREATE=true" >&2
				echo "     o" >&2
				echo "     ./scripts/sh/utils/ensure-network.sh --recreate" >&2
				echo "" >&2
				echo "  2. Usar la configuración actual:" >&2
				echo "     Actualiza NETWORK_IP en tu .env para que coincida con el subnet actual" >&2
				echo "     Subnet actual: ${current_subnet:-desconocido}" >&2
				echo "     Para calcular IP base desde subnet: toma los primeros 2 octetos + .0.0" >&2
				echo "     Ejemplo: subnet 172.20.0.0/16 -> NETWORK_IP=172.20.0.0" >&2
				echo "" >&2
				echo "  3. Ver información detallada de la red:" >&2
				echo "     docker network inspect $networkName" >&2
				echo "" >&2
				echo "  4. Eliminar manualmente y recrear (⚠️ detén contenedores primero):" >&2
				if network_has_containers "$networkName"; then
					echo "     # Primero, detén los contenedores conectados:" >&2
					local containers
					containers=$(network_list_containers "$networkName" 2>/dev/null || true)
					if [[ -n "$containers" ]]; then
						while IFS= read -r container; do
							[[ -z "$container" ]] && continue
							echo "     docker stop $container" >&2
						done < <(echo "$containers")
					fi
					echo "     # Luego elimina y recrea:" >&2
				fi
				echo "     docker network rm $networkName" >&2
				echo "     make network-tool" >&2
				echo "" >&2
				log_separator
				return 1
			fi
		fi
	fi

	# Calcular subnet (si no se calculó antes)
	if [[ -z "${expected_subnet:-}" ]]; then
		local networkParts
		IFS='.' read -ra networkParts <<< "$networkIp"
		_network_net=$(join . "${networkParts[@]:0:2}")
		local networkNet="$_network_net"
		unset _network_net
		expected_subnet="${networkNet}.0.0/16"
	fi
	local subnet="$expected_subnet"

	# Verificar si ya existe una red con el mismo subnet ANTES de intentar crear
	local existing_networks=()
	while IFS= read -r net_name || [[ -n "$net_name" ]]; do
		if [[ -n "$net_name" ]] && [[ "$net_name" != "$networkName" ]]; then
			if docker network inspect "$net_name" 2>/dev/null | \
				grep -q "\"Subnet\": \"${subnet}\""; then
				existing_networks+=("$net_name")
			fi
		fi
	done < <(docker network ls --format "{{.Name}}" 2>/dev/null || true)

	if [[ ${#existing_networks[@]} -gt 0 ]]; then
		log_separator
		log_warn "⚠️  CONFLICTO DE SUBNET DETECTADO"
		log_separator
		echo "" >&2
		log_error "No se puede crear la red '$networkName' porque ya existe otra(s)" \
			"red(es) con el mismo subnet (${subnet}):"
		for net in "${existing_networks[@]}"; do
			echo "  • $net" >&2
		done
		echo "" >&2
		log_info "💡 Opciones para resolver el conflicto:"
		echo "  1. Usar la red existente:" >&2
		echo "     Cambia NETWORK_NAME en tu .env a uno de los nombres arriba" >&2
		echo "     Ejemplo: NETWORK_NAME=${existing_networks[0]}" >&2
		echo "" >&2
		echo "  2. Cambiar el subnet:" >&2
		echo "     Modifica NETWORK_IP en tu .env a un subnet diferente" >&2
		echo "     Ejemplo: NETWORK_IP=101.81.0.0 (o cualquier otro subnet no usado)" >&2
		echo "" >&2
		echo "  3. Eliminar la red existente (si no está en uso):" >&2
		echo "     docker network rm ${existing_networks[0]}" >&2
		echo "     make network-tool" >&2
		echo "" >&2
		log_separator
		return 1
	fi

	# Intentar crear la red solo si no hay conflictos
	local create_output
	create_output=$(docker network create --driver=bridge --subnet="${subnet}" \
		"$networkName" 2>&1)
	local create_exit=$?

	if [[ $create_exit -eq 0 ]]; then
		log_success "Red $networkName creada exitosamente (subnet: $subnet)"
		# Verificar que la red realmente se creó
		if ! docker network ls -q -f "name=^${networkName}$" | grep -q .; then
			log_error "La red $networkName no se creó correctamente"
			log_info "💡 Sugerencia: Verifica los logs de Docker para más detalles"
			return 1
		fi

		# Verificar que la configuración es correcta
		if validate_network_config "$networkName" "$subnet"; then
			log_success "Configuración de la red verificada correctamente"
		else
			log_warn "La red se creó pero la configuración no coincide con lo esperado"
		fi

		return 0
	else
		# Si falla por otro motivo, verificar si es por solapamiento
		if echo "$create_output" | grep -qi "overlaps\|pool"; then
			log_separator
			log_error "❌ ERROR AL CREAR LA RED (SOLAPAMIENTO DE SUBNET)"
			log_separator
			echo "" >&2
			log_error "Error: $create_output"
			echo "" >&2
			log_info "El subnet ${subnet} está en conflicto con otra red existente."
			log_info "💡 Soluciones:"
			echo "  1. Cambia NETWORK_IP en tu .env a un subnet diferente" >&2
			echo "     Ejemplo: NETWORK_IP=101.81.0.0" >&2
			echo "" >&2
			echo "  2. Lista redes existentes para ver qué subnets están en uso:" >&2
			echo "     docker network ls" >&2
			echo "     docker network inspect <nombre-red>" >&2
			echo "" >&2
			log_separator
		elif echo "$create_output" | grep -qi "already exists"; then
			log_error "La red $networkName ya existe"
			log_info "💡 Sugerencia: Usa --recreate para recrearla si es necesario"
		else
			log_separator
			log_error "❌ ERROR AL CREAR LA RED"
			log_separator
			echo "" >&2
			log_error "Error: $create_output"
			echo "" >&2
			log_info "💡 Sugerencias:"
			echo "  • Verifica que Docker está corriendo: docker info" >&2
			echo "  • Verifica permisos: docker network ls" >&2
			echo "  • Revisa los logs: docker system events" >&2
			echo "" >&2
			log_separator
		fi
		return 1
	fi
}
