# ============================================================================
# Script: validate.ps1
# Ubicación: scripts/powershell/
# ============================================================================
# Valida la configuración básica del proyecto en Windows.
# NOTA: Versión limitada. Se recomienda usar WSL para validación completa.
#
# Uso:
#   .\scripts\powershell\validate.ps1
#
# Retorno:
#   0 si la validación es exitosa
#   1 si hay problemas
# ============================================================================

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

Write-Host "`n=== Validación de Configuración ===" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = if ($env:PROJECT_ROOT) { $env:PROJECT_ROOT } else { Get-Location }
$EnvFile = Join-Path $ProjectRoot ".env"

# Verificar .env
Write-Info "Verificando archivo .env..."
if (Test-Path $EnvFile) {
    Write-Success "Archivo .env encontrado: $EnvFile"
} else {
    Write-Error "Archivo .env no encontrado"
    Write-Info "Ejecuta: make init-env (en WSL) o crea .env manualmente"
    exit 1
}

# Verificar variables requeridas
Write-Info "Verificando variables requeridas..."
$requiredVars = @("NETWORK_NAME", "NETWORK_IP")
$missingVars = @()

foreach ($var in $requiredVars) {
    $content = Get-Content $EnvFile -Raw
    if ($content -match "^${var}=") {
        Write-Success "Variable $var encontrada"
    } else {
        $missingVars += $var
        Write-Error "Variable $var no encontrada"
    }
}

if ($missingVars.Count -gt 0) {
    Write-Host ""
    Write-Error "Variables faltantes: $($missingVars -join ', ')"
    exit 1
}

Write-Host ""
Write-Warn "NOTA: Esta es una validación básica. Para validación completa, usa WSL."
Write-Info "Ejecuta en WSL: make validate"
Write-Info "Ver: docs/WSL_SETUP.md"

Write-Host ""
Write-Success "Validación básica completada"

exit 0
