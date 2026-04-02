/**
 * @fileoverview Sistema de colores ANSI para JavaScript
 * @description Define códigos de color ANSI para usar en scripts JavaScript
 *              Compatible con Node.js y mongosh
 *
 * @example
 * // En mongosh:
 * load('scripts/js/common/colors.js')
 * print(COLOR_ERROR + 'Error message' + COLOR_RESET)
 *
 * @example
 * // En Node.js:
 * const { COLOR_ERROR, COLOR_RESET } = require('./scripts/js/common/colors.js')
 * console.log(COLOR_ERROR + 'Error message' + COLOR_RESET)
 */

'use strict'

// ============================================================================
// DETECCIÓN DE COLORES
// ============================================================================

/**
 * Detecta si el entorno soporta colores ANSI
 * Similar a colors.sh que verifica [[ -t 1 ]] || [[ -t 2 ]]
 * @returns {boolean} true si se pueden usar colores, false en caso contrario
 */
function supportsColors() {
  // Verificar NO_COLOR primero (estándar para desactivar colores)
  if (
    typeof process !== 'undefined' &&
    (process.env.NO_COLOR === '1' || process.env.NO_COLOR === 'true')
  ) {
    return false
  }

  // En mongosh (incluso con --eval), forzar colores
  if (typeof print !== 'undefined') {
    return true
  }

  // En Node.js, verificar si stdout o stderr son TTY
  if (typeof process !== 'undefined') {
    const hasStdoutTTY = process.stdout && process.stdout.isTTY === true
    const hasStderrTTY = process.stderr && process.stderr.isTTY === true
    const forceColor = process.env.FORCE_COLOR
    if (
      forceColor === '1' ||
      forceColor === 'true' ||
      forceColor === '2' ||
      forceColor === '3'
    ) {
      return true
    }
    return hasStdoutTTY || hasStderrTTY
  }

  // Sin terminal, no usar colores
  return false
}

// ============================================================================
// DEFINICIÓN DE COLORES CON TERMINAL
// ============================================================================

/**
 * Colores ANSI para terminal (cuando hay soporte)
 * @readonly
 * @type {Object<string, string>}
 */
const colorsWithTerminal = Object.freeze({
  // Control y Reset
  COLOR_RESET: '\x1b[0m',

  // Colores Semánticos (Recomendados para uso general)
  COLOR_ERROR: '\x1b[1;31m', // Rojo brillante para errores
  COLOR_INFO: '\x1b[1;34m', // Azul brillante para información
  COLOR_OK: '\x1b[1;32m', // Verde brillante para éxito
  COLOR_WARN: '\x1b[1;33m', // Amarillo brillante para advertencias

  // Colores Básicos (Intensidad Normal)
  COLOR_BLACK: '\x1b[0;30m',
  COLOR_RED: '\x1b[0;31m',
  COLOR_GREEN: '\x1b[0;32m',
  COLOR_YELLOW: '\x1b[0;33m',
  COLOR_BLUE: '\x1b[0;34m',
  COLOR_PURPLE: '\x1b[0;35m',
  COLOR_CYAN: '\x1b[0;36m',
  COLOR_WHITE: '\x1b[0;37m',

  // Colores Brillantes (Intensidad Alta)
  COLOR_BRIGHT_BLACK: '\x1b[1;30m',
  COLOR_BRIGHT_RED: '\x1b[1;31m',
  COLOR_BRIGHT_GREEN: '\x1b[1;32m',
  COLOR_BRIGHT_YELLOW: '\x1b[1;33m',
  COLOR_BRIGHT_BLUE: '\x1b[1;34m',
  COLOR_BRIGHT_PURPLE: '\x1b[1;35m',
  COLOR_BRIGHT_CYAN: '\x1b[1;36m',
  COLOR_BRIGHT_WHITE: '\x1b[1;37m',

  // Colores Especiales
  COLOR_TITLE: '\x1b[1m', // Negrita (sin color específico)
  COLOR_CMD: '\x1b[36m', // Cyan (alias de COLOR_CYAN)
  COLOR_DEPRECATED: '\x1b[1;33m' // Amarillo brillante (alias de COLOR_WARN)
})

// ============================================================================
// DEFINICIÓN DE COLORES SIN TERMINAL
// ============================================================================

/**
 * Colores vacíos (sin formato) cuando no hay terminal
 * Similar a colors.sh que desactiva colores si no hay terminal
 * @readonly
 * @type {Object<string, string>}
 */
const colorsWithoutTerminal = Object.freeze({
  COLOR_RESET: '',
  COLOR_ERROR: '',
  COLOR_INFO: '',
  COLOR_OK: '',
  COLOR_WARN: '',
  COLOR_BLACK: '',
  COLOR_RED: '',
  COLOR_GREEN: '',
  COLOR_YELLOW: '',
  COLOR_BLUE: '',
  COLOR_PURPLE: '',
  COLOR_CYAN: '',
  COLOR_WHITE: '',
  COLOR_BRIGHT_BLACK: '',
  COLOR_BRIGHT_RED: '',
  COLOR_BRIGHT_GREEN: '',
  COLOR_BRIGHT_YELLOW: '',
  COLOR_BRIGHT_BLUE: '',
  COLOR_BRIGHT_PURPLE: '',
  COLOR_BRIGHT_CYAN: '',
  COLOR_BRIGHT_WHITE: '',
  COLOR_TITLE: '',
  COLOR_CMD: '',
  COLOR_DEPRECATED: ''
})

// ============================================================================
// OBTENER COLORES ACTIVOS
// ============================================================================

/**
 * Obtiene el objeto de colores apropiado según el entorno
 * @returns {Object<string, string>} Objeto con códigos de color
 */
function getColors() {
  return supportsColors() ? colorsWithTerminal : colorsWithoutTerminal
}

// Obtener colores activos
const activeColors = getColors()

// Extraer constantes individuales para compatibilidad
const COLOR_RESET = activeColors.COLOR_RESET
const COLOR_ERROR = activeColors.COLOR_ERROR
const COLOR_INFO = activeColors.COLOR_INFO
const COLOR_OK = activeColors.COLOR_OK
const COLOR_WARN = activeColors.COLOR_WARN
const COLOR_BLACK = activeColors.COLOR_BLACK
const COLOR_RED = activeColors.COLOR_RED
const COLOR_GREEN = activeColors.COLOR_GREEN
const COLOR_YELLOW = activeColors.COLOR_YELLOW
const COLOR_BLUE = activeColors.COLOR_BLUE
const COLOR_PURPLE = activeColors.COLOR_PURPLE
const COLOR_CYAN = activeColors.COLOR_CYAN
const COLOR_WHITE = activeColors.COLOR_WHITE
const COLOR_BRIGHT_BLACK = activeColors.COLOR_BRIGHT_BLACK
const COLOR_BRIGHT_RED = activeColors.COLOR_BRIGHT_RED
const COLOR_BRIGHT_GREEN = activeColors.COLOR_BRIGHT_GREEN
const COLOR_BRIGHT_YELLOW = activeColors.COLOR_BRIGHT_YELLOW
const COLOR_BRIGHT_BLUE = activeColors.COLOR_BRIGHT_BLUE
const COLOR_BRIGHT_PURPLE = activeColors.COLOR_BRIGHT_PURPLE
const COLOR_BRIGHT_CYAN = activeColors.COLOR_BRIGHT_CYAN
const COLOR_BRIGHT_WHITE = activeColors.COLOR_BRIGHT_WHITE
const COLOR_TITLE = activeColors.COLOR_TITLE
const COLOR_CMD = activeColors.COLOR_CMD
const COLOR_DEPRECATED = activeColors.COLOR_DEPRECATED

// ============================================================================
// EXPORTACIÓN
// ============================================================================

// Exportar para Node.js (CommonJS)
if (typeof module !== 'undefined' && typeof module.exports !== 'undefined') {
  module.exports = {
    // Constantes de colores
    COLOR_RESET,
    COLOR_ERROR,
    COLOR_INFO,
    COLOR_OK,
    COLOR_WARN,
    COLOR_BLACK,
    COLOR_RED,
    COLOR_GREEN,
    COLOR_YELLOW,
    COLOR_BLUE,
    COLOR_PURPLE,
    COLOR_CYAN,
    COLOR_WHITE,
    COLOR_BRIGHT_BLACK,
    COLOR_BRIGHT_RED,
    COLOR_BRIGHT_GREEN,
    COLOR_BRIGHT_YELLOW,
    COLOR_BRIGHT_BLUE,
    COLOR_BRIGHT_PURPLE,
    COLOR_BRIGHT_CYAN,
    COLOR_BRIGHT_WHITE,
    COLOR_TITLE,
    COLOR_CMD,
    COLOR_DEPRECATED,
    // Objetos y funciones
    colors: activeColors,
    supportsColors,
    getColors
  }
}

// Exportar para mongosh (hacer disponible globalmente)
if (typeof global !== 'undefined') {
  global.COLOR_RESET = COLOR_RESET
  global.COLOR_ERROR = COLOR_ERROR
  global.COLOR_INFO = COLOR_INFO
  global.COLOR_OK = COLOR_OK
  global.COLOR_WARN = COLOR_WARN
  global.COLOR_BLACK = COLOR_BLACK
  global.COLOR_RED = COLOR_RED
  global.COLOR_GREEN = COLOR_GREEN
  global.COLOR_YELLOW = COLOR_YELLOW
  global.COLOR_BLUE = COLOR_BLUE
  global.COLOR_PURPLE = COLOR_PURPLE
  global.COLOR_CYAN = COLOR_CYAN
  global.COLOR_WHITE = COLOR_WHITE
  global.COLOR_BRIGHT_BLACK = COLOR_BRIGHT_BLACK
  global.COLOR_BRIGHT_RED = COLOR_BRIGHT_RED
  global.COLOR_BRIGHT_GREEN = COLOR_BRIGHT_GREEN
  global.COLOR_BRIGHT_YELLOW = COLOR_BRIGHT_YELLOW
  global.COLOR_BRIGHT_BLUE = COLOR_BRIGHT_BLUE
  global.COLOR_BRIGHT_PURPLE = COLOR_BRIGHT_PURPLE
  global.COLOR_BRIGHT_CYAN = COLOR_BRIGHT_CYAN
  global.COLOR_BRIGHT_WHITE = COLOR_BRIGHT_WHITE
  global.COLOR_TITLE = COLOR_TITLE
  global.COLOR_CMD = COLOR_CMD
  global.COLOR_DEPRECATED = COLOR_DEPRECATED
  global.colors = activeColors
  global.supportsColors = supportsColors
  global.getColors = getColors
}

// También hacer disponible directamente en el scope global para mongosh
// (las variables const/let en scope global están disponibles después de load())
