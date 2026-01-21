# Scripts PowerShell (Alternativa para Windows)

⚠️ **ADVERTENCIA**: Estos scripts PowerShell son una **alternativa básica y limitada** para usuarios que no pueden usar WSL. **Se recomienda encarecidamente usar WSL** para funcionalidad completa.

---

## 📋 Scripts Disponibles

### `check-dependencies.ps1`
Verifica que Docker y Docker Compose estén instalados.

**Uso**:
```powershell
.\scripts\powershell\check-dependencies.ps1
```

### `validate.ps1`
Validación básica de configuración (archivo .env y variables requeridas).

**Uso**:
```powershell
.\scripts\powershell\validate.ps1
```

---

## ⚠️ Limitaciones

Estos scripts PowerShell tienen limitaciones significativas:

- ✅ Verificación básica de dependencias
- ✅ Validación básica de .env
- ❌ **No incluyen** todos los comandos de dev-toolbox
- ❌ **No incluyen** validaciones avanzadas (IPs, puertos, versiones, etc.)
- ❌ **No incluyen** comandos de backup, monitoreo, etc.
- ❌ **No incluyen** integración con Infisical
- ❌ **No incluyen** gestión completa de servicios Docker

---

## 🚀 Recomendación: Usar WSL

Para funcionalidad completa, **usa WSL (Windows Subsystem for Linux)**:

1. **Instalar WSL**:
   ```powershell
   wsl --install
   ```

2. **Instalar Docker Desktop** con integración WSL

3. **Usar dev-toolbox en WSL**:
   ```bash
   # En WSL
   make check-dependencies
   make validate
   make start
   # ... todos los comandos disponibles
   ```

📖 **Ver guía completa**: [docs/WSL_SETUP.md](../docs/WSL_SETUP.md)

---

## 🔧 Requisitos para Scripts PowerShell

- **PowerShell 5.1 o superior** (incluido en Windows 10/11)
- **Docker Desktop para Windows** instalado y corriendo
- **Permisos de ejecución**: Puede ser necesario cambiar política de ejecución:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

---

## 📝 Notas

- Estos scripts son **experimentales** y pueden no recibir actualizaciones frecuentes
- Para desarrollo activo, se recomienda usar WSL
- Los scripts PowerShell pueden tener bugs o incompatibilidades
- La funcionalidad completa solo está disponible en Linux/macOS/WSL

---

**¿Necesitas ayuda?** Consulta [docs/WSL_SETUP.md](../docs/WSL_SETUP.md) o abre un issue.
