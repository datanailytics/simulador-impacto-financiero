#!/bin/bash
# Scripts de automatización para mantenimiento del repositorio
# Directorio: scripts/

# Script principal de setup del proyecto
# scripts/setup.sh

#!/bin/bash
set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de utilidad
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar si comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función principal de setup
main() {
    log_info "Iniciando configuración del Simulador Predictivo de Impacto Financiero"
    echo "================================================================="
    
    # Verificar prerequisitos del sistema
    check_prerequisites
    
    # Configurar entorno Python
    setup_python_environment
    
    # Instalar dependencias
    install_dependencies
    
    # Configurar archivos de configuración
    setup_configuration_files
    
    # Crear estructura de directorios
    create_directory_structure
    
    # Configurar pre-commit hooks
    setup_pre_commit_hooks
    
    # Configurar base de datos (si aplicable)
    setup_database
    
    # Ejecutar pruebas iniciales
    run_initial_tests
    
    # Mostrar resumen final
    show_setup_summary
}

check_prerequisites() {
    log_info "Verificando prerequisitos del sistema..."
    
    local missing_deps=()
    
    # Verificar Python
    if ! command_exists python3; then
        missing_deps+=("python3")
    else
        python_version=$(python3 --version | cut -d' ' -f2)
        log_success "Python encontrado: $python_version"
        
        # Verificar versión mínima (3.8)
        if ! python3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)"; then
            log_error "Python 3.8+ requerido. Versión actual: $python_version"
            exit 1
        fi
    fi
    
    # Verificar pip
    if ! command_exists pip3; then
        missing_deps+=("python3-pip")
    else
        log_success "pip encontrado: $(pip3 --version)"
    fi
    
    # Verificar git
    if ! command_exists git; then
        missing_deps+=("git")
    else
        log_success "Git encontrado: $(git --version)"
    fi
    
    # Verificar Node.js (opcional para interface web)
    if command_exists node; then
        log_success "Node.js encontrado: $(node --version)"
    else
        log_warning "Node.js no encontrado. Interface web no estará disponible."
    fi
    
    # Reportar dependencias faltantes
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Dependencias faltantes: ${missing_deps[*]}"
        log_info "En Ubuntu/Debian: sudo apt install ${missing_deps[*]}"
        log_info "En macOS: brew install ${missing_deps[*]}"
        exit 1
    fi
    
    log_success "Todos los prerequisitos verificados correctamente"
}

setup_python_environment() {
    log_info "Configurando entorno virtual de Python..."
    
    # Crear entorno virtual si no existe
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        log_success "Entorno virtual creado"
    else
        log_info "Entorno virtual ya existe"
    fi
    
    # Activar entorno virtual
    source venv/bin/activate || {
        log_error "Error activando entorno virtual"
        exit 1
    }
    
    # Actualizar pip
    pip install --upgrade pip setuptools wheel
    log_success "Entorno Python configurado correctamente"
}

install_dependencies() {
    log_info "Instalando dependencias de Python..."
    
    # Verificar que requirements.txt existe
    if [ ! -f "requirements.txt" ]; then
        log_error "Archivo requirements.txt no encontrado"
        exit 1
    fi
    
    # Instalar dependencias principales
    pip install -r requirements.txt
    
    # Instalar dependencias de desarrollo
    if [ -f "requirements-dev.txt" ]; then
        pip install -r requirements-dev.txt
    fi
    
    log_success "Dependencias instaladas correctamente"
}

setup_configuration_files() {
    log_info "Configurando archivos de configuración..."
    
    # Crear directorio de configuración si no existe
    mkdir -p config
    
    # Copiar archivo de configuración de ejemplo si no existe
    if [ ! -f "config/financial_parameters.json" ]; then
        if [ -f "config/financial_parameters.json.example" ]; then
            cp config/financial_parameters.json.example config/financial_parameters.json
            log_success "Archivo de configuración creado desde ejemplo"
        else
            # Crear configuración básica
            cat > config/financial_parameters.json << 'EOF'
{
  "simulation_parameters": {
    "time_horizon": 5,
    "discount_rate": 0.10,
    "tax_rate": 0.25,
    "inflation_rate": 0.03
  },
  "risk_parameters": {
    "market_volatility": 0.15,
    "operational_risk": 0.10,
    "financial_risk": 0.08
  }
}
EOF
            log_success "Archivo de configuración básico creado"
        fi
    else
        log_info "Archivo de configuración ya existe"
    fi
    
    # Verificar configuración
    python3 -c "
import json
try:
    with open('config/financial_parameters.json', 'r') as f:
        config = json.load(f)
    print('✓ Configuración válida')
except Exception as e:
    print(f'✗ Error en configuración: {e}')
    exit(1)
"
    
    log_success "Configuración validada correctamente"
}

create_directory_structure() {
    log_info "Creando estructura de directorios..."
    
    # Directorios principales
    directories=(
        "data/raw"
        "data/processed"
        "data/examples"
        "reports"
        "logs"
        "cache"
        "exports"
        "backups"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        log_info "Directorio creado: $dir"
    done
    
    # Crear archivos .gitkeep para directorios vacíos
    for dir in "${directories[@]}"; do
        if [ ! -f "$dir/.gitkeep" ] && [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
            touch "$dir/.gitkeep"
        fi
    done
    
    log_success "Estructura de directorios configurada"
}

setup_pre_commit_hooks() {
    log_info "Configurando pre-commit hooks..."
    
    # Verificar si pre-commit está instalado
    if command_exists pre-commit; then
        # Crear archivo de configuración si no existe
        if [ ! -f ".pre-commit-config.yaml" ]; then
            cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: check-merge-conflict
      - id: check-added-large-files
        args: ['--maxkb=500']
  
  - repo: https://github.com/psf/black
    rev: 23.7.0
    hooks:
      - id: black
        language_version: python3
  
  - repo: https://github.com/pycqa/flake8
    rev: 6.0.0
    hooks:
      - id: flake8
        args: [--max-line-length=88]
  
  - repo: https://github.com/pycqa/isort
    rev: 5.12.0
    hooks:
      - id: isort
        args: ["--profile", "black"]
EOF
        fi
        
        # Instalar hooks
        pre-commit install
        log_success "Pre-commit hooks configurados"
    else
        log_warning "pre-commit no está instalado. Hooks no configurados."
    fi
}

setup_database() {
    log_info "Configurando base de datos (si aplicable)..."
    
    # Para este proyecto, la base de datos es opcional
    # Solo crear estructura si se especifica en configuración
    
    if [ -f "config/database.ini" ]; then
        log_info "Configuración de base de datos encontrada"
        # Aquí se podría configurar SQLite o PostgreSQL
    else
        log_info "No se requiere configuración de base de datos"
    fi
}

run_initial_tests() {
    log_info "Ejecutando pruebas iniciales..."
    
    # Crear configuración de prueba si no existe
    mkdir -p config
    if [ ! -f "config/financial_parameters.json" ]; then
        setup_configuration_files
    fi
    
    # Ejecutar test de importación
    python3 -c "
try:
    from src.core.financial_model import FinancialModel
    model = FinancialModel()
    print('✓ Importación del modelo exitosa')
except ImportError as e:
    print(f'✗ Error de importación: {e}')
    exit(1)
except Exception as e:
    print(f'✗ Error inicializando modelo: {e}')
    exit(1)
"
    
    # Ejecutar test básico si existe
    if [ -d "tests" ] && command_exists pytest; then
        pytest tests/ -x -q --tb=short || {
            log_warning "Algunas pruebas fallaron. Revisar configuración."
        }
    fi
    
    log_success "Pruebas iniciales completadas"
}

show_setup_summary() {
    log_success "Configuración completada exitosamente!"
    echo ""
    echo "================================================================="
    echo "                    RESUMEN DE CONFIGURACIÓN"
    echo "================================================================="
    echo ""
    echo "✓ Entorno Python configurado"
    echo "✓ Dependencias instaladas"
    echo "✓ Archivos de configuración creados"
    echo "✓ Estructura de directorios configurada"
    echo "✓ Pruebas iniciales ejecutadas"
    echo ""
    echo "PRÓXIMOS PASOS:"
    echo ""
    echo "1. Activar entorno virtual:"
    echo "   source venv/bin/activate"
    echo ""
    echo "2. Ejecutar ejemplo básico:"
    echo "   python examples/basic_simulation.py"
    echo ""
    echo "3. Iniciar interface web (opcional):"
    echo "   python -m http.server 8000 --directory web"
    echo ""
    echo "4. Ejecutar pruebas completas:"
    echo "   pytest tests/ -v"
    echo ""
    echo "5. Generar documentación:"
    echo "   cd docs && make html"
    echo ""
    echo "================================================================="
    echo "Para soporte: https://github.com/tu-usuario/simulador-impacto-financiero/issues"
    echo "================================================================="
}

# Verificar si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

---

# Script de validación del entorno
# scripts/validate_environment.sh

#!/bin/bash
set -euo pipefail

# Importar funciones de utilidad
source "$(dirname "$0")/setup.sh"

validate_environment() {
    log_info "Validando entorno de desarrollo..."
    
    local issues_found=0
    
    # Verificar entorno virtual
    if [[ "$VIRTUAL_ENV" == "" ]]; then
        log_error "Entorno virtual no activado"
        ((issues_found++))
    else
        log_success "Entorno virtual activo: $VIRTUAL_ENV"
    fi
    
    # Verificar dependencias críticas
    critical_packages=(
        "numpy"
        "pandas"
        "scipy"
        "matplotlib"
        "plotly"
    )
    
    for package in "${critical_packages[@]}"; do
        if python3 -c "import $package" 2>/dev/null; then
            version=$(python3 -c "import $package; print($package.__version__)")
            log_success "$package instalado: $version"
        else
            log_error "$package no encontrado"
            ((issues_found++))
        fi
    done
    
    # Verificar archivos de configuración
    config_files=(
        "config/financial_parameters.json"
        "requirements.txt"
        ".gitignore"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_success "Archivo encontrado: $file"
        else
            log_error "Archivo faltante: $file"
            ((issues_found++))
        fi
    done
    
    # Verificar estructura de directorios
    required_dirs=(
        "src/core"
        "src/data"
        "src/visualization"
        "tests"
        "docs"
        "examples"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_success "Directorio encontrado: $dir"
        else
            log_error "Directorio faltante: $dir"
            ((issues_found++))
        fi
    done
    
    # Verificar que el código puede importarse
    if python3 -c "from src.core.financial_model import FinancialModel" 2>/dev/null; then
        log_success "Modelo principal importable"
    else
        log_error "Error importando modelo principal"
        ((issues_found++))
    fi
    
    # Resumen final
    if [[ $issues_found -eq 0 ]]; then
        log_success "Entorno validado exitosamente. ¡Todo listo para desarrollo!"
        return 0
    else
        log_error "Se encontraron $issues_found problemas. Ejecutar scripts/setup.sh para resolver."
        return 1
    fi
}

# Ejecutar validación
validate_environment

---

# Script de limpieza del proyecto
# scripts/cleanup.sh

#!/bin/bash
set -euo pipefail

# Importar funciones de utilidad
source "$(dirname "$0")/setup.sh"

cleanup_project() {
    log_info "Iniciando limpieza del proyecto..."
    
    # Archivos y directorios a limpiar
    cleanup_patterns=(
        "__pycache__"
        "*.pyc"
        "*.pyo"
        "*.pyd"
        ".pytest_cache"
        ".coverage"
        "htmlcov"
        ".mypy_cache"
        "*.egg-info"
        "build"
        "dist"
        ".DS_Store"
        "Thumbs.db"
        "*.log"
        "logs/*.log"
        "cache/*"
        "exports/*"
        "reports/*.pdf"
        "reports/*.html"
    )
    
    for pattern in "${cleanup_patterns[@]}"; do
        if find . -name "$pattern" -type f -o -name "$pattern" -type d | grep -q .; then
            find . -name "$pattern" -type f -delete 2>/dev/null || true
            find . -name "$pattern" -type d -exec rm -rf {} + 2>/dev/null || true
            log_info "Limpiado: $pattern"
        fi
    done
    
    # Limpiar archivos temporales específicos
    temp_files=(
        "temp/*"
        "*.tmp"
        "*.bak"
        "*.swp"
        "*.swo"
        "*~"
    )
    
    for pattern in "${temp_files[@]}"; do
        find . -name "$pattern" -type f -delete 2>/dev/null || true
    done
    
    # Limpiar entorno virtual si se solicita
    if [[ "${1:-}" == "--full" ]]; then
        log_warning "Eliminando entorno virtual..."
        rm -rf venv/
        log_info "Entorno virtual eliminado"
    fi
    
    log_success "Limpieza completada"
}

# Mostrar ayuda si se solicita
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Uso: $0 [--full]"
    echo ""
    echo "Opciones:"
    echo "  --full    Eliminar también el entorno virtual"
    echo "  --help    Mostrar esta ayuda"
    exit 0
fi

# Ejecutar limpieza
cleanup_project "$@"

---

# Script de actualización del proyecto
# scripts/update.sh

#!/bin/bash
set -euo pipefail

# Importar funciones de utilidad
source "$(dirname "$0")/setup.sh"

update_project() {
    log_info "Actualizando proyecto..."
    
    # Verificar que estamos en un repositorio git
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "No se encuentra repositorio git"
        exit 1
    fi
    
    # Verificar cambios no committed
    if ! git diff-index --quiet HEAD --; then
        log_warning "Hay cambios sin commit. Considere commitear antes de actualizar."
        read -p "¿Continuar de todos modos? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Actualización cancelada"
            exit 0
        fi
    fi
    
    # Hacer pull de cambios
    log_info "Obteniendo últimos cambios..."
    git fetch origin
    
    current_branch=$(git branch --show-current)
    log_info "Rama actual: $current_branch"
    
    # Actualizar rama actual
    git pull origin "$current_branch"
    
    # Activar entorno virtual si existe
    if [[ -d "venv" ]]; then
        source venv/bin/activate
        log_info "Entorno virtual activado"
    fi
    
    # Actualizar dependencias
    if [[ -f "requirements.txt" ]]; then
        log_info "Actualizando dependencias..."
        pip install --upgrade -r requirements.txt
        
        # Verificar si hay nuevas dependencias
        pip check || {
            log_warning "Conflictos de dependencias detectados"
            log_info "Ejecute: pip install --upgrade --force-reinstall -r requirements.txt"
        }
    fi
    
    # Ejecutar migraciones si existen
    if [[ -f "scripts/migrate.sh" ]]; then
        log_info "Ejecutando migraciones..."
        bash scripts/migrate.sh
    fi
    
    # Actualizar documentación si es necesario
    if [[ -d "docs" ]] && command_exists sphinx-build; then
        log_info "Actualizando documentación..."
        cd docs && make html && cd ..
    fi
    
    # Ejecutar pruebas rápidas
    if command_exists pytest; then
        log_info "Ejecutando pruebas rápidas..."
        pytest tests/ --maxfail=5 -q || {
            log_warning "Algunas pruebas fallaron. Revisar cambios."
        }
    fi
    
    log_success "Proyecto actualizado exitosamente"
    
    # Mostrar resumen de cambios
    log_info "Resumen de cambios recientes:"
    git log --oneline -10
}

# Ejecutar actualización
update_project "$@"

---

# Script para generar release
# scripts/release.sh

#!/bin/bash
set -euo pipefail

# Importar funciones de utilidad
source "$(dirname "$0")/setup.sh"

generate_release() {
    local version_type="${1:-patch}"
    
    log_info "Generando release ($version_type)..."
    
    # Verificar que estamos en main/master
    current_branch=$(git branch --show-current)
    if [[ "$current_branch" != "main" ]] && [[ "$current_branch" != "master" ]]; then
        log_error "Release debe ejecutarse desde rama main/master"
        exit 1
    fi
    
    # Verificar que no hay cambios pendientes
    if ! git diff-index --quiet HEAD --; then
        log_error "Hay cambios sin commit. Commit antes de crear release."
        exit 1
    fi
    
    # Obtener última versión
    last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
    log_info "Última versión: $last_tag"
    
    # Calcular nueva versión
    if command_exists python3; then
        new_version=$(python3 << EOF
import re
import sys

def increment_version(version_str, version_type):
    # Remover 'v' si existe
    version = version_str.lstrip('v')
    
    # Parsear versión
    match = re.match(r'(\d+)\.(\d+)\.(\d+)', version)
    if not match:
        print("v1.0.0")
        return
    
    major, minor, patch = map(int, match.groups())
    
    if version_type == "major":
        major += 1
        minor = 0
        patch = 0
    elif version_type == "minor":
        minor += 1
        patch = 0
    else:  # patch
        patch += 1
    
    print(f"v{major}.{minor}.{patch}")

increment_version("$last_tag", "$version_type")
EOF
)
    else
        log_error "Python3 requerido para cálculo de versión"
        exit 1
    fi
    
    log_info "Nueva versión: $new_version"
    
    # Confirmar con usuario
    read -p "¿Crear release $new_version? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Release cancelado"
        exit 0
    fi
    
    # Actualizar archivos de versión
    update_version_files "$new_version"
    
    # Ejecutar pruebas completas
    log_info "Ejecutando pruebas completas..."
    if command_exists pytest; then
        pytest tests/ -v || {
            log_error "Pruebas fallaron. No se puede crear release."
            exit 1
        }
    fi
    
    # Generar changelog
    generate_changelog "$last_tag" "$new_version"
    
    # Commit cambios de versión
    git add .
    git commit -m "Bump version to $new_version" || true
    
    # Crear tag
    git tag -a "$new_version" -m "Release $new_version"
    
    # Push cambios y tag
    git push origin "$current_branch"
    git push origin "$new_version"
    
    log_success "Release $new_version creado exitosamente"
    log_info "GitHub Actions creará automáticamente el release en GitHub"
}

update_version_files() {
    local version="$1"
    local version_number="${version#v}"
    
    # Actualizar README
    if [[ -f "README.md" ]]; then
        sed -i.bak "s/\*\*Versión actual\*\*: .*/\*\*Versión actual\*\*: $version_number/" README.md
        rm README.md.bak 2>/dev/null || true
    fi
    
    # Actualizar configuración
    if [[ -f "config/financial_parameters.json" ]]; then
        python3 << EOF
import json
try:
    with open('config/financial_parameters.json', 'r') as f:
        config = json.load(f)
    config['version'] = '$version_number'
    config['release_date'] = '$(date -I)'
    with open('config/financial_parameters.json', 'w') as f:
        json.dump(config, f, indent=2)
    print("✓ Configuración actualizada")
except Exception as e:
    print(f"✗ Error actualizando configuración: {e}")
EOF
    fi
}

generate_changelog() {
    local last_tag="$1"
    local new_version="$2"
    
    log_info "Generando changelog..."
    
    # Crear archivo changelog si no existe
    if [[ ! -f "CHANGELOG.md" ]]; then
        cat > CHANGELOG.md << 'EOF'
# Changelog

Todos los cambios notables de este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto se adhiere a [Versionado Semántico](https://semver.org/lang/es/).

EOF
    fi
    
    # Generar changelog para esta versión
    {
        echo "## [$new_version] - $(date -I)"
        echo ""
        echo "### Agregado"
        git log "$last_tag"..HEAD --pretty=format:"- %s" --grep="^feat:" --grep="^add:" | sed 's/^feat: //' | sed 's/^add: //' || true
        echo ""
        echo "### Corregido"
        git log "$last_tag"..HEAD --pretty=format:"- %s" --grep="^fix:" --grep="^bug:" | sed 's/^fix: //' | sed 's/^bug: //' || true
        echo ""
        echo "### Cambiado"
        git log "$last_tag"..HEAD --pretty=format:"- %s" --grep="^change:" --grep="^update:" | sed 's/^change: //' | sed 's/^update: //' || true
        echo ""
    } > temp_changelog.md
    
    # Insertar nuevo changelog al principio del archivo existente
    {
        head -6 CHANGELOG.md
        cat temp_changelog.md
        tail -n +7 CHANGELOG.md
    } > new_changelog.md
    
    mv new_changelog.md CHANGELOG.md
    rm temp_changelog.md
    
    log_success "Changelog actualizado"
}

# Verificar argumentos
if [[ $# -gt 1 ]]; then
    echo "Uso: $0 [patch|minor|major]"
    exit 1
fi

# Ejecutar generación de release
generate_release "${1:-patch}"