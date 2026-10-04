#!/usr/bin/env bash
set -euo pipefail

# Lucoa Omarchy — Kitty installer
#
# Installs the Kitty configuration shipped with this rice.
#
# Safety:
#   - supports a read-only --check mode
#   - validates source files before making changes
#   - installs Kitty only when it is missing
#   - creates a temporary rollback copy of managed config files
#   - never deletes unrelated files from ~/.config/kitty
#   - validates kitty.conf with Kitty's own config loader
#
# A persistent user backup is handled by install/backup.sh before this
# script is called by install/install.sh.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/config/kitty"

SOURCE_CONFIG="$SOURCE_DIR/kitty.conf"
SOURCE_THEME="$SOURCE_DIR/current-theme.conf"

TARGET_DIR="$HOME/.config/kitty"
TARGET_CONFIG="$TARGET_DIR/kitty.conf"
TARGET_THEME="$TARGET_DIR/current-theme.conf"

CHECK_ONLY=false
ROLLBACK_NEEDED=false
ROLLBACK_DIR=""

MANAGED_FILES=(
    "kitty.conf"
    "current-theme.conf"
)

usage() {
    cat <<'USAGE'
Uso:
  ./install/kitty.sh
  ./install/kitty.sh --check
  ./install/kitty.sh --help

Modos:
  --check       valida Kitty e os arquivos sem alterar a configuração
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

check_source_files() {
    echo
    echo "==> Validando arquivos do projeto..."

    [[ -f "$SOURCE_CONFIG" ]] \
        || die "kitty.conf não encontrado: $SOURCE_CONFIG"

    [[ -s "$SOURCE_CONFIG" ]] \
        || die "kitty.conf está vazio: $SOURCE_CONFIG"

    [[ -f "$SOURCE_THEME" ]] \
        || die "current-theme.conf não encontrado: $SOURCE_THEME"

    [[ -s "$SOURCE_THEME" ]] \
        || die "current-theme.conf está vazio: $SOURCE_THEME"

    log_ok "kitty.conf presente."
    log_ok "current-theme.conf presente."
}

check_kitty_command() {
    echo
    echo "==> Verificando Kitty..."

    if command -v kitty >/dev/null 2>&1; then
        log_ok "Kitty já instalado: $(command -v kitty)"
        return 0
    fi

    if [[ "$CHECK_ONLY" == true ]]; then
        log_warn "Kitty não está instalado; a instalação real usará pacman."
        return 0
    fi

    command -v pacman >/dev/null 2>&1 \
        || die "pacman não encontrado; não é possível instalar Kitty."

    echo
    echo "==> Kitty não encontrado; instalando pelo pacman..."

    sudo pacman -S --needed --noconfirm kitty

    command -v kitty >/dev/null 2>&1 \
        || die "Kitty não foi encontrado após a instalação."

    log_ok "Kitty instalado."
}

validate_kitty_config() {
    local config_file="$1"
    local label="$2"
    local error_file

    command -v kitty >/dev/null 2>&1 \
        || die "Kitty não está disponível para validar a configuração."

    error_file="$(mktemp "${TMPDIR:-/tmp}/lucoa-kitty-config.XXXXXX")"

    # Kitty does not provide a --debug-config CLI flag. The documented
    # debug_config feature is an in-application action. For this installer
    # we need a non-interactive check, so use Kitty's +runpy entry point and
    # its own config loader without opening a terminal window.
    #
    # Running from the config directory preserves relative include behavior,
    # e.g. "include current-theme.conf".
    if (
        export KITTY_VALIDATE_CONFIG="$config_file"
        cd "$(dirname "$config_file")"
        kitty +runpy '
import os
from kitty.config import load_config
load_config(os.environ["KITTY_VALIDATE_CONFIG"])
'
    ) > /dev/null 2>"$error_file"; then
        rm -f "$error_file"
        log_ok "$label aceito pelo Kitty."
        return 0
    fi

    echo
    echo "ERRO: Kitty rejeitou $label:"
    echo "  $config_file"

    if [[ -s "$error_file" ]]; then
        echo
        cat "$error_file" >&2
    fi

    rm -f "$error_file"
    return 1
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

show_check_summary() {
    echo
    echo "============================================================"
    echo "Lucoa Omarchy — KITTY CHECK"
    echo "============================================================"
    log_ok "arquivos e configuração do Kitty validados."
    log_ok "nenhum arquivo foi alterado."
}

create_rollback() {
    ROLLBACK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lucoa-kitty-backup.XXXXXX")"

    for file in "${MANAGED_FILES[@]}"; do
        if [[ -f "$TARGET_DIR/$file" ]]; then
            install -Dm600 "$TARGET_DIR/$file" "$ROLLBACK_DIR/$file"
        fi
    done

    ROLLBACK_NEEDED=true
    log_ok "backup temporário criado para rollback."
}

restore_rollback() {
    echo
    echo "==> Restaurando configuração anterior do Kitty..."

    for file in "${MANAGED_FILES[@]}"; do
        local saved="$ROLLBACK_DIR/$file"

        if [[ -f "$saved" ]]; then
            install -Dm600 "$saved" "$TARGET_DIR/$file"
            log_ok "restaurado: $file"
        else
            rm -f "$TARGET_DIR/$file"
            log_ok "removido arquivo que não existia antes: $file"
        fi
    done
}

rollback() {
    [[ "$ROLLBACK_NEEDED" == true ]] || return 0

    echo
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "ERRO: instalação do Kitty falhou."
    echo "==> Iniciando rollback..."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

    if [[ -n "$ROLLBACK_DIR" && -d "$ROLLBACK_DIR" ]]; then
        restore_rollback
    else
        log_warn "backup temporário do Kitty não está disponível."
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

    [[ -f "$TARGET_CONFIG" ]] \
        || die "kitty.conf não foi encontrado após a instalação."

    [[ -f "$TARGET_THEME" ]] \
        || die "current-theme.conf não foi encontrado após a instalação."

    validate_kitty_config "$TARGET_CONFIG" "kitty.conf instalado"

    # Ensure the shipped theme file actually contains configuration data.
    [[ -s "$TARGET_THEME" ]] \
        || die "current-theme.conf instalado está vazio."

    log_ok "current-theme.conf instalado."
}

run_check() {
    echo "==> Lucoa Omarchy — Kitty installer"
    echo "    Modo: CHECK (somente leitura)"
    echo "    Source: $SOURCE_DIR"
    echo "    Target: $TARGET_DIR"

    check_source_files
    check_kitty_command

    if command -v kitty >/dev/null 2>&1; then
        validate_kitty_config "$SOURCE_CONFIG" "kitty.conf"
    else
        log_warn "Kitty não está instalado; a validação de sintaxe será feita na instalação real."
    fi

    check_target_dir

    echo
    echo "============================================================"
    echo "Lucoa Omarchy — KITTY CHECK"
    echo "============================================================"
    log_ok "preflight do Kitty concluído."
    log_ok "nenhum arquivo de configuração foi alterado."
}

run_install() {
    echo "==> Lucoa Omarchy — Kitty installer"
    echo "    Modo: INSTALAÇÃO"
    echo "    Source: $SOURCE_DIR"
    echo "    Target: $TARGET_DIR"

    trap on_error ERR

    check_source_files
    check_kitty_command
    validate_kitty_config "$SOURCE_CONFIG" "kitty.conf"
    check_target_dir
    create_rollback

    echo
    echo "==> Instalando configuração do Kitty..."

    install -Dm644 "$SOURCE_CONFIG" "$TARGET_CONFIG"
    log_ok "$TARGET_CONFIG"

    install -Dm644 "$SOURCE_THEME" "$TARGET_THEME"
    log_ok "$TARGET_THEME"

    validate_installed_config

    trap - ERR
    ROLLBACK_NEEDED=false

    echo
    echo "============================================================"
    echo "✓ Configuração Kitty instalada com sucesso."
    echo "============================================================"
    echo
    echo "Kitty:  $(command -v kitty)"
    echo "Config: $TARGET_CONFIG"
    echo "Theme:  $TARGET_THEME"
}

cleanup() {
    [[ -n "$ROLLBACK_DIR" && -d "$ROLLBACK_DIR" ]] \
        && rm -rf "$ROLLBACK_DIR"
}

trap cleanup EXIT

if [[ "$CHECK_ONLY" == true ]]; then
    run_check
else
    run_install
fi
