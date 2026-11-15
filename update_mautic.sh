#!/usr/bin/env bash
# ==============================================================================
# Script de Atualização e Deploy do Mautic Custom na VPS
# Repositório: https://github.com/WesllenMatias/mautic_custom.git
# Branch: 7.x
# ==============================================================================

set -eo pipefail

echo "=========================================================="
echo "       Iniciando Atualização do Mautic Custom na VPS      "
echo "=========================================================="

# 1. Identificar o diretório do Mautic
MAUTIC_DIR="${1:-}"

if [ -z "$MAUTIC_DIR" ]; then
    if [ -f "./index.php" ] && [ -d "./app" ] && [ -d "./plugins" ]; then
        MAUTIC_DIR="$(pwd)"
    elif [ -d "/var/www/html/mautic" ]; then
        MAUTIC_DIR="/var/www/html/mautic"
    elif [ -d "/var/www/mautic" ]; then
        MAUTIC_DIR="/var/www/mautic"
    elif [ -d "/var/www/html" ] && [ -f "/var/www/html/index.php" ] && [ -d "/var/www/html/app" ]; then
        MAUTIC_DIR="/var/www/html"
    else
        echo "[-] Erro: Não foi possível detectar o diretório do Mautic automaticamente."
        echo "    Uso: bash update_mautic.sh /caminho/do/mautic"
        exit 1
    fi
fi

echo "[+] Diretório do Mautic detectado: ${MAUTIC_DIR}"
cd "${MAUTIC_DIR}"

# 2. Detectar binário do PHP
PHP_BIN="php"
if command -v php8.2 >/dev/null 2>&1; then
    PHP_BIN="php8.2"
elif command -v php8.3 >/dev/null 2>&1; then
    PHP_BIN="php8.3"
fi
echo "[+] Utilizando PHP: $(${PHP_BIN} -v 2>/dev/null | head -n 1 || echo 'php')"

# 3. Detectar usuário do servidor web (www-data, nginx ou apache)
WEB_USER="www-data"
if id "www-data" >/dev/null 2>&1; then
    WEB_USER="www-data"
elif id "nginx" >/dev/null 2>&1; then
    WEB_USER="nginx"
elif id "apache" >/dev/null 2>&1; then
    WEB_USER="apache"
fi
echo "[+] Usuário Web detectado: ${WEB_USER}"

# 4. Atualizar código do projeto
echo "[+] Atualizando arquivos do repositório..."
if [ -d ".git" ]; then
    git config --global --add safe.directory "${MAUTIC_DIR}" || true
    echo "[+] Repositório Git detectado. Sincronizando com branch 7.x..."
    git fetch origin 7.x
    git checkout 7.x
    git pull origin 7.x
else
    echo "[!] Diretório não é um clone Git. Baixando versão atualizada do GitHub..."
    TMP_DIR="/tmp/mautic_update_$$"
    mkdir -p "${TMP_DIR}"
    curl -fsSL "https://github.com/WesllenMatias/mautic_custom/archive/refs/heads/7.x.tar.gz" -o "${TMP_DIR}/mautic.tar.gz"
    tar -xzf "${TMP_DIR}/mautic.tar.gz" -C "${TMP_DIR}"
    
    EXTRACTED_DIR="${TMP_DIR}/mautic_custom-7.x"
    if [ -d "${EXTRACTED_DIR}" ]; then
        echo "[+] Aplicando arquivos atualizados (preservando config/local.php e mídias)..."
        cp -r "${EXTRACTED_DIR}/app" "${MAUTIC_DIR}/"
        cp -r "${EXTRACTED_DIR}/plugins" "${MAUTIC_DIR}/"
        cp -r "${EXTRACTED_DIR}/themes" "${MAUTIC_DIR}/"
        cp -r "${EXTRACTED_DIR}/media" "${MAUTIC_DIR}/" 2>/dev/null || true
        [ -f "${EXTRACTED_DIR}/router.php" ] && cp "${EXTRACTED_DIR}/router.php" "${MAUTIC_DIR}/"
    fi
    rm -rf "${TMP_DIR}"
fi

# 5. Garantir que os assets do GrapesJS estão no lugar
if [ -f "${MAUTIC_DIR}/plugins/GrapesJsBuilderBundle/Assets/library/js/dist/manifest.json" ]; then
    echo "[+] Assets do GrapesJS verificados com sucesso (manifest.json presente)."
else
    echo "[!] Atenção: manifest.json do GrapesJS não encontrado em dist/."
fi

# 6. Limpar cache do Mautic
echo "[+] Limpando cache do Mautic..."
rm -rf var/cache/* 2>/dev/null || true

if [ -f "bin/console" ]; then
    ${PHP_BIN} bin/console cache:clear --no-interaction || true
    
    echo "[+] Regenerando assets do Mautic..."
    ${PHP_BIN} bin/console mautic:assets:generate --no-interaction || true
fi

# 7. Ajustar permissões de arquivos e pastas críticas
echo "[+] Ajustando permissões de diretórios..."
mkdir -p var/cache var/logs var/spool var/tmp media/files 2>/dev/null || true
chown -R "${WEB_USER}:${WEB_USER}" var/ media/ plugins/ themes/ 2>/dev/null || true
chmod -R 775 var/cache var/logs var/spool var/tmp media/ 2>/dev/null || true

# 8. Recarregar serviços do PHP/Web se tiver permissão root
if [ "$(id -u)" -eq 0 ]; then
    echo "[+] Recarregando PHP-FPM / Servidor Web..."
    systemctl reload php8.2-fpm 2>/dev/null || systemctl reload php8.3-fpm 2>/dev/null || systemctl reload php-fpm 2>/dev/null || true
    systemctl reload nginx 2>/dev/null || systemctl reload apache2 2>/dev/null || systemctl reload httpd 2>/dev/null || true
fi

echo "=========================================================="
echo "    Atualização concluída com sucesso no Mautic Custom!   "
echo "=========================================================="
