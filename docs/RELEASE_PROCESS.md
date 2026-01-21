# Proceso de Release

> Guía completa para realizar releases de dev-toolbox

---

## 📋 Tabla de Contenidos

- [Introducción](#introducción)
- [Proceso Automatizado](#proceso-automatizado)
- [Proceso Manual](#proceso-manual)
- [Generación de Release Notes](#generación-de-release-notes)
- [Publicación en GitHub](#publicación-en-github)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Introducción

El proceso de release en dev-toolbox está automatizado para asegurar consistencia y reducir errores. Un release incluye:

1. ✅ Ejecución de tests
2. ✅ Actualización de versión
3. ✅ Actualización de archivos relacionados (.version, .env, README.md, CHANGELOG.md)
4. ✅ Creación de tag de Git
5. ✅ Generación de release notes
6. ✅ Commit de cambios

---

## 🚀 Proceso Automatizado

### Comando Principal

```bash
make release PART=<major|minor|patch>
```

### Ejemplos

```bash
# Release patch (2.3.0 → 2.3.1)
make release PART=patch

# Release minor (2.3.0 → 2.4.0)
make release PART=minor

# Release major (2.3.0 → 3.0.0)
make release PART=major
```

### Opciones

```bash
# Simular release sin hacer cambios (dry-run)
make release PART=patch DRY_RUN=1

# Saltar tests (útil si ya se ejecutaron)
make release PART=patch SKIP_TESTS=1

# Combinar opciones
make release PART=minor DRY_RUN=1 SKIP_TESTS=1
```

### Qué Hace el Script

El script `release.sh` ejecuta los siguientes pasos en orden:

1. **Validación del repositorio**
   - Verifica que es un repositorio Git
   - Comprueba que estás en la rama correcta (main/master)
   - Advierte sobre cambios sin commitear

2. **Ejecución de tests**
   - Ejecuta todos los tests en `scripts/sh/tests/`
   - Si algún test falla, aborta el release
   - Puede saltarse con `--skip-tests` o `SKIP_TESTS=1`

3. **Verificación de calidad**
   - Ejecuta `check-code-quality.sh` si está disponible
   - No aborta el release si falla (solo warning)

4. **Actualización de versión**
   - Llama a `bump-version.sh` con `--no-tag --no-commit`
   - Actualiza `.version`, `.env`, `README.md`, `CHANGELOG.md`

5. **Generación de release notes**
   - Extrae la sección de la versión del `CHANGELOG.md`
   - Crea `RELEASE_NOTES_X.Y.Z.md`

6. **Creación de tag de Git**
   - Crea tag anotado: `vX.Y.Z`
   - Mensaje: "Release version X.Y.Z"

7. **Commit de cambios**
   - Hace commit de todos los archivos modificados
   - Mensaje: "chore: release version X.Y.Z"

---

## 📝 Proceso Manual

Si prefieres hacer el release manualmente o necesitas más control:

### Paso 1: Preparar Cambios

```bash
# Asegúrate de que todos los cambios están commiteados
git status

# Si hay cambios, haz commit
git add .
git commit -m "feat: nueva funcionalidad"
```

### Paso 2: Ejecutar Tests

```bash
# Ejecutar todos los tests
for test in scripts/sh/tests/test-*.sh; do
	bash "$test"
done

# O usar el script de release en modo test
bash scripts/sh/commands/release.sh patch --skip-tests --dry-run
```

### Paso 3: Actualizar Versión

```bash
# Bump version (sin tag ni commit)
make bump-version PART=patch SKIP_GIT_TAG=1 SKIP_GIT_COMMIT=1

# O manualmente
bash scripts/sh/commands/bump-version.sh patch --no-tag --no-commit
```

### Paso 4: Revisar Cambios

```bash
# Ver qué cambió
git diff

# Verificar que CHANGELOG.md está actualizado
cat CHANGELOG.md | head -50
```

### Paso 5: Generar Release Notes

```bash
# Generar release notes manualmente
bash scripts/sh/commands/release.sh patch --skip-tests --dry-run
# Esto generará RELEASE_NOTES_X.Y.Z.md

# O extraer del CHANGELOG manualmente
VERSION=$(cat .version)
awk "/^## \[${VERSION}\]/,/^## \[/" CHANGELOG.md | head -n -1 > "RELEASE_NOTES_${VERSION}.md"
```

### Paso 6: Crear Tag

```bash
VERSION=$(cat .version)
git tag -a "v${VERSION}" -m "Release version ${VERSION}"
```

### Paso 7: Commit y Push

```bash
# Commit de cambios
git add .version .env README.md CHANGELOG.md "RELEASE_NOTES_${VERSION}.md"
git commit -m "chore: release version ${VERSION}"

# Push commits y tags
git push origin main
git push origin "v${VERSION}"
```

---

## 📄 Generación de Release Notes

### Automática

El script `release.sh` genera automáticamente `RELEASE_NOTES_X.Y.Z.md` desde el `CHANGELOG.md`.

**Formato generado**:
```markdown
# Release Notes - v2.3.0

2025-01-27

---

## [2.3.0] - 2025-01-27

### Added
- Nueva funcionalidad 1
- Nueva funcionalidad 2

### Changed
- Mejora en X

...

---

**Ver changelog completo**: [CHANGELOG.md](../CHANGELOG.md)
```

### Manual

Si necesitas generar release notes manualmente:

```bash
VERSION="2.3.0"
bash scripts/sh/commands/release.sh patch --skip-tests --dry-run
# Esto generará RELEASE_NOTES_${VERSION}.md
```

O extraer directamente del CHANGELOG:

```bash
VERSION="2.3.0"
awk "/^## \[${VERSION}\]/,/^## \[/" CHANGELOG.md | \
	head -n -1 | \
	sed '/^---$/d' > "RELEASE_NOTES_${VERSION}.md"
```

---

## 🐙 Publicación en GitHub

### Crear Release en GitHub

1. **Ir a Releases**
   - Ve a: `https://github.com/ingeniomaps/dev-toolbox/releases`
   - Click en "Draft a new release"

2. **Configurar Release**
   - **Tag**: Selecciona `v2.3.0` (el tag creado)
   - **Title**: `v2.3.0` o `Release v2.3.0`
   - **Description**: Copia el contenido de `RELEASE_NOTES_2.3.0.md`

3. **Publicar**
   - Click en "Publish release"

### Usando GitHub CLI (gh)

```bash
# Instalar GitHub CLI si no está instalado
# https://cli.github.com/

# Autenticarse
gh auth login

# Crear release desde release notes
VERSION=$(cat .version)
gh release create "v${VERSION}" \
	--title "Release v${VERSION}" \
	--notes-file "RELEASE_NOTES_${VERSION}.md"
```

### Automatización con GitHub Actions

Ver sección [Integración con GitHub Actions](#integración-con-github-actions).

---

## 🔧 Troubleshooting

### Problema: "Tests fallaron"

**Solución**:
```bash
# Ejecutar tests individualmente para ver qué falla
bash scripts/sh/tests/test-init.sh
bash scripts/sh/tests/test-services.sh

# Corregir problemas y volver a intentar
make release PART=patch
```

### Problema: "Tag ya existe"

**Solución**:
```bash
# Ver tags existentes
git tag -l

# Eliminar tag local (si es necesario)
git tag -d v2.3.0

# Eliminar tag remoto (si es necesario)
git push origin --delete v2.3.0

# Volver a intentar
make release PART=patch
```

### Problema: "Hay cambios sin commitear"

**Solución**:
```bash
# Ver cambios
git status

# Opción 1: Hacer commit
git add .
git commit -m "feat: cambios antes de release"

# Opción 2: Hacer stash
git stash

# Opción 3: Continuar de todas formas (el script solo advierte)
make release PART=patch
```

### Problema: "No se pudo actualizar CHANGELOG.md"

**Solución**:
```bash
# Actualizar manualmente
bash scripts/sh/utils/update-changelog.sh $(cat .version)

# O editar CHANGELOG.md manualmente
```

### Problema: "No es un repositorio Git"

**Solución**:
```bash
# Inicializar repositorio
git init
git add .
git commit -m "Initial commit"

# O trabajar desde un repositorio Git válido
```

---

## 🔄 Integración con GitHub Actions

### Workflow de Release Automático

Crea `.github/workflows/release.yml`:

```yaml
name: Release

on:
  workflow_dispatch:
    inputs:
      version_part:
        description: 'Parte a incrementar'
        required: true
        type: choice
        options:
          - patch
          - minor
          - major
  push:
    tags:
      - 'v*'

jobs:
  release:
    name: Crear Release
    runs-on: ubuntu-latest
    if: github.event_name == 'workflow_dispatch'
    
    steps:
      - name: Checkout código
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Configurar Git
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
      
      - name: Ejecutar release
        env:
          SKIP_TESTS: 0
        run: |
          make release PART=${{ github.event.inputs.version_part }}
      
      - name: Publicar tag
        run: |
          VERSION=$(cat .version)
          git push origin "v${VERSION}"
          git push origin main
      
      - name: Crear GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            RELEASE_NOTES_*.md
          body_path: RELEASE_NOTES_*.md
          draft: false
          prerelease: false
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  publish-release:
    name: Publicar Release desde Tag
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')
    
    steps:
      - name: Checkout código
        uses: actions/checkout@v4
        with:
          ref: ${{ github.ref }}
      
      - name: Extraer versión del tag
        id: version
        run: |
          VERSION=${GITHUB_REF#refs/tags/v}
          echo "version=$VERSION" >> $GITHUB_OUTPUT
      
      - name: Generar release notes
        run: |
          VERSION=${{ steps.version.outputs.version }}
          awk "/^## \[${VERSION}\]/,/^## \[/" CHANGELOG.md | \
            head -n -1 | \
            sed '/^---$/d' > RELEASE_NOTES.md
      
      - name: Crear GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            RELEASE_NOTES.md
          body_path: RELEASE_NOTES.md
          draft: false
          prerelease: false
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Uso del Workflow

1. **Release Manual desde GitHub**:
   - Ve a "Actions" → "Release"
   - Click en "Run workflow"
   - Selecciona `patch`, `minor` o `major`
   - Click en "Run workflow"

2. **Release Automático al Push Tag**:
   - Crea tag localmente: `git tag v2.3.0`
   - Push tag: `git push origin v2.3.0`
   - El workflow creará el release automáticamente

---

## ✅ Checklist de Release

Antes de hacer un release, verifica:

- [ ] Todos los cambios están commiteados
- [ ] Tests pasan: `bash scripts/sh/tests/test-*.sh`
- [ ] CHANGELOG.md está actualizado con cambios de [Unreleased]
- [ ] README.md está actualizado si hay cambios importantes
- [ ] Documentación está actualizada
- [ ] Estás en la rama correcta (main/master)
- [ ] No hay cambios sin commitear (o están intencionalmente)
- [ ] Versión a liberar es correcta (revisa .version)

---

## 📚 Recursos

- [CHANGELOG.md](../CHANGELOG.md) - Historial de cambios
- [CONTRIBUTING.md](../CONTRIBUTING.md) - Guía de contribución
- [Semantic Versioning](https://semver.org/lang/es/) - Especificación de versionado semántico
- [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/) - Formato de changelog

---

*Última actualización: 2025-01-27*
