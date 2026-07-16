#!/bin/sh
#
# Configura um ambiente virtual Python local ao projeto.
# Compatível com bash, zsh, dash e outros shells POSIX.
#
# Deve ser carregado:
#
#   source ambiente.sh
#
# ou:
#
#   . ambiente.sh
#

###############################################################################
# Funções auxiliares
###############################################################################

erro()
{
    printf '%s\n' "ERRO: $*" >&2

    # Quando o script é carregado com source, return encerra somente o script.
    return 1 2>/dev/null || exit 1
}

comando_existe()
{
    command -v "$1" >/dev/null 2>&1
}

###############################################################################
# Diretórios do projeto
###############################################################################

PROJECT_HOME=$(pwd)
PATH_ENV="${PROJECT_HOME}/.env"
VIRTUAL_ENV="${PATH_ENV}/usr"

BUILD_HOME="${PROJECT_HOME}/build"
BUILD_BIN="${BUILD_HOME}/bin"
BUILD_LIB="${BUILD_HOME}/lib"
BUILD_CONF="${BUILD_HOME}/confs"
BUILD_TMP="${BUILD_HOME}/tmp"
BUILD_CACHE="${BUILD_HOME}/cache"
BUILD_DIST="${BUILD_HOME}/dist"
BUILD_COVERAGE="${BUILD_HOME}/coverage"
PYTHONPYCACHEPREFIX="${BUILD_CACHE}/pycache"

export PROJECT_HOME
export PATH_ENV
export VIRTUAL_ENV
export BUILD_HOME
export BUILD_BIN
export BUILD_LIB
export BUILD_CONF
export BUILD_TMP
export BUILD_CACHE
export BUILD_DIST
export BUILD_COVERAGE
export PYTHONPYCACHEPREFIX

###############################################################################
# Diretórios de build
###############################################################################

for diretorio in \
    "$BUILD_HOME" \
    "$BUILD_BIN" \
    "$BUILD_LIB" \
    "$BUILD_CONF" \
    "$BUILD_TMP" \
    "$BUILD_CACHE" \
    "$BUILD_DIST" \
    "$BUILD_COVERAGE" \
    "$PYTHONPYCACHEPREFIX"
do
    [ -d "$diretorio" ] || mkdir -p "$diretorio" ||
        erro "Falha ao criar diretório: ${diretorio}"
done

if [ "${1:-}" = "--make-vars" ]; then
    printf '%s\n' \
        "PROJECT_HOME := ${PROJECT_HOME}" \
        "PATH_ENV := ${PATH_ENV}" \
        "VIRTUAL_ENV := ${VIRTUAL_ENV}" \
        "BUILD_HOME := ${BUILD_HOME}" \
        "BUILD_BIN := ${BUILD_BIN}" \
        "BUILD_LIB := ${BUILD_LIB}" \
        "BUILD_CONF := ${BUILD_CONF}" \
        "BUILD_TMP := ${BUILD_TMP}" \
        "BUILD_CACHE := ${BUILD_CACHE}" \
        "BUILD_DIST := ${BUILD_DIST}" \
        "BUILD_COVERAGE := ${BUILD_COVERAGE}" \
        "PYTHONPYCACHEPREFIX := ${PYTHONPYCACHEPREFIX}"
    return 0 2>/dev/null || exit 0
fi

###############################################################################
# Identificação do gerenciador de pacotes
###############################################################################

PKG_MANAGER=""

if comando_existe apt-get; then
    PKG_MANAGER="apt"
elif comando_existe dnf; then
    PKG_MANAGER="dnf"
elif comando_existe yum; then
    PKG_MANAGER="yum"
fi

###############################################################################
# Instalação do Python, caso necessário
###############################################################################

tentativa=1
max_tentativas=2

while :; do
    python_ok=0
    pip_ok=0

    comando_existe python3 && python_ok=1
    comando_existe pip3 && pip_ok=1

    if [ "$python_ok" -eq 1 ] && [ "$pip_ok" -eq 1 ]; then
        break
    fi

    if [ "$tentativa" -gt "$max_tentativas" ]; then
        erro "Problemas com python3 ou pip3. Reveja a instalação."
    fi

    printf '%s\n' \
        "Python 3 ou pip3 não encontrados. Tentando instalar..."

    case "$PKG_MANAGER" in
        apt)
            sudo apt-get update ||
                erro "Falha ao atualizar os repositórios."

            sudo apt-get -y install \
                python3 \
                python3-pip \
                python3-venv ||
                erro "Falha ao instalar Python pelo apt."
            ;;

        dnf)
            sudo dnf -y install \
                python3 \
                python3-pip ||
                erro "Falha ao instalar Python pelo dnf."
            ;;

        yum)
            sudo yum -y install \
                python3 \
                python3-pip ||
                erro "Falha ao instalar Python pelo yum."
            ;;

        *)
            erro "Nenhum gerenciador de pacotes suportado foi encontrado."
            ;;
    esac

    tentativa=$((tentativa + 1))
done

###############################################################################
# Localização do Python
###############################################################################

PYTHON3=$(command -v python3) ||
    erro "Não foi possível localizar o executável python3."

###############################################################################
# Criação do ambiente virtual
###############################################################################

if [ ! -x "${VIRTUAL_ENV}/bin/python" ]; then
    printf '%s\n' \
        "Criando ambiente virtual em ${VIRTUAL_ENV}..."

    "$PYTHON3" -m venv "$VIRTUAL_ENV" ||
        erro "Falha ao criar o ambiente virtual."

    "${VIRTUAL_ENV}/bin/python" -m pip install --upgrade \
        pip \
        setuptools \
        wheel ||
        erro "Falha ao atualizar pip, setuptools e wheel."

    "${VIRTUAL_ENV}/bin/python" -m pip install ipython ||
        erro "Falha ao instalar o IPython."

    if [ -f "${PROJECT_HOME}/requirements.txt" ]; then
        printf '%s\n' \
            "Instalando dependências de requirements.txt..."

        "${VIRTUAL_ENV}/bin/python" -m pip install \
            -r "${PROJECT_HOME}/requirements.txt" ||
            erro "Falha ao instalar requirements.txt."
    fi
fi

###############################################################################
# Ativação do ambiente
###############################################################################

ACTIVATE="${VIRTUAL_ENV}/bin/activate"

if [ ! -f "$ACTIVATE" ]; then
    erro "Arquivo de ativação não encontrado: ${ACTIVATE}"
fi

# shellcheck disable=SC1090
. "$ACTIVATE"


###############################################################################
# Cria/atualiza o .gitignore
###############################################################################

GITIGNORE="${PROJECT_HOME}/.gitignore"

# Cria o arquivo se não existir
[ -f "$GITIGNORE" ] || : > "$GITIGNORE"

# Acrescenta apenas as entradas inexistentes
while IFS= read -r linha; do
    [ -z "$linha" ] && continue

    if ! grep -Fqx -- "$linha" "$GITIGNORE"; then
        printf '%s\n' "$linha" >> "$GITIGNORE"
    fi
done <<'EOF'
*.pyc
*.pyo
*.orig
*.bak
*.rej
*~
cur/
tmp/
.env/
.codex/
__pycache__/
*.DS_Store
*.project
*.dbeaver
*.pydevproject
*.settings
*.sqlite
*.sqlite-journal
src/logs
src/tmp
*.tar.bz2
build/
EOF

###############################################################################
# Confirmação
###############################################################################

export PATH=${BUILD_BIN}:${PATH_ENV}/bin:${VIRTUAL_ENV}/bin:${PATH}

printf '%s\n' \
    "Ambiente Python ativado:" \
    "  Projeto: ${PROJECT_HOME}" \
    "  Virtualenv: ${VIRTUAL_ENV}" \
    "  Build: ${BUILD_HOME}" \
    "  Python: $(command -v python)" \
    "  Versão: $(python --version 2>&1)"
