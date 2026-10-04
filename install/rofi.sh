#!/usr/bin/env bash
set -euo pipefail

# Lucoa Omarchy — Rofi installer
#
# Installs the Rofi configuration shipped with this rice.
#
# Safety:
#   - supports a read-only --check mode
#   - validates the source config before making changes
#   - installs Rofi only when it is missing
#   - creates a temporary rollback copy of config.rasi
#   - never deletes unrelated files from ~/.config/rofi
#   - validates the resulting Rofi configuration
#
# A persistent user backup is handled by install/backup.sh before this
# script is called by install/install.sh.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_FILE="$ROOT_DIR/config/rofi/config.rasi"
TARGET_DIR="$HOME/.config/rofi"
TARGET_FILE="$TARGET_DIR/config.rasi"

CHECK_ONLY=false
ROLLBACK_NEEDED=false
ROLLBACK_FILE=""
ROFI_WAS_INSTALLED=false

usage() {
    cat <<'USAGE'
Uso:
  ./install/rofi.sh
  ./install/rofi.sh --check
  ./install/rofi.sh --help

Modos:
  --check       valida Rofi e config.rasi sem alterar o sistema
  -h, --help    mostra esta ajuda
USAGE
}

log_ok() {
    printf '✓ %s\n' "$1"
}

log_info() {
    printf '• %s\n' "$1"
}

log_warn() {
    printf '⚠ %s\n' "$1"
}

die() {
    echo
    echo "ERRO: $1" >&2
    return 1
}

case "${1:-}" in
    "")
        ;;
    --check)
        CHECK_ONLY=true
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        echo "ERRO: argumento desconhecido: $1" >&2
        echo
        usage
        exit 1
        ;;
esac

if [[ $EUID -eq 0 ]]; then
    die "execute este script como seu usuário normal."
fi

check_source() {
    echo
    echo "==> Verificando configuração do projeto..."

    [[ -f "$SOURCE_FILE" ]] \
        || die "configuração do Rofi não encontrada: $SOURCE_FILE"

    [[ -s "$SOURCE_FILE" ]] \
        || die "configuração do Rofi está vazia: $SOURCE_FILE"

    log_ok "config.rasi presente."
}

install_rofi_if_needed() {
    if command -v rofi >/dev/null 2>&1; then
        log_ok "Rofi já instalado: $(command -v rofi)"
        return 0
    fi

    if [[ "$CHECK_ONLY" == true ]]; then
        log_warn "Rofi não está instalado; o instalador real usará pacman para instalá-lo."
        return 0
    fi

    command -v pacman >/dev/null 2>&1 \
        || die "pacman não encontrado; não é possível instalar Rofi."

    echo
    echo "==> Rofi não encontrado; instalando pelo pacman..."

    sudo pacman -S --needed --noconfirm rofi
    ROFI_WAS_INSTALLED=true

    command -v rofi >/dev/null 2>&1 \
        || die "Rofi não foi encontrado após a instalação."

    log_ok "Rofi instalado."
}

validate_rofi_binary() {
    command -v rofi >/dev/null 2>&1 \
        || die "Rofi não encontrado."

    if [[ "$CHECK_ONLY" != true ]]; then
        return 0
    fi

    log_ok "binário do Rofi disponível: $(command -v rofi)"
}

validate_config_syntax() {
    local config_file="$1"

    # Rofi parses the supplied config when any option requiring a config is
    # processed. -dump-config writes the effective configuration and exits
    # without opening the launcher UI.
    if rofi -config "$config_file" -dump-config >/dev/null 2>&1; then
        log_ok "configuração Rofi válida: $config_file"
    else
        die "Rofi rejeitou a configuração: $config_file"
    fi
}

check_target_dir() {
    if [[ ! -d "$TARGET_DIR" ]]; then
        if [[ "$CHECK_ONLY" == true ]]; then
            log_info "diretório alvo ainda não existe: $TARGET_DIR"
        else
            mkdir -p "$TARGET_DIR"
            log_ok "diretório criado: $TARGET_DIR"
        fi
        return 0
    fi

    [[ -w "$TARGET_DIR" ]] \
        || die "diretório alvo não é gravável: $TARGET_DIR"

    log_ok "diretório alvo gravável: $TARGET_DIR"
}

create_rollback() {
    ROLLBACK_FILE="$(mktemp "${TMPDIR:-/tmp}/lucoa-rofi-config.XXXXXX")"

    if [[ -f "$TARGET_FILE" ]]; then
        cp -a "$TARGET_FILE" "$ROLLBACK_FILE"
        ROLLBACK_NEEDED=true
        log_ok "backup temporário criado para rollback."
    else
        rm -f "$ROLLBACK_FILE"
        ROLLBACK_FILE=""
        ROLLBACK_NEEDED=true
        log_ok "nenhum config.rasi anterior; rollback removerá apenas o arquivo criado."
    fi
}

restore_rollback() {
    [[ "$ROLLBACK_NEEDED" == true ]] || return 0

    echo
    echo "==> Restaurando configuração anterior do Rofi..."

    if [[ -n "$ROLLBACK_FILE" && -f "$ROLLBACK_FILE" ]]; then
        install -Dm644 "$ROLLBACK_FILE" "$TARGET_FILE"
        log_ok "config.rasi restaurado."
    else
        rm -f "$TARGET_FILE"
        log_ok "config.rasi removido porque não existia antes."
    fi
}

rollback() {
    [[ "$ROLLBACK_NEEDED" == true ]] || return 0

    echo
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "ERRO: instalação do Rofi falhou."
    echo "==> Iniciando rollback..."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

    restore_rollback

    # Do not remove an existing system package. If this installer had to
    # install Rofi, leaving the package installed is safer than attempting
    # a package removal that might affect another user/workflow.
    if [[ "$ROFI_WAS_INSTALLED" == true ]]; then
        log_info "Rofi foi instalado pelo instalador e foi mantido no sistema."
    fi

    echo
    echo "✓ Rollback concluído."
}

on_error() {
    local exit_code=$?
    trap - ERR
    rollback || true
    exit "$exit_code"
}

validate_installed_config() {
    echo
    echo "==> Validando configuração instalada..."

    [[ -f "$TARGET_FILE" ]] \
        || die "config.rasi não foi encontrado após a instalação."

    validate_config_syntax "$TARGET_FILE"

    # Keep this configuration invariant explicit: the shipped palette is
    # intentionally the dark Lucoa pink palette.
    if ! grep -Fq 'background-color: #260014;' "$TARGET_FILE"; then
        die "a paleta Lucoa esperada não foi encontrada em config.rasi."
    fi

    if ! grep -Fq 'background-color: #720044;' "$TARGET_FILE"; then
        die "a cor de seleção da paleta Lucoa não foi encontrada em config.rasi."
    fi

    log_ok "paleta Lucoa detectada."
}

run_check() {
    echo "==> Lucoa Omarchy — Rofi installer"
    echo "    Modo: CHECK (somente leitura)"
    echo "    Source: $SOURCE_FILE"
    echo "    Target: $TARGET_FILE"

    check_source
    install_rofi_if_needed

    if command -v rofi >/dev/null 2>&1; then
        log_info "versão: $(rofi -version 2>/dev/null | head -n 1 || true)"
        validate_config_syntax "$SOURCE_FILE"
    else
        log_warn "não foi possível validar a sintaxe com Rofi porque o binário não está instalado."
    fi

    if [[ -f "$TARGET_FILE" ]]; then
        validate_config_syntax "$TARGET_FILE"
        log_info "configuração atual do usuário também é válida."
    else
        log_info "configuração alvo ainda não existe; será criada pela instalação."
    fi

    check_target_dir

    echo
    echo "============================================================"
    echo "Lucoa Omarchy — ROFI CHECK"
    echo "============================================================"
    log_ok "preflight do Rofi concluído."
    log_ok "nenhum arquivo de configuração foi alterado."
}

run_install() {
    echo "==> Lucoa Omarchy — Rofi installer"
    echo "    Modo: INSTALAÇÃO"
    echo "    Source: $SOURCE_FILE"
    echo "    Target: $TARGET_FILE"

    trap on_error ERR

    check_source
    install_rofi_if_needed
    validate_rofi_binary
    check_target_dir
    create_rollback

    echo
    echo "==> Instalando configuração..."

    install -Dm644 "$SOURCE_FILE" "$TARGET_FILE"
    log_ok "$TARGET_FILE"

    validate_installed_config

    trap - ERR
    ROLLBACK_NEEDED=false

    echo
    echo "============================================================"
    echo "✓ Configuração Rofi instalada com sucesso."
    echo "============================================================"
    echo
    echo "Rofi: $(command -v rofi)"
    echo "Config: $TARGET_FILE"
}

cleanup() {
    [[ -n "$ROLLBACK_FILE" && -f "$ROLLBACK_FILE" ]] \
        && rm -f "$ROLLBACK_FILE"
}

trap cleanup EXIT

if [[ "$CHECK_ONLY" == true ]]; then
    run_check
else
    run_install
fi
