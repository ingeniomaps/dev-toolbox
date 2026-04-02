# ============================================================================
# Script: check-dependencies.ps1
# Ubicación: scripts/powershell/
# ============================================================================
# Verifica prerrequisitos del sistema (Docker) en Windows.
# NOTA: Esta es una versión básica. Se recomienda usar WSL para funcionalidad completa.
#
# Uso:
#   .\scripts\powershell\check-dependencies.ps1
#
# Retorno:
#   0 si todas las dependencias están instaladas
#   1 si hay errores
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

Write-Host "`n=== Verificando Dependencias ===" -ForegroundColor Cyan
Write-Host ""

# Verificar Docker
Write-Info "Verificando Docker..."
try {
    $dockerVersion = docker --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker instalado: $dockerVersion"
    } else {
        throw "Docker no encontrado"
    }
} catch {
    Write-Error "Docker no está instalado"
    Write-Info "Instala Docker Desktop desde: https://docs.docker.com/desktop/install/windows-install/"
    Write-Host ""
    Write-Warn "RECOMENDACIÓN: Usa WSL (Windows Subsystem for Linux) para funcionalidad completa"
    Write-Info "Ver documentación: docs/WSL_SETUP.md"
    exit 1
}

# Verificar Docker daemon
Write-Info "Verificando Docker daemon..."
try {
    docker ps | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker daemon está corriendo"
    } else {
        throw "Docker daemon no responde"
    }
} catch {
    Write-Error "Docker daemon no está corriendo"
    Write-Info "Inicia Docker Desktop desde el menú de inicio"
    exit 1
}

# Verificar Docker Compose
Write-Info "Verificando Docker Compose..."
try {
    $composeVersion = docker compose version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker Compose V2: $composeVersion"
    } else {
        # Intentar V1
        $composeV1 = docker-compose --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker Compose V1: $composeV1"
        } else {
            throw "Docker Compose no encontrado"
        }
    }
} catch {
    Write-Error "Docker Compose no está instalado"
    Write-Info "Docker Compose está incluido en Docker Desktop"
    exit 1
}

Write-Host ""
Write-Success "Todas las dependencias están instaladas y funcionando"
Write-Host ""
Write-Warn "NOTA: Esta versión PowerShell es básica. Para funcionalidad completa, usa WSL."
Write-Info "Ver: docs/WSL_SETUP.md para configuración de WSL"

exit 0
