#!/usr/bin/env bash
# ============================================================================
# Funciones: version-checks.sh
# Ubicación: scripts/sh/commands/
# ============================================================================
# Funciones de validación para versiones de servicios.
# ============================================================================

# Función: Verificar versión muy antigua
check_too_old() {
	local service_info="$1"
	local version_num=$2
	local version_str="$3"
	local errors_var="$4"

	if ! check_jq; then
		return 1
	fi

	local min_supported
	min_supported=$(echo "$service_info" | jq -r '.min_supported // empty' 2>/dev/null || echo "")

	if [[ -z "$min_supported" ]] || [[ "$min_supported" == "null" ]]; then
		return 1
	fi

	local min_num
	min_num=$(parse_version "$min_supported")

	if compare_versions "$version_num" "$min_num" 2>/dev/null; then
		eval "$errors_var+=(\"Versión $version_str es muy antigua. Versión mínima soportada: $min_supported\")"
		return 0
	fi

	return 1
}

# Función: Verificar versión muy nueva (beta/RC)
check_too_new() {
	local service_info="$1"
	local version_num=$2
	local version_str="$3"
	local warnings_var="$4"

	if ! check_jq; then
		return 1
	fi

	local max_stable
	max_stable=$(echo "$service_info" | jq -r '.max_stable // empty' 2>/dev/null || echo "")

	if [[ -z "$max_stable" ]] || [[ "$max_stable" == "null" ]]; then
		return 1
	fi

	local max_num
	max_num=$(parse_version "$max_stable")

	# Si la versión es > 10% mayor que la máxima estable, es probablemente beta/RC
	local threshold=$((max_num + (max_num / 10)))

	if [[ $version_num -gt $threshold ]]; then
		eval "$warnings_var+=(\"Versión $version_str parece ser una versión beta o release candidate no estable\")"
		return 0
	fi

	return 1
}

# Función: Verificar problemas conocidos
check_known_issues() {
	local service_info="$1"
	local version_str="$2"
	local errors_var="$3"
	local warnings_var="$4"

	if ! check_jq; then
		return 1
	fi

	local major_minor
	major_minor=$(get_major_minor "$version_str")
	local major
	major=$(get_major "$version_str")

	# Buscar problema exacto por versión
	local issue
	issue=$(
		echo "$service_info" | jq -r \
			".known_issues.\"${version_str}\" // .known_issues.\"${major_minor}\" // .known_issues.\"${major}\" // empty" \
			2>/dev/null || echo ""
	)

	if [[ -z "$issue" ]] || [[ "$issue" == "null" ]]; then
		return 1
	fi

	local severity
	severity=$(echo "$issue" | jq -r '.severity // "warning"' 2>/dev/null || echo "warning")
	local message
	message=$(echo "$issue" | jq -r '.message // ""' 2>/dev/null || echo "")

	if [[ "$severity" == "error" ]]; then
		eval "$errors_var+=(\"$message\")"
		return 0
	else
		eval "$warnings_var+=(\"$message\")"
		return 0
	fi
}

# Función: Verificar fecha de EOL
check_eol() {
	local service_info="$1"
	local version_str="$2"
	local errors_var="$3"
	local warnings_var="$4"

	if ! check_jq; then
		return 1
	fi

	local major_minor
	major_minor=$(get_major_minor "$version_str")
	local major
	major=$(get_major "$version_str")

	# Buscar fecha de EOL
	local eol_date
	eol_date=$(
		echo "$service_info" | jq -r \
			".eol_dates.\"${major_minor}\" // .eol_dates.\"${major}\" // empty" \
			2>/dev/null || echo ""
	)

	if [[ -z "$eol_date" ]] || [[ "$eol_date" == "null" ]]; then
		return 1
	fi

	# Verificar si la fecha ya pasó
	local eol_timestamp
	eol_timestamp=$(date -d "$eol_date" +%s 2>/dev/null || \
		date -j -f "%Y-%m-%d" "$eol_date" +%s 2>/dev/null || echo "0")
	local current_timestamp
	current_timestamp=$(date +%s 2>/dev/null || echo "0")

	# Si no se pudieron calcular las fechas, salir
	if [[ $eol_timestamp -eq 0 ]] || [[ $current_timestamp -eq 0 ]]; then
		return 1
	fi

	local days_until_eol=$(((eol_timestamp - current_timestamp) / 86400))

	if [[ $eol_timestamp -gt 0 ]]; then
		if [[ $days_until_eol -lt 0 ]]; then
			local days_ago=$((days_until_eol * -1))
			local eol_msg="Versión $version_str está fuera de soporte (EOL: $eol_date, hace $days_ago días)"
			eval "$errors_var+=(\"$eol_msg\")"
			return 0
		elif [[ $days_until_eol -le 90 ]]; then
			local eol_msg="Versión $version_str se acerca al fin de soporte (EOL: $eol_date, en $days_until_eol días)"
			eval "$warnings_var+=(\"$eol_msg\")"
			return 0
		fi
	fi

	return 1
}

# Función: Verificar requisitos específicos
check_requirements() {
	local service_info="$1"
	local version_str="$2"
	local info_var="$3"

	if ! check_jq; then
		return 1
	fi

	local major_minor
	major_minor=$(get_major_minor "$version_str")
	local major
	major=$(get_major "$version_str")

	# Buscar requisitos por versión
	local requirements
	requirements=$(
		echo "$service_info" | jq -r \
			".requirements.\"${version_str}\" // .requirements.\"${major_minor}\" // .requirements.\"${major}\" // empty" \
			2>/dev/null || echo ""
	)

	if [[ -z "$requirements" ]] || [[ "$requirements" == "null" ]]; then
		return 1
	fi

	local message
	message=$(echo "$requirements" | jq -r '.message // ""' 2>/dev/null || echo "")

	if [[ -n "$message" ]]; then
		eval "$info_var+=(\"$message\")"
	fi

	# Verificar requisito de Docker
	local docker_req
	docker_req=$(echo "$requirements" | jq -r '.docker // empty' 2>/dev/null || echo "")
	if [[ -n "$docker_req" ]] && [[ "$docker_req" != "null" ]]; then
		# Verificar versión de Docker (básico)
		if command -v docker >/dev/null 2>&1; then
			local docker_version
			docker_version=$(docker --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1 || echo "")
			if [[ -n "$docker_version" ]]; then
				eval "$info_var+=(\"Requiere Docker $docker_req (actual: $docker_version)\")"
			fi
		fi
	fi

	return 0
}

# Función: Verificar versión recomendada
check_recommended() {
	local service_info="$1"
	local version_num=$2
	local version_str="$3"
	local warnings_var="$4"

	if ! check_jq; then
		return 1
	fi

	local min_recommended
	min_recommended=$(echo "$service_info" | jq -r '.min_recommended // empty' 2>/dev/null || echo "")

	if [[ -z "$min_recommended" ]] || [[ "$min_recommended" == "null" ]]; then
		return 1
	fi

	local rec_num
	rec_num=$(parse_version "$min_recommended")

	if compare_versions "$version_num" "$rec_num"; then
		eval "$warnings_var+=(\"Versión $version_str es anterior a la recomendada ($min_recommended)\")"
		return 0
	fi

	return 1
}
