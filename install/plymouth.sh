#!/usr/bin/env bash
set -euo pipefail

# Lucoa Omarchy — Plymouth installer
#
# Installs the Lucoa Plymouth theme into the existing Omarchy theme
# directory without touching /usr/share/omarchy.
#
# Safety:
#   - validates all source files before making changes
#   - supports a read-only --check mode
#   - backs up the current Omarchy Plymouth theme
#   - restores the backup if installation or initramfs regeneration fails
#   - uses Omarchy's Limine-aware initramfs flow
#   - records the backup under ~/.local/state/lucoa-omarchy/backups/

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SOURCE_THEME_DIR="$ROOT_DIR/plymouth/lucoa"
SOURCE_ASSET_DIR="$ROOT_DIR/assets/plymouth"
TARGET_THEME_DIR="/usr/share/plymouth/themes/omarchy"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/lucoa-omarchy"
BACKUP_ROOT="$STATE_DIR/backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/plymouth-$TIMESTAMP"

THEME_FILES=(
    "omarchy.plymouth"
    "omarchy.script"
)

ASSET_FILES=(
    "bullet.png"
    "entry.png"
    "lock.png"
    "logo.png"
    "preview-unlock.png"
    "progress_bar.png"
    "progress_box.png"
)

CURRENT_THEME=""
CHECK_ONLY=false
ROLLBACK_NEEDED=false

usage() {
    cat <<'USAGE'
Uso:
  ./install/plymouth.sh
  ./install/plymouth.sh --check

Modos:
  --check       verifica pré-requisitos e arquivos sem alterar o sistema
  -h, --help    mostra esta ajuda
USAGE
}

die() {
    echo
    echo "ERRO: $1"
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
        echo "ERRO: argumento desconhecido: $1"
        echo
        usage
        exit 1
        ;;
esac

rollback() {
    if [[ "$ROLLBACK_NEEDED" != true ]]; then
        return 0
    fi

    echo
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "ERRO: instalação do Plymouth falhou."
    echo "==> Restaurando backup..."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

    if [[ -d "$BACKUP_DIR" ]]; then
        sudo rm -rf "$TARGET_THEME_DIR"
        sudo mkdir -p "$TARGET_THEME_DIR"
        sudo cp -a "$BACKUP_DIR/." "$TARGET_THEME_DIR/"
    fi

    if [[ -n "$CURRENT_THEME" ]]; then
        echo "==> Restaurando tema anterior: $CURRENT_THEME"
        sudo plymouth-set-default-theme "$CURRENT_THEME" || true
    fi

    echo
    echo "✓ Rollback concluído."
    echo "  Backup: $BACKUP_DIR"
}

on_error() {
    local exit_code=$?
    trap - ERR
    rollback || true
    exit "$exit_code"
}

check_prerequisites() {
    echo
    echo "==> Verificando pré-requisitos..."

    if [[ $EUID -eq 0 ]]; then
        die "execute este script como seu usuário normal. O script usa sudo apenas nas operações do sistema."
    fi

    if ! command -v sudo >/dev/null 2>&1; then
        die "sudo não encontrado."
    fi

    if ! command -v plymouth-set-default-theme >/dev/null 2>&1; then
        die "plymouth-set-default-theme não encontrado."
    fi

    if ! command -v limine-mkinitcpio >/dev/null 2>&1; then
        die "limine-mkinitcpio não encontrado. Este instalador exige o fluxo de boot do Omarchy."
    fi

    if ! command -v limine-update >/dev/null 2>&1; then
        die "limine-update não encontrado. Este instalador exige o fluxo de boot do Omarchy."
    fi

    if [[ ! -d "$SOURCE_THEME_DIR" ]]; then
        die "diretório do tema não encontrado: $SOURCE_THEME_DIR"
    fi

    if [[ ! -d "$SOURCE_ASSET_DIR" ]]; then
        die "diretório de assets não encontrado: $SOURCE_ASSET_DIR"
    fi

    if [[ ! -d "$TARGET_THEME_DIR" ]]; then
        echo
        echo "ERRO: tema Plymouth do Omarchy não encontrado:"
        echo "  $TARGET_THEME_DIR"
        echo
        echo "Este instalador é específico para o layout Plymouth do Omarchy."
        return 1
    fi

    echo "✓ Pré-requisitos básicos OK."
}

check_source_files() {
    echo
    echo "==> Validando arquivos do pacote..."

    for file in "${THEME_FILES[@]}"; do
        [[ -f "$SOURCE_THEME_DIR/$file" ]] \
            || die "arquivo ausente: $SOURCE_THEME_DIR/$file"
    done

    for file in "${ASSET_FILES[@]}"; do
        [[ -f "$SOURCE_ASSET_DIR/$file" ]] \
            || die "asset ausente: $SOURCE_ASSET_DIR/$file"
    done

    echo "✓ Arquivos do tema e assets OK."
}

get_current_theme() {
    CURRENT_THEME="$(plymouth-set-default-theme 2>/dev/null || true)"
    CURRENT_THEME="$(printf '%s' "$CURRENT_THEME" | head -n 1 | xargs || true)"
}

run_check() {
    echo "==> Lucoa Plymouth installer"
    echo "    Modo: CHECK (somente leitura)"
    echo "    Target: $TARGET_THEME_DIR"

    check_prerequisites
    check_source_files
    get_current_theme

    echo
    echo "==> Tema Plymouth atual: ${CURRENT_THEME:-desconhecido}"

    echo
    echo "✓ CHECK concluído."
    echo "  Nenhum arquivo do sistema foi alterado."
    echo "  Nenhum tema foi selecionado."
    echo "  Nenhum initramfs foi regenerado."
}

install_theme() {
    echo
    echo "==> Criando backup..."

    mkdir -p "$BACKUP_ROOT"

    sudo mkdir -p "$BACKUP_DIR"
    sudo cp -a "$TARGET_THEME_DIR/." "$BACKUP_DIR/"
    sudo chown -R "$USER":"$(id -gn)" "$BACKUP_DIR"

    ROLLBACK_NEEDED=true

    echo "✓ Backup salvo em:"
    echo "  $BACKUP_DIR"

    echo
    echo "==> Instalando arquivos do tema..."

    for file in "${THEME_FILES[@]}"; do
        sudo install -Dm644 \
            "$SOURCE_THEME_DIR/$file" \
            "$TARGET_THEME_DIR/$file"
    done

    for file in "${ASSET_FILES[@]}"; do
        sudo install -Dm644 \
            "$SOURCE_ASSET_DIR/$file" \
            "$TARGET_THEME_DIR/$file"
    done

    echo "✓ Arquivos copiados."
}

validate_installation() {
    echo
    echo "==> Validando tema instalado..."

    if [[ ! -f "$TARGET_THEME_DIR/omarchy.plymouth" \
       || ! -f "$TARGET_THEME_DIR/omarchy.script" ]]; then
        die "arquivos principais do tema não foram encontrados após a instalação."
    fi

    for file in "${ASSET_FILES[@]}"; do
        if [[ ! -f "$TARGET_THEME_DIR/$file" ]]; then
            die "asset não encontrado após instalação: $TARGET_THEME_DIR/$file"
        fi
    done

    FINAL_THEME="$(plymouth-set-default-theme 2>/dev/null || true)"
    FINAL_THEME="$(printf '%s' "$FINAL_THEME" | head -n 1 | xargs || true)"

    if [[ "$FINAL_THEME" != "omarchy" ]]; then
        die "o tema padrão não ficou como 'omarchy'. Resultado: ${FINAL_THEME:-desconhecido}"
    fi

    echo "✓ Tema e assets validados."
}

rebuild_boot() {
    echo
    echo "==> Reconstruindo initramfs do Omarchy..."
    sudo limine-mkinitcpio

    echo
    echo "==> Atualizando entradas do Limine..."
    sudo limine-update

    echo
    echo "✓ Initramfs e Limine atualizados."
}

run_install() {
    echo "==> Lucoa Plymouth installer"
    echo "    Modo: INSTALAÇÃO"
    echo "    Target: $TARGET_THEME_DIR"

    check_prerequisites
    check_source_files
    get_current_theme

    echo
    echo "==> Tema Plymouth atual: ${CURRENT_THEME:-desconhecido}"

    trap on_error ERR

    install_theme

    echo
    echo "==> Selecionando tema omarchy..."
    sudo plymouth-set-default-theme omarchy

    rebuild_boot

    validate_installation

    trap - ERR
    ROLLBACK_NEEDED=false

    echo
    echo "✓ Plymouth Lucoa instalado com sucesso."
    echo
    echo "  Tema:       omarchy"
    echo "  Diretório:  $TARGET_THEME_DIR"
    echo "  Backup:     $BACKUP_DIR"
    echo
    echo "O instalador não alterou /usr/share/omarchy."
}

if [[ "$CHECK_ONLY" == true ]]; then
    run_check
else
    run_install
fi
