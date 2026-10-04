#!/usr/bin/env bash
set -euo pipefail

# Lucoa Omarchy — Hyprland installer
#
# Installs the Hyprland configuration shipped with this rice.
#
# Safety:
#   - supports a read-only --check mode
#   - validates every source file before copying anything
#   - never deletes unrelated files from ~/.config/hypr
#   - creates a temporary rollback copy of the six managed files
#   - compares Hyprland config errors before/after installation
#   - reloads Hyprland and verifies that it remains responsive
#   - restores the previous files if the reload/validation fails
#
# A full persistent user backup is handled by install/backup.sh before
# this script is called by install/install.sh.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/config/hypr"
TARGET_DIR="$HOME/.config/hypr"

FILES=(
    "autostart.lua"
    "bindings.lua"
    "hyprland.lua"
    "input.lua"
    "looknfeel.lua"
    "monitors.lua"
)

CHECK_ONLY=false
ROLLBACK_NEEDED=false
ROLLBACK_DIR=""
BASELINE_ERRORS_FILE=""
CURRENT_ERRORS_FILE=""

usage() {
    cat <<'USAGE'
Uso:
  ./install/hyprland.sh
  ./install/hyprland.sh --check
  ./install/hyprland.sh --help

Modos:
  --check       valida os arquivos do projeto sem alterar o Hyprland
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

check_commands() {
    echo
    echo "==> Verificando comandos..."

    command -v hyprland >/dev/null 2>&1 \
        || die "Hyprland não encontrado."

    command -v hyprctl >/dev/null 2>&1 \
        || die "hyprctl não encontrado."

    log_ok "Hyprland e hyprctl disponíveis."
}

check_paths() {
    echo
    echo "==> Verificando diretórios..."

    [[ -d "$SOURCE_DIR" ]] \
        || die "diretório de configuração não encontrado: $SOURCE_DIR"

    if [[ ! -d "$TARGET_DIR" ]]; then
        if [[ "$CHECK_ONLY" == true ]]; then
            log_info "diretório alvo ainda não existe: $TARGET_DIR"
        else
            mkdir -p "$TARGET_DIR"
            log_ok "diretório criado: $TARGET_DIR"
        fi
    else
        log_ok "diretório alvo presente: $TARGET_DIR"
    fi
}

check_source_files() {
    echo
    echo "==> Validando arquivos do projeto..."

    local missing=false

    for file in "${FILES[@]}"; do
        if [[ ! -f "$SOURCE_DIR/$file" ]]; then
            echo "✗ arquivo ausente: $SOURCE_DIR/$file" >&2
            missing=true
        else
            log_ok "$file"
        fi
    done

    [[ "$missing" == false ]] \
        || die "um ou mais arquivos do Hyprland estão ausentes."

    if ! grep -Fq 'o.launch_on_start("/usr/local/bin/noctalia")' \
        "$SOURCE_DIR/autostart.lua"; then
        die "autostart.lua não aponta para /usr/local/bin/noctalia."
    fi

    log_ok "autostart usa o Noctalia customizado."
}

check_target_writable() {
    [[ -d "$TARGET_DIR" ]] || return 0

    if [[ ! -w "$TARGET_DIR" ]]; then
        die "diretório alvo não é gravável: $TARGET_DIR"
    fi

    log_ok "diretório alvo é gravável."
}

show_check_summary() {
    echo
    echo "============================================================"
    echo "Lucoa Omarchy — HYPRLAND CHECK"
    echo "============================================================"
    log_ok "arquivos do projeto validados."
    log_ok "nenhum arquivo do sistema foi alterado."
    log_ok "nenhum reload do Hyprland foi executado."
}

create_temporary_backup() {
    ROLLBACK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lucoa-hyprland-backup.XXXXXX")"

    for file in "${FILES[@]}"; do
        if [[ -f "$TARGET_DIR/$file" ]]; then
            install -Dm600 "$TARGET_DIR/$file" "$ROLLBACK_DIR/$file"
        fi
    done

    log_ok "backup temporário criado para rollback."
}

capture_config_errors() {
    local destination="$1"
    local output

    # hyprctl configerrors is an information command that lists current
    # parsing errors. Capture both streams so terminal formatting/output
    # quirks cannot make the installer misread the result.
    output="$(hyprctl configerrors 2>&1 || true)"

    # Normalize CRLF and discard whitespace-only output.
    output="${output//$'\r'/}"
    output="$(printf '%s\n' "$output" | sed '/^[[:space:]]*$/d')"

    printf '%s\n' "$output" > "$destination"
}

show_config_errors() {
    local file="$1"

    if [[ -s "$file" ]]; then
        cat "$file"
    else
        echo "(nenhum erro reportado)"
    fi
}

config_errors_equal() {
    cmp -s "$BASELINE_ERRORS_FILE" "$CURRENT_ERRORS_FILE"
}

validate_runtime() {
    echo
    echo "==> Recarregando Hyprland..."

    if ! hyprctl reload; then
        die "hyprctl reload falhou."
    fi

    log_ok "Hyprland aceitou o reload."

    # Give the compositor a brief moment to finish parsing/reloading.
    sleep 0.2

    echo
    echo "==> Verificando erros de configuração..."

    CURRENT_ERRORS_FILE="$(mktemp "${TMPDIR:-/tmp}/lucoa-hypr-errors.XXXXXX")"
    capture_config_errors "$CURRENT_ERRORS_FILE"

    if [[ -s "$BASELINE_ERRORS_FILE" ]]; then
        echo "• Erros existentes antes da instalação:"
        show_config_errors "$BASELINE_ERRORS_FILE"
        echo
    else
        echo "• Erros existentes antes da instalação: nenhum"
    fi

    if [[ -s "$CURRENT_ERRORS_FILE" ]]; then
        echo "• Erros reportados depois do reload:"
        show_config_errors "$CURRENT_ERRORS_FILE"
        echo
    else
        echo "• Erros reportados depois do reload: nenhum"
    fi

    # If the state of configerrors changed, something about the reload's
    # parsing state changed. Treat that as unsafe and rollback.
    if ! config_errors_equal; then
        die "o estado de configerrors mudou após o reload."
    fi

    log_ok "configerrors permanece igual após a instalação."

    if ! hyprctl version >/dev/null 2>&1; then
        die "Hyprland não está respondendo após o reload."
    fi

    log_ok "Hyprland continua respondendo."
}

restore_previous_files() {
    local backup_dir="$1"

    echo
    echo "==> Restaurando configuração anterior..."

    for file in "${FILES[@]}"; do
        local saved="$backup_dir/$file"

        if [[ -f "$saved" ]]; then
            install -Dm600 "$saved" "$TARGET_DIR/$file"
            log_ok "restaurado: $file"
        else
            # The target did not exist before this install.
            rm -f "$TARGET_DIR/$file"
            log_ok "removido arquivo que não existia antes: $file"
        fi
    done
}

rollback() {
    [[ "$ROLLBACK_NEEDED" == true ]] || return 0

    echo
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "ERRO: configuração Hyprland falhou."
    echo "==> Iniciando rollback..."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

    if [[ -n "$ROLLBACK_DIR" && -d "$ROLLBACK_DIR" ]]; then
        restore_previous_files "$ROLLBACK_DIR"

        if hyprctl reload >/dev/null 2>&1; then
            log_ok "Hyprland recarregado com a configuração anterior."
        else
            log_warn "Hyprland não pôde ser recarregado automaticamente após rollback."
        fi
    else
        log_warn "backup temporário do Hyprland não está disponível."
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

cleanup() {
    [[ -n "$ROLLBACK_DIR" && -d "$ROLLBACK_DIR" ]] \
        && rm -rf "$ROLLBACK_DIR"

    [[ -n "$BASELINE_ERRORS_FILE" && -f "$BASELINE_ERRORS_FILE" ]] \
        && rm -f "$BASELINE_ERRORS_FILE"

    [[ -n "$CURRENT_ERRORS_FILE" && -f "$CURRENT_ERRORS_FILE" ]] \
        && rm -f "$CURRENT_ERRORS_FILE"
}

run_check() {
    echo "==> Lucoa Omarchy — Hyprland installer"
    echo "    Modo: CHECK (somente leitura)"
    echo "    Source: $SOURCE_DIR"
    echo "    Target: $TARGET_DIR"

    check_commands
    check_paths
    check_source_files
    check_target_writable
    show_check_summary
}

run_install() {
    echo "==> Lucoa Omarchy — Hyprland installer"
    echo "    Modo: INSTALAÇÃO"
    echo "    Source: $SOURCE_DIR"
    echo "    Target: $TARGET_DIR"

    trap on_error ERR
    trap cleanup EXIT

    check_commands
    check_paths
    check_source_files
    check_target_writable

    BASELINE_ERRORS_FILE="$(mktemp "${TMPDIR:-/tmp}/lucoa-hypr-errors-baseline.XXXXXX")"
    capture_config_errors "$BASELINE_ERRORS_FILE"

    if [[ -s "$BASELINE_ERRORS_FILE" ]]; then
        log_warn "existem configerrors antes da instalação; eles serão preservados como baseline."
    else
        log_ok "nenhum configerror existente antes da instalação."
    fi

    create_temporary_backup

    echo
    echo "==> Instalando configuração Hyprland..."

    for file in "${FILES[@]}"; do
        install -Dm644 "$SOURCE_DIR/$file" "$TARGET_DIR/$file"
        log_ok "$TARGET_DIR/$file"
    done

    ROLLBACK_NEEDED=true

    validate_runtime

    trap - EXIT ERR
    ROLLBACK_NEEDED=false

    cleanup

    echo
    echo "============================================================"
    echo "✓ Configuração Hyprland instalada com sucesso."
    echo "============================================================"
}

if [[ "$CHECK_ONLY" == true ]]; then
    run_check
else
    run_install
fi
