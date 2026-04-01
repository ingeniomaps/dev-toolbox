#!/usr/bin/env bash
# ============================================================================
# Funciones: coverage-output.sh
# Ubicación: scripts/sh/utils/
# ============================================================================
# Funciones para generar salida en diferentes formatos (text, JSON, HTML).
# ============================================================================

# Función: Generar salida en texto
output_text() {
	local total="$1"
	local tested="$2"
	local untested="$3"
	local coverage="$4"
	local min_coverage="$5"
	local project_root="$6"
	local untested_scripts_var="$7"
	local tested_scripts_var="$8"
	local script_to_test_var="$9"
	local output_file="${10}"

	# shellcheck disable=SC2154
	# Las referencias dinámicas (local -n) se crean aquí
	local -n untested_scripts_ref=$untested_scripts_var
	local -n tested_scripts_ref=$tested_scripts_var
	local -n script_to_test_ref=$script_to_test_var

	{
		echo "=========================================="
		echo "  Reporte de Cobertura de Tests"
		echo "=========================================="
		echo ""
		echo "📊 Estadísticas Generales:"
		echo "  Total de scripts:     $total"
		echo "  Scripts con tests:    $tested"
		echo "  Scripts sin tests:    $untested"
		echo "  Cobertura:           ${coverage}%"
		echo "  Mínimo requerido:    ${min_coverage}%"
		echo ""

		if [[ $coverage -ge $min_coverage ]]; then
			echo "✅ Cobertura aceptable (>= ${min_coverage}%)"
		else
			echo "❌ Cobertura insuficiente (< ${min_coverage}%)"
		fi
		echo ""

		if [[ ${#untested_scripts_ref[@]} -gt 0 ]]; then
			echo "📝 Scripts sin tests (${#untested_scripts_ref[@]}):"
			for script in "${untested_scripts_ref[@]}"; do
				local rel_path="${script#"$project_root"/}"
				echo "  - $rel_path"
			done
			echo ""
		fi

		if [[ ${#tested_scripts_ref[@]} -gt 0 ]]; then
			echo "✅ Scripts con tests (${#tested_scripts_ref[@]}):"
			local count=0
			for script in "${tested_scripts_ref[@]}"; do
				local rel_path="${script#"$project_root"/}"
				local test_file="${script_to_test_ref[$script]}"
				local test_count
				test_count=$(count_tests_in_file "$test_file")
				echo "  - $rel_path (${test_count} tests)"
				((count++))
				if [[ $count -ge 20 ]]; then
					echo "  ... y $((tested - count)) más"
					break
				fi
			done
			echo ""
		fi

		echo "=========================================="
	} > "${output_file:-/dev/stdout}"
}

# Función: Generar salida en JSON
output_json() {
	local total="$1"
	local tested="$2"
	local untested="$3"
	local coverage="$4"
	local min_coverage="$5"
	local project_root="$6"
	local untested_scripts_var="$7"
	local tested_scripts_var="$8"
	local script_to_test_var="$9"
	local output_file="${10}"

	# shellcheck disable=SC2154
	# Las referencias dinámicas (local -n) se crean aquí
	local -n untested_scripts_ref=$untested_scripts_var
	local -n tested_scripts_ref=$tested_scripts_var
	local -n script_to_test_ref=$script_to_test_var

	{
		echo "{"
		echo "  \"coverage\": {"
		echo "    \"total_scripts\": $total,"
		echo "    \"tested_scripts\": $tested,"
		echo "    \"untested_scripts\": $untested,"
		echo "    \"coverage_percent\": $coverage,"
		echo "    \"min_required\": $min_coverage,"
		echo "    \"meets_requirement\": $([ "$coverage" -ge "$min_coverage" ] && echo "true" || echo "false")"
		echo "  },"
		echo "  \"tested_scripts\": ["

		local first=true
		for script in "${tested_scripts_ref[@]}"; do
			if [[ "$first" == "true" ]]; then
				first=false
			else
				echo ","
			fi
			local rel_path="${script#"$project_root"/}"
			local test_file="${script_to_test_ref[$script]}"
			local test_count
			test_count=$(count_tests_in_file "$test_file")
			echo -n "    {"
			echo -n "\"script\": \"$rel_path\","
			echo -n "\"test_file\": \"${test_file#"$project_root"/}\","
			echo -n "\"test_count\": $test_count"
			echo -n "}"
		done

		echo ""
		echo "  ],"
		echo "  \"untested_scripts\": ["

		first=true
		for script in "${untested_scripts_ref[@]}"; do
			if [[ "$first" == "true" ]]; then
				first=false
			else
				echo ","
			fi
			local rel_path="${script#"$project_root"/}"
			echo -n "    \"$rel_path\""
		done

		echo ""
		echo "  ]"
		echo "}"
	} > "${output_file:-/dev/stdout}"
}

# Función: Generar salida en HTML
output_html() {
	local total="$1"
	local tested="$2"
	local untested="$3"
	local coverage="$4"
	local min_coverage="$5"
	local project_root="$6"
	local untested_scripts_var="$7"
	local tested_scripts_var="$8"
	local script_to_test_var="$9"
	local output_file="${10}"

	# shellcheck disable=SC2154
	# Las referencias dinámicas (local -n) se crean aquí
	local -n untested_scripts_ref=$untested_scripts_var
	local -n tested_scripts_ref=$tested_scripts_var
	local -n script_to_test_ref=$script_to_test_var

	_status_class=$([ "$coverage" -ge "$min_coverage" ] && echo "success" || echo "error")
	local status_class="$_status_class"
	unset _status_class
	_status_icon=$([ "$coverage" -ge "$min_coverage" ] && echo "✅" || echo "❌")
	local status_icon="$_status_icon"
	unset _status_icon

	{
		cat <<EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte de Cobertura de Tests</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 { color: #333; border-bottom: 3px solid #4CAF50; padding-bottom: 10px; }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .stat-box {
            background: #f9f9f9;
            padding: 15px;
            border-radius: 5px;
            border-left: 4px solid #4CAF50;
        }
        .stat-box h3 { margin: 0 0 10px 0; color: #666; font-size: 14px; }
        .stat-box .value { font-size: 32px; font-weight: bold; color: #333; }
        .coverage-bar {
            background: #e0e0e0;
            height: 30px;
            border-radius: 15px;
            margin: 10px 0;
            overflow: hidden;
        }
        .coverage-fill {
            background: linear-gradient(90deg, #4CAF50, #8BC34A);
            height: 100%;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
        }
        .status { padding: 10px; border-radius: 5px; margin: 20px 0; }
        .status.success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        .status.error {
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #4CAF50; color: white; }
        tr:hover { background: #f5f5f5; }
        .untested { color: #dc3545; }
        .tested { color: #28a745; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 Reporte de Cobertura de Tests</h1>

        <div class="stats">
            <div class="stat-box">
                <h3>Total de Scripts</h3>
                <div class="value">$total</div>
            </div>
            <div class="stat-box">
                <h3>Scripts con Tests</h3>
                <div class="value">$tested</div>
            </div>
            <div class="stat-box">
                <h3>Scripts sin Tests</h3>
                <div class="value">$untested</div>
            </div>
            <div class="stat-box">
                <h3>Cobertura</h3>
                <div class="value">${coverage}%</div>
            </div>
        </div>

        <div class="coverage-bar">
            <div class="coverage-fill" style="width: ${coverage}%;">${coverage}%</div>
        </div>

        <div class="status $status_class">
            $status_icon Cobertura: ${coverage}% (Mínimo requerido: ${min_coverage}%)
        </div>

        <h2>Scripts sin Tests (${#untested_scripts_ref[@]})</h2>
        <table>
            <thead>
                <tr>
                    <th>Script</th>
                </tr>
            </thead>
            <tbody>
EOF

		for script in "${untested_scripts_ref[@]}"; do
			local rel_path="${script#"$project_root"/}"
			echo "                <tr><td class=\"untested\">$rel_path</td></tr>"
		done

		cat <<EOF
            </tbody>
        </table>

        <h2>Scripts con Tests (${#tested_scripts_ref[@]})</h2>
        <table>
            <thead>
                <tr>
                    <th>Script</th>
                    <th>Test File</th>
                    <th>Tests</th>
                </tr>
            </thead>
            <tbody>
EOF

		for script in "${tested_scripts_ref[@]}"; do
			local rel_path="${script#"$project_root"/}"
			local test_file="${script_to_test_ref[$script]}"
			local test_file_rel="${test_file#"$project_root"/}"
			local test_count
			test_count=$(count_tests_in_file "$test_file")
			echo "                <tr>"
			echo "                    <td class=\"tested\">$rel_path</td>"
			echo "                    <td>$test_file_rel</td>"
			echo "                    <td>$test_count</td>"
			echo "                </tr>"
		done

		cat <<EOF
            </tbody>
        </table>

        <p style="text-align: center; color: #666; margin-top: 30px;">
            Generado el $(date '+%Y-%m-%d %H:%M:%S')
        </p>
    </div>
</body>
</html>
EOF
	} > "${output_file:-/dev/stdout}"
}
