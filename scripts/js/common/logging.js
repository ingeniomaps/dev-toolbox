/**
 * @fileoverview Sistema de Logging para JavaScript
 * @description Sistema completo de logging con niveles, timestamps, colores,
 *              control de verbosidad y soporte para logging a archivo
 *              Compatible con Node.js y mongosh
 *
 * @example
 * // En mongosh:
 * load('scripts/js/common/logging.js')
 * log_info('Iniciando proceso')
 * log_success('Operación completada')
 *
 * @example
 * // En Node.js:
 * const { log_info, log_success, log_error } = require('./scripts/js/common/logging.js')
 * log_info('Iniciando proceso')
 *
 * @example
 * // Configuración:
 * global.LOG_LEVEL = 'DEBUG'  // DEBUG, INFO, SUCCESS, WARN, ERROR
 * global.VERBOSE = true
 * global.LOG_TIMESTAMP = true
 * global.LOG_FILE = '/var/log/mi-script.log'  // Solo Node.js
 */

'use strict'

// Cargar colors.js si no está cargado (intento simple, sin import real)
// En mongosh y Node.js se espera que colors.js se cargue antes
let activeColors = {}
let COLOR_RESET = ''
let COLOR_BRIGHT_BLACK = ''
let COLOR_BRIGHT_BLUE = ''
let COLOR_BRIGHT_GREEN = ''
let COLOR_BRIGHT_YELLOW = ''
let COLOR_BRIGHT_RED = ''
let COLOR_BRIGHT_WHITE = ''
let COLOR_BRIGHT_CYAN = ''
let COLOR_CYAN = ''

// Intentar obtener colores si están disponibles
if (typeof global !== 'undefined') {
  if (global.COLOR_RESET) {
    COLOR_RESET = global.COLOR_RESET
    COLOR_BRIGHT_BLACK = global.COLOR_BRIGHT_BLACK || ''
    COLOR_BRIGHT_BLUE = global.COLOR_BRIGHT_BLUE || ''
    COLOR_BRIGHT_GREEN = global.COLOR_BRIGHT_GREEN || ''
    COLOR_BRIGHT_YELLOW = global.COLOR_BRIGHT_YELLOW || ''
    COLOR_BRIGHT_RED = global.COLOR_BRIGHT_RED || ''
    COLOR_BRIGHT_WHITE = global.COLOR_BRIGHT_WHITE || ''
    COLOR_BRIGHT_CYAN = global.COLOR_BRIGHT_CYAN || ''
    COLOR_CYAN = global.COLOR_CYAN || ''
    activeColors = global.colors || {}
  }
}

// ============================================================================
// CONFIGURACIÓN DEL SISTEMA DE LOGGING
// ============================================================================

// Nivel de logging (DEBUG, INFO, SUCCESS, WARN, ERROR)
const LOG_LEVEL = (typeof global !== 'undefined' && global.LOG_LEVEL) || 'INFO'

// Control de verbosidad general
const VERBOSE = (typeof global !== 'undefined' && global.VERBOSE !== undefined)
  ? global.VERBOSE
  : true

// Habilitar timestamps en los logs
const LOG_TIMESTAMP = (typeof global !== 'undefined' && global.LOG_TIMESTAMP)
  ? global.LOG_TIMESTAMP
  : false

// Archivo de log (opcional, solo Node.js)
const LOG_FILE = (typeof global !== 'undefined' && global.LOG_FILE)
  ? global.LOG_FILE
  : null

// Indentación base
const LOG_INDENT = (typeof global !== 'undefined' && global.LOG_INDENT) || ''

// Prefijos para cada nivel
const LOG_PREFIX_DEBUG = '[DEBUG]'
const LOG_PREFIX_INFO = '[INFO]'
const LOG_PREFIX_SUCCESS = '[SUCCESS]'
const LOG_PREFIX_WARN = '[WARN]'
const LOG_PREFIX_ERROR = '[ERROR]'
const LOG_PREFIX_NOTE = '[NOTE]'
const LOG_PREFIX_STEP = '[STEP]'

// Prioridades de niveles (mayor número = mayor prioridad)
const LOG_PRIORITY = {
  DEBUG: 0,
  INFO: 1,
  SUCCESS: 2,
  WARN: 3,
  ERROR: 4
}

// Prioridad actual basada en LOG_LEVEL
const LOG_CURRENT_PRIORITY = LOG_PRIORITY[LOG_LEVEL] || LOG_PRIORITY.INFO

// ============================================================================
// FUNCIONES HELPER INTERNAS
// ============================================================================

/**
 * Obtener timestamp en formato [YYYY-MM-DD HH:MM:SS]
 * @returns {string} Timestamp formateado o string vacío
 */
function getTimestamp() {
  if (!LOG_TIMESTAMP) {
    return ''
  }
  const now = new Date()
  const year = now.getFullYear()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const day = String(now.getDate()).padStart(2, '0')
  const hours = String(now.getHours()).padStart(2, '0')
  const minutes = String(now.getMinutes()).padStart(2, '0')
  const seconds = String(now.getSeconds()).padStart(2, '0')
  return `[${year}-${month}-${day} ${hours}:${minutes}:${seconds}]`
}

/**
 * Verificar si un nivel debe mostrarse
 * @param {string} level - Nivel a verificar
 * @returns {boolean} true si debe mostrarse
 */
function shouldLog(level) {
  if (!VERBOSE) {
    return false
  }
  const levelPriority = LOG_PRIORITY[level] || LOG_PRIORITY.INFO
  return levelPriority >= LOG_CURRENT_PRIORITY
}

/**
 * Obtener función de impresión para stdout
 * @returns {Function} Función para imprimir
 */
function getStdoutFunction() {
  if (typeof console !== 'undefined' && typeof console.log === 'function') {
    return console.log.bind(console)
  }
  if (typeof print === 'function') {
    return print
  }
  return () => {}
}

/**
 * Obtener función de impresión para stderr
 * @returns {Function} Función para imprimir
 */
function getStderrFunction() {
  if (typeof console !== 'undefined' && typeof console.error === 'function') {
    return console.error.bind(console)
  }
  if (typeof printError === 'function') {
    return printError
  }
  if (typeof print === 'function') {
    return print
  }
  return () => {}
}

/**
 * Escribir log a archivo (solo Node.js)
 * @param {string} line - Línea a escribir
 */
function writeToFile(line) {
  if (!LOG_FILE || typeof process === 'undefined') {
    return
  }
  try {
    const fs = require('fs')
    fs.appendFileSync(LOG_FILE, line + '\n', { encoding: 'utf8' })
  } catch (e) {
    // Silenciosamente fallar si no se puede escribir
  }
}

/**
 * Función interna para escribir log
 * @param {string} prefix - Prefijo del log
 * @param {string} color - Código de color
 * @param {string} message - Mensaje
 * @param {number} outputStream - 1=stdout, 2=stderr
 */
function writeLog(prefix, color, message, outputStream = 1) {
  const timestamp = getTimestamp()
  const outputLine = `${LOG_INDENT}${timestamp}${prefix} ${message}`
  let coloredOutput = outputLine

  // Formatear con colores si están disponibles
  if (color && COLOR_RESET) {
    const coloredPrefix = `${color}${prefix}${COLOR_RESET}`
    coloredOutput = `${LOG_INDENT}${timestamp}${coloredPrefix} ${message}`
  }

  // Escribir a stdout/stderr
  const outputFunc = outputStream === 2 ? getStderrFunction() : getStdoutFunction()
  outputFunc(coloredOutput)

  // Escribir a archivo (sin colores)
  if (LOG_FILE) {
    writeToFile(outputLine)
  }
}

// ============================================================================
// FUNCIONES DE LOGGING POR NIVEL
// ============================================================================

/**
 * Log DEBUG - Mensajes detallados para depuración
 * @param {...string} messages - Mensajes a loguear
 */
function log_debug(...messages) {
  if (shouldLog('DEBUG')) {
    writeLog(LOG_PREFIX_DEBUG, COLOR_BRIGHT_BLACK, messages.join(' '), 1)
  }
}

/**
 * Log INFO - Mensajes informativos generales
 * @param {...string} messages - Mensajes a loguear
 */
function log_info(...messages) {
  if (shouldLog('INFO')) {
    writeLog(LOG_PREFIX_INFO, COLOR_BRIGHT_BLUE, messages.join(' '), 1)
  }
}

/**
 * Log SUCCESS - Mensajes de éxito y operaciones completadas
 * @param {...string} messages - Mensajes a loguear
 */
function log_success(...messages) {
  if (shouldLog('SUCCESS')) {
    writeLog(LOG_PREFIX_SUCCESS, COLOR_BRIGHT_GREEN, messages.join(' '), 1)
  }
}

/**
 * Log WARN - Mensajes de advertencia
 * @param {...string} messages - Mensajes a loguear
 */
function log_warn(...messages) {
  if (VERBOSE) {
    writeLog(LOG_PREFIX_WARN, COLOR_BRIGHT_YELLOW, messages.join(' '), 2)
  }
}

/**
 * Log ERROR - Mensajes de error (siempre visibles si VERBOSE=true)
 * @param {...string} messages - Mensajes a loguear
 */
function log_error(...messages) {
  if (VERBOSE) {
    writeLog(LOG_PREFIX_ERROR, COLOR_BRIGHT_RED, messages.join(' '), 2)
  }
}

/**
 * Log NOTE - Notas y mensajes neutrales
 * @param {...string} messages - Mensajes a loguear
 */
function log_note(...messages) {
  if (shouldLog('INFO')) {
    writeLog(LOG_PREFIX_NOTE, COLOR_BRIGHT_WHITE, messages.join(' '), 1)
  }
}

/**
 * Log STEP - Pasos y secciones (formato especial)
 * @param {...string} messages - Mensajes a loguear
 */
function log_step(...messages) {
  if (shouldLog('INFO')) {
    writeLog(LOG_PREFIX_STEP, COLOR_BRIGHT_CYAN, messages.join(' '), 1)
  }
}

// ============================================================================
// FUNCIONES DE FORMATO ESPECIAL
// ============================================================================

/**
 * Separador visual para secciones
 */
function log_separator() {
  if (VERBOSE) {
    const separator = '='.repeat(80)
    const output = COLOR_BRIGHT_BLACK ? `${COLOR_BRIGHT_BLACK}${separator}${COLOR_RESET}` : separator
    getStdoutFunction()(output)
  }
}

/**
 * Título de sección
 * @param {string} title - Título de la sección
 */
function log_title(title = 'Sección') {
  if (VERBOSE) {
    const separator = '='.repeat(80)
    const stdout = getStdoutFunction()
    stdout('')
    if (COLOR_BRIGHT_CYAN) {
      stdout(`${COLOR_BRIGHT_CYAN}${separator}${COLOR_RESET}`)
      stdout(`${COLOR_BRIGHT_CYAN}${LOG_PREFIX_STEP} ${COLOR_BRIGHT_WHITE}${title}${COLOR_RESET}`)
      stdout(`${COLOR_BRIGHT_CYAN}${separator}${COLOR_RESET}`)
    } else {
      stdout(separator)
      stdout(`${LOG_PREFIX_STEP} ${title}`)
      stdout(separator)
    }
    stdout('')
  }
}

/**
 * Mensaje con formato de comando ejecutándose
 * @param {string} cmd - Comando a mostrar
 */
function log_cmd(cmd) {
  if (shouldLog('INFO')) {
    const output = COLOR_CYAN ? `> ${COLOR_CYAN}${cmd}${COLOR_RESET}` : `> ${cmd}`
    getStdoutFunction()(output)
  }
}

/**
 * Mensaje vacío (línea en blanco)
 */
function log_blank() {
  if (VERBOSE) {
    getStdoutFunction()('')
  }
}

// ============================================================================
// FUNCIONES DE UTILIDAD Y ERROR HANDLING
// ============================================================================

/**
 * Mostrar error y salir
 * @param {string} message - Mensaje de error
 * @param {number} exitCode - Código de salida (default: 1)
 */
function error_exit(message = 'Error desconocido', exitCode = 1) {
  log_error(message)
  if (typeof process !== 'undefined' && typeof process.exit === 'function') {
    process.exit(Number(exitCode) || 1)
  }
  throw new Error(message)
}

/**
 * Validar que un comando existe
 * @param {string} command - Nombre del comando
 */
function check_command(command) {
  const cmd = String(command || '')
  if (!cmd) {
    error_exit('check_command: se requiere el nombre del comando')
  }
  if (typeof process !== 'undefined' && typeof require !== 'undefined') {
    try {
      const { execSync } = require('child_process')
      execSync(`command -v ${cmd}`, { stdio: 'ignore' })
      return true
    } catch (e) {
      error_exit(`Comando '${cmd}' no encontrado. Por favor, instálalo primero.`)
    }
  }
  log_warn(`No se puede verificar el comando '${cmd}' en este entorno.`)
  return true
}

/**
 * Mostrar uso de un script
 * @param {string} scriptName - Nombre del script (opcional)
 * @param {string} usageText - Texto de uso (opcional)
 * @param {string|Array<string>} examples - Ejemplos (opcional)
 */
function usage(scriptName, usageText, examples) {
  log_error('Uso incorrecto')
  if (usageText) {
    log_info(`Uso: ${usageText}`)
  }
  if (examples) {
    log_info('Ejemplos:')
    const examplesArray = Array.isArray(examples) ? examples : [examples]
    const stderr = getStderrFunction()
    examplesArray.forEach((example) => {
      stderr(`  ${String(example)}`)
    })
  }
}

// ============================================================================
// ALIASES PARA COMPATIBILIDAD
// ============================================================================

const error = log_error
const warn = log_warn
const success = log_success
const info = log_info

// ============================================================================
// MOSTRAR CONFIGURACIÓN DEL LOGGER
// ============================================================================

/**
 * Mostrar configuración del logger
 */
function log_show_config() {
  log_info('=== Configuración del Sistema de Logging ===')
  log_info(`  Nivel de Log:    ${LOG_LEVEL}`)
  log_info(`  Verbose:         ${VERBOSE}`)
  log_info(`  Timestamps:      ${LOG_TIMESTAMP}`)
  log_info(`  Prioridad Actual: ${LOG_CURRENT_PRIORITY}`)
  if (LOG_FILE) {
    log_info(`  Archivo de Log:   ${LOG_FILE}`)
  }
}

// ============================================================================
// EXPORTACIÓN
// ============================================================================

// Exportar para Node.js (CommonJS)
if (typeof module !== 'undefined' && typeof module.exports !== 'undefined') {
  module.exports = {
    // Funciones de logging
    log_debug,
    log_info,
    log_success,
    log_warn,
    log_error,
    log_note,
    log_step,
    // Funciones de formato
    log_separator,
    log_title,
    log_cmd,
    log_blank,
    // Utilidades
    error_exit,
    check_command,
    usage,
    log_show_config,
    // Aliases
    error,
    warn,
    success,
    info
  }
}

// Exportar para mongosh (hacer disponible globalmente)
if (typeof global !== 'undefined') {
  global.log_debug = log_debug
  global.log_info = log_info
  global.log_success = log_success
  global.log_warn = log_warn
  global.log_error = log_error
  global.log_note = log_note
  global.log_step = log_step
  global.log_separator = log_separator
  global.log_title = log_title
  global.log_cmd = log_cmd
  global.log_blank = log_blank
  global.error_exit = error_exit
  global.check_command = check_command
  global.usage = usage
  global.log_show_config = log_show_config
  // Aliases
  global.error = error
  global.warn = warn
  global.success = success
  global.info = info
}
