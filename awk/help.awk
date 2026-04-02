#!/usr/bin/awk -f
# ============================================================================
# Script: help.awk
# Descripción: Genera ayuda formateada desde Makefiles con soporte para
#              categorías, orden personalizado y comandos deprecados.
#
# Uso: awk -f help.awk [Makefiles...]
#
# Variables de entorno:
#   HELP_CATS  - Categorías: "tag1:Nombre1,tag2:Nombre2,..."
#   HELP_ORDER - Orden: "tag1,tag2,..." (opcional, se deriva de HELP_CATS)
#
# Formato de entrada:
#   target: ## Descripción [tag]  (normal)
#   target: ## Descripción [DEPRECATED: razón] [tag]  (deprecado)
#
# Autor: Infrastructure Toolbox
# ============================================================================

BEGIN {
	FS = ":.*##";

	# Constantes
	CMD_WIDTH = 30;          # Ancho de columna para comandos
	DEPRECATED_PREFIX_LEN = 12;  # Longitud de "[DEPRECATED:"
	DEPRECATED_SUFFIX_LEN = 1;   # Longitud de "]"

	# Colores ANSI (compatibles con colors.mk)
	# Nota: En AWK no podemos acceder directamente a variables de Make,
	# pero mantenemos los mismos valores que colors.mk
	COLOR_TITLE      = "\033[1m";
	COLOR_CMD        = "\033[36m";
	COLOR_DEPRECATED = "\033[1;33m";
	COLOR_RESET      = "\033[0m";

	# Cargar categorías desde HELP_CATS
	load_categories();

	# Cargar orden desde HELP_ORDER o derivar de HELP_CATS
	load_order();

	# Inicializar contadores para cada categoría
	init_counters();
}

# ============================================================================
# Funciones de Utilidad
# ============================================================================

# Cargar categorías desde variable de entorno HELP_CATS
# Formato: "tag1:Nombre1,tag2:Nombre2,..."
function load_categories() {
	if (ENVIRON["HELP_CATS"] != "") {
		parse_categories(ENVIRON["HELP_CATS"], cats);
	} else {
		# Valores por defecto (compatibilidad hacia atrás)
		cats["help"] = "Comandos PostgreSQL";
	}
}

# Cargar orden desde HELP_ORDER o derivar de HELP_CATS
# Formato: "tag1,tag2,tag3,..."
function load_order() {
	if (ENVIRON["HELP_ORDER"] != "") {
		parse_order(ENVIRON["HELP_ORDER"], order);
	} else if (ENVIRON["HELP_CATS"] != "") {
		# Derivar orden del orden en HELP_CATS
		parse_order_from_cats(ENVIRON["HELP_CATS"], order);
	} else {
		# Valores por defecto (compatibilidad hacia atrás)
		order[1] = "help";
		order_count = 1;
	}
}

# Inicializar contadores para cada categoría
function init_counters() {
	for (i = 1; i <= order_count; i++) {
		tag = order[i];
		if (tag != "") {
			count[tag] = 0;
		}
	}
}

# Parsear categorías desde string
# Parsea "tag1:Nombre1,tag2:Nombre2,..." y llena el array cats
function parse_categories(cats_str, result_array,     pairs, pair, i) {
	split(cats_str, pairs, ",");
	for (i = 1; i <= length(pairs); i++) {
		if (pairs[i] != "") {
			split(pairs[i], pair, ":");
			if (length(pair) == 2) {
				result_array[pair[1]] = pair[2];
			}
		}
	}
}

# Parsear orden desde string
# Parsea "tag1,tag2,tag3,..." y llena el array order
function parse_order(order_str, result_array,     items, tag, i) {
	split(order_str, items, ",");
	order_count = 0;
	for (i = 1; i <= length(items); i++) {
		if (items[i] != "") {
			tag = items[i];
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", tag);
			if (tag != "" && cats[tag] != "") {
				result_array[++order_count] = tag;
			}
		}
	}
}

# Derivar orden desde HELP_CATS
function parse_order_from_cats(cats_str, result_array,     pairs, pair, tag, i) {
	split(cats_str, pairs, ",");
	order_count = 0;
	for (i = 1; i <= length(pairs); i++) {
		if (pairs[i] != "") {
			split(pairs[i], pair, ":");
			if (length(pair) == 2) {
				tag = pair[1];
				gsub(/^[[:space:]]+|[[:space:]]+$/, "", tag);
				if (tag != "" && cats[tag] != "") {
					result_array[++order_count] = tag;
				}
			}
		}
	}
}

# Extraer mensaje de deprecación de descripción
# Retorna el mensaje si existe, vacío si no
function extract_deprecated_msg(desc,     match_result, start_pos) {
	if (desc ~ /\[DEPRECATED:/) {
		match(desc, /\[DEPRECATED:[^]]+\]/);
		if (RSTART > 0) {
			return substr(desc, RSTART + DEPRECATED_PREFIX_LEN,
			              RLENGTH - DEPRECATED_PREFIX_LEN - DEPRECATED_SUFFIX_LEN);
		}
	}
	return "";
}

# Limpiar descripción (eliminar tags y espacios)
function clean_description(desc) {
	gsub(/\[[^]]+\]/, "", desc);  # Eliminar tags como [tag]
	gsub(/^[[:space:]]+|[[:space:]]+$/, "", desc);  # Trim espacios
	return desc;
}

# Ordenar array alfabéticamente (bubble sort)
# Nota: Para arrays pequeños (<100 items) bubble sort es aceptable
function sort_array(arr, n,     i, j, tmp) {
	for (i = 1; i <= n; i++) {
		for (j = i + 1; j <= n; j++) {
			if (arr[i] > arr[j]) {
				tmp = arr[i];
				arr[i] = arr[j];
				arr[j] = tmp;
			}
		}
	}
}

# ============================================================================
# Procesamiento de Líneas
# ============================================================================

# Procesar líneas que coincidan con formato de ayuda Makefile
# Formato: target: ## Descripción [tag]
/^[a-zA-Z0-9_-]+:.*##/ {
	for (i = 1; i <= order_count; i++) {
		tag = order[i];
		if (tag != "" && $0 ~ "\\[" tag "\\]") {
			cmd = $1;
			cmd_key = tag SUBSEP cmd;

			# Evitar duplicados
			if (!seen[cmd_key]) {
				seen[cmd_key] = 1;

				# Extraer y procesar descripción
				desc = $2;
				deprecated_msg = extract_deprecated_msg(desc);
				desc = clean_description(desc);

				# Almacenar comando y descripción
				count[tag]++;
				idx = tag SUBSEP count[tag];
				commands[idx] = cmd;

				desc_idx = tag SUBSEP cmd;
				descriptions[desc_idx] = desc;
				deprecated[desc_idx] = deprecated_msg;
			}
		}
	}
}

# ============================================================================
# Generación de Salida
# ============================================================================

END {
	for (i = 1; i <= order_count; i++) {
		tag = order[i];
		if (tag != "" && count[tag] > 0) {
			print_category(tag);
		}
	}
}

# Imprimir una categoría con sus comandos
function print_category(tag,     n, j, idx, sorted, cmd, desc_idx, desc, dep_msg) {
	n = 0;

	# Recopilar comandos de esta categoría
	for (j = 1; j <= count[tag]; j++) {
		idx = tag SUBSEP j;
		if (commands[idx] != "") {
			sorted[++n] = commands[idx];
		}
	}

	# Ordenar alfabéticamente
	if (n > 0) {
		sort_array(sorted, n);

		# Imprimir encabezado de categoría
		printf "\n%s%s:%s\n\n", COLOR_TITLE, cats[tag], COLOR_RESET;

		# Imprimir comandos
		for (j = 1; j <= n; j++) {
			cmd = sorted[j];
			desc_idx = tag SUBSEP cmd;
			desc = descriptions[desc_idx];
			dep_msg = deprecated[desc_idx];

			if (dep_msg != "") {
				# Comando deprecado
				printf "  %s%-" CMD_WIDTH "s%s %s ⚠️  %s[DEPRECATED: %s]%s\n",
				       COLOR_CMD, cmd, COLOR_RESET, desc,
				       COLOR_DEPRECATED, dep_msg, COLOR_RESET;
			} else {
				# Comando normal
				printf "  %s%-" CMD_WIDTH "s%s %s\n",
				       COLOR_CMD, cmd, COLOR_RESET, desc;
			}
		}
	}
}
