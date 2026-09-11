#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ERRORS=0
TESTS=0

echo
echo "======================================"
echo " Homelab Infrastructure Validation"
echo "======================================"
echo

success() {
    echo "✓ $1"
}

failure() {
    echo "✗ $1"
    ERRORS=$((ERRORS + 1))
}

test_started() {
    TESTS=$((TESTS + 1))
}

cd "$ROOT_DIR" || exit 1


# --------------------------------------------------
# 1. Verificar arquivos sensíveis
# --------------------------------------------------

echo "[1/5] Verificando arquivos sensíveis..."

test_started

SENSITIVE_FILES=$(
    find . \
        -path './.git' -prune -o \
        -type f \( \
            -name ".env" -o \
            -name "*.key" -o \
            -name "*.pem" -o \
            -name "*.p12" -o \
            -name "*.pfx" -o \
            -name "id_rsa" -o \
            -name "id_rsa.*" -o \
            -name "id_ed25519" -o \
            -name "id_ed25519.*" \
        \) \
        -print
)

if [ -z "$SENSITIVE_FILES" ]; then
    success "Nenhum arquivo sensível encontrado"
else
    failure "Arquivos sensíveis encontrados:"
    echo "$SENSITIVE_FILES"
fi

echo


# --------------------------------------------------
# 2. Verificar possíveis secrets
# --------------------------------------------------

echo "[2/5] Procurando possíveis secrets..."

test_started

SECRET_RESULTS=$(
    find . \
        -path './.git' -prune -o \
        -type f \
        ! -name '*.md' \
        ! -name '.env.example' \
        ! -name '.gitignore' \
        ! -name 'validate.sh' \
        -print0 |
    xargs -0 -r grep -niE \
        'password|passwd|secret|token|api[_-]?key|app[_-]?key|private[_-]?key|credential|base64:' \
        2>/dev/null || true
)

REAL_SECRETS=""

while IFS= read -r line; do

    [ -z "$line" ] && continue

    # Ignora variáveis de ambiente, por exemplo:
    # ${BESZEL_AGENT_TOKEN}
    if echo "$line" | grep -qE '\$\{[A-Za-z_][A-Za-z0-9_]*\}'; then
        continue
    fi

    REAL_SECRETS+="$line"$'\n'

done <<< "$SECRET_RESULTS"

if [ -z "$REAL_SECRETS" ]; then
    success "Nenhum secret evidente encontrado"
else
    failure "Possíveis secrets encontrados:"
    printf "%s" "$REAL_SECRETS"
fi

echo


# --------------------------------------------------
# 3. Validar Docker Compose
# --------------------------------------------------

echo "[3/5] Validando Docker Compose..."

while IFS= read -r compose; do

    test_started

    echo "  → $compose"

    if docker compose \
        --env-file "$ROOT_DIR/.env.example" \
        -f "$compose" \
        config --quiet \
        >/dev/null 2>&1; then

        success "$compose"

    else

        failure "$compose"

        docker compose \
            --env-file "$ROOT_DIR/.env.example" \
            -f "$compose" \
            config 2>&1 | sed 's/^/      /'
    fi

done < <(
    find "$ROOT_DIR/docker" \
        -type f \
        \( -name "compose.yml" -o -name "docker-compose.yml" \) \
        | sort
)

echo


# --------------------------------------------------
# 4. Validar Caddy
# --------------------------------------------------

echo "[4/5] Validando Caddyfile..."

test_started

if docker run --rm \
    -v "$ROOT_DIR/caddy/Caddyfile:/etc/caddy/Caddyfile:ro" \
    caddy:latest \
    caddy validate \
    --config /etc/caddy/Caddyfile \
    >/dev/null 2>&1; then

    success "Caddyfile válido"

else

    failure "Caddyfile inválido"

    docker run --rm \
        -v "$ROOT_DIR/caddy/Caddyfile:/etc/caddy/Caddyfile:ro" \
        caddy:latest \
        caddy validate \
        --config /etc/caddy/Caddyfile
fi

echo


# --------------------------------------------------
# 5. Verificar estrutura do projeto
# --------------------------------------------------

echo "[5/5] Verificando estrutura..."

REQUIRED_PATHS=(
    "README.md"
    ".gitignore"
    ".env.example"
    "docker"
    "caddy"
    "homepage"
    "scripts"
    "docs"
)

for item in "${REQUIRED_PATHS[@]}"; do

    test_started

    if [ -e "$ROOT_DIR/$item" ]; then
        success "$item"
    else
        failure "$item não encontrado"
    fi

done


# --------------------------------------------------
# Resultado
# --------------------------------------------------

echo
echo "======================================"
echo " Resultado"
echo "======================================"
echo

echo "Testes executados: $TESTS"
echo "Erros encontrados: $ERRORS"
echo

if [ "$ERRORS" -eq 0 ]; then

    echo "✓ INFRAESTRUTURA VALIDADA"
    echo
    exit 0

else

    echo "✗ VALIDAÇÃO FALHOU"
    echo
    exit 1

fi
