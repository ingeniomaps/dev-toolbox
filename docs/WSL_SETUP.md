# Guía de Configuración en WSL (Windows Subsystem for Linux)

Esta guía explica cómo usar `dev-toolbox` en Windows usando WSL (Windows Subsystem for Linux).

---

## 📋 Requisitos Previos

### Opción 1: WSL 2 (Recomendado)

1. **Verificar requisitos de Windows**:
   - Windows 10 versión 2004 o superior (Build 19041 o superior)
   - Windows 11
   - Habilitar características necesarias

2. **Instalar WSL**:
   ```powershell
   # Abre PowerShell como Administrador
   wsl --install
   ```

   Este comando instala WSL 2 con Ubuntu por defecto. Si prefieres otra distribución:
   ```powershell
   wsl --list --online    # Ver distribuciones disponibles
   wsl --install -d Ubuntu-22.04
   ```

3. **Reiniciar Windows** cuando se solicite

4. **Configurar usuario de WSL**:
   - Al abrir WSL por primera vez, te pedirá crear un usuario y contraseña
   - Este usuario será el administrador de WSL (puede usar `sudo`)

### Opción 2: Instalación Manual (si wsl --install no funciona)

1. **Habilitar características de Windows**:
   ```powershell
   # PowerShell como Administrador
   dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
   dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
   ```

2. **Reiniciar Windows**

3. **Descargar e instalar WSL 2 Kernel Update**:
   - Descarga desde: https://aka.ms/wsl2kernel
   - Ejecuta el instalador

4. **Establecer WSL 2 como versión por defecto**:
   ```powershell
   wsl --set-default-version 2
   ```

5. **Instalar distribución Linux**:
   - Abre Microsoft Store
   - Busca "Ubuntu" o tu distribución preferida
   - Haz clic en "Instalar"

---

## 🐳 Instalación de Docker en WSL

### Opción 1: Docker Desktop para Windows (Recomendado)

1. **Instalar Docker Desktop**:
   - Descarga desde: https://docs.docker.com/desktop/install/windows-install/
   - Instala Docker Desktop
   - Durante la instalación, habilita "Use WSL 2 based engine"

2. **Configurar integración con WSL**:
   - Abre Docker Desktop
   - Ve a Settings > Resources > WSL Integration
   - Habilita la integración con tu distribución WSL
   - Haz clic en "Apply & Restart"

3. **Verificar instalación**:
   ```bash
   # En WSL
   docker --version
   docker ps
   ```

### Opción 2: Docker Engine en WSL (Alternativa)

Si prefieres instalar Docker Engine directamente en WSL:

```bash
# Actualizar paquetes
sudo apt update

# Instalar dependencias
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Agregar clave GPG de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Agregar repositorio de Docker
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Agregar usuario al grupo docker (para no usar sudo)
sudo usermod -aG docker $USER

# Reiniciar sesión de WSL
exit
# Vuelve a abrir WSL

# Verificar instalación
docker --version
docker ps
```

---

## 📦 Instalación de dev-toolbox en WSL

### 1. Clonar el Repositorio

```bash
# En WSL
cd ~
git clone https://github.com/ingeniomaps/dev-toolbox.git
cd dev-toolbox
```

### 2. Instalar Dependencias

```bash
# Verificar dependencias
make check-dependencies
```

Si falta algo:
```bash
# Actualizar paquetes
sudo apt update

# Instalar Git (si no está instalado)
sudo apt install -y git

# Instalar Make
sudo apt install -y make

# Instalar otras herramientas útiles
sudo apt install -y curl jq
```

### 3. Configurar el Proyecto

```bash
# Crear archivo .env desde plantilla
make init-env

# Configurar y validar entorno
make setup-env
```

---

## 🔧 Configuración de Rutas

### Acceso a Archivos de Windows desde WSL

Los archivos de Windows están disponibles en `/mnt/`:

```bash
# Acceder a disco C:
cd /mnt/c/

# Acceder a disco D:
cd /mnt/d/

# Acceder a carpeta de usuario de Windows
cd /mnt/c/Users/TuUsuario/Documents
```

### Recomendaciones

1. **Trabaja dentro de WSL**: Evita editar archivos del proyecto desde Windows mientras trabajas en WSL
2. **Usa rutas de WSL**: Los proyectos deben estar en el sistema de archivos de WSL (`~`, `/home/usuario/`)
3. **Rendimiento**: El sistema de archivos de WSL es más rápido que `/mnt/` para operaciones de I/O

---

## 🚀 Uso Básico

Todos los comandos funcionan igual que en Linux:

```bash
# Validar configuración
make validate

# Iniciar servicios
make start

# Ver logs
make aggregate-logs

# Backup
make backup-all

# Ver ayuda
make help-toolbox
```

---

## ⚠️ Problemas Comunes

### Docker no está disponible en WSL

**Síntoma**: `docker: command not found` o `Cannot connect to the Docker daemon`

**Soluciones**:

1. **Si usas Docker Desktop**:
   - Verifica que Docker Desktop esté corriendo en Windows
   - Verifica la integración WSL en Docker Desktop (Settings > Resources > WSL Integration)
   - Reinicia WSL: `wsl --shutdown` en PowerShell, luego vuelve a abrir WSL

2. **Si usas Docker Engine en WSL**:
   - Inicia el servicio Docker: `sudo service docker start`
   - Verifica permisos: `sudo usermod -aG docker $USER` (luego reinicia sesión)

### Problemas con Permisos

**Síntoma**: `Permission denied` al ejecutar comandos Docker

**Solución**:
```bash
# Agregar usuario al grupo docker
sudo usermod -aG docker $USER

# Reiniciar sesión de WSL
exit
# Vuelve a abrir WSL
```

### Rutas de Windows no Funcionan

**Síntoma**: Errores al acceder a archivos en `/mnt/`

**Solución**: Mueve el proyecto al sistema de archivos de WSL:
```bash
# Copiar desde Windows a WSL
cp -r /mnt/c/ruta/al/proyecto ~/proyecto
cd ~/proyecto
```

### WSL es Lento

**Soluciones**:

1. **Usa WSL 2** (más rápido que WSL 1):
   ```powershell
   wsl --set-version Ubuntu-22.04 2
   ```

2. **Mueve proyectos a WSL**: Evita trabajar en `/mnt/`

3. **Optimiza Docker Desktop**: Ajusta recursos en Settings > Resources

---

## 🔗 Enlaces Útiles

- **Documentación oficial de WSL**: https://docs.microsoft.com/en-us/windows/wsl/
- **Docker Desktop para Windows**: https://docs.docker.com/desktop/windows/
- **WSL 2 Installation Guide**: https://docs.microsoft.com/en-us/windows/wsl/install
- **Troubleshooting WSL**: https://docs.microsoft.com/en-us/windows/wsl/troubleshooting

---

## 📝 Notas Adicionales

### Editor de Código

Puedes usar VS Code con extensión WSL:

1. Instala "Remote - WSL" en VS Code
2. Abre la carpeta del proyecto desde WSL: `code .` (dentro de WSL)
3. VS Code se conectará a WSL y usará el entorno Linux

### Git en WSL

Git funciona igual que en Linux:
```bash
git config --global user.name "Tu Nombre"
git config --global user.email "tu@email.com"
```

### Acceso a Puerto de WSL desde Windows

Los puertos expuestos en WSL son accesibles desde Windows usando `localhost`:
- Puerto 8080 en WSL → `http://localhost:8080` en Windows

---

**¿Necesitas ayuda?** Abre un issue en el repositorio de dev-toolbox.
