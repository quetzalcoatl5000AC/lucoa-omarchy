#!/usr/bin/env bash
set -euo pipefail

# Lucoa Omarchy — backup manager
#
# Creates a timestamped backup of files that Lucoa Omarchy installers may
# replace. The script is intentionally conservative:
#   - never deletes anything
#   - never modifies the original files
#   - skips targets that do not exist
#   - uses sudo only for system-owned files
#
# The backup is stored under:
#   ~/.local/state/lucoa-omarchy/backups/
#
# Optional:
#   ./install/backup.sh --check
#   ./install/backup.sh --output-dir /path/to/backup

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/lucoa-omarchy"
BACKUP_ROOT="$STATE_DIR/backups"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
DEFAULT_BACKUP_DIR="$BACKUP_ROOT/setup-$TIMESTAMP"

BACKUP_DIR="$DEFAULT_BACKUP_DIR"
CHECK_ONLY=false
ERRORS=0
SKIPPED=0
BACKED_UP=0

USER_TARGETS=(
    ".config/hypr/autostart.lua"
    ".config/hypr/bindings.lua"
    ".config/hypr/hyprland.lua"
    ".config/hypr/input.lua"
    ".config/hypr/looknfeel.lua"
    ".config/hypr/monitors.lua"
    ".config/kitty/current-theme.conf"
    ".config/kitty/kitty.conf"
    ".config/noctalia/bar.toml"
    ".config/rofi/config.rasi"
)

SYSTEM_TARGETS=(
    "/usr/share/plymouth/themes/omarchy"
    "/usr/local/bin/noctalia"
    "/usr/local/share/noctalia/assets"
)

usage() {
    cat <<'USAGE'
Uso:
  ./install/backup.sh
  ./install/backup.sh --check
  ./install/backup.sh --output-dir /caminho/do/backup

Modos:
  --check             mostra o que seria salvo, sem copiar nada
  --output-dir PATH   define o diretório de backup
  -h, --help          mostra esta ajuda
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

log_error() {
    printf '✗ %s\n' "$1" >&2
    ERRORS=$((ERRORS + 1))
}

die() {
    echo
    echo "ERRO: $1" >&2
    exit 1
}

case "${1:-}" in
    "")
        ;;
    --check)
        CHECK_ONLY=true
        ;;
    --output-dir)
        [[ $# -eq 2 ]] || die "--output-dir exige um caminho."
        BACKUP_DIR="$2"
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
    die "execute este script como seu usuário normal. Ele usa sudo apenas para ler/copiar arquivos protegidos."
fi

if ! command -v sudo >/dev/null 2>&1; then
    die "sudo não encontrado."
fi

if [[ ! -d "$ROOT_DIR" ]]; then
    die "root do projeto não encontrado: $ROOT_DIR"
fi

# Refuse to overwrite an existing backup directory unless explicitly empty.
if [[ "$CHECK_ONLY" != true && -e "$BACKUP_DIR" ]]; then
    die "diretório de backup já existe: $BACKUP_DIR"
fi

backup_user_target() {
    local relative="$1"
    local source="$HOME/$relative"
    local destination="$BACKUP_DIR/user/$relative"

    if [[ ! -e "$source" && ! -L "$source" ]]; then
        SKIPPED=$((SKIPPED + 1))
        log_info "não existe, ignorando: $source"
        return 0
    fi

    if [[ "$CHECK_ONLY" == true ]]; then
        log_ok "será salvo: $source"
        return 0
    fi

    mkdir -p "$(dirname "$destination")"

    if cp -a "$source" "$destination"; then
        BACKED_UP=$((BACKED_UP + 1))
        log_ok "backup: $source"
    else
        log_error "falha ao copiar: $source"
    fi
}

backup_system_target() {
    local source="$1"

    # Existence checks are deliberately unprivileged. --check must not
    # prompt for sudo or alter authentication state.
    if [[ ! -e "$source" && ! -L "$source" ]]; then
        SKIPPED=$((SKIPPED + 1))
        log_info "não existe, ignorando: $source"
        return 0
    fi

    if [[ "$CHECK_ONLY" == true ]]; then
        log_ok "será salvo: $source"
        return 0
    fi

    local relative="${source#/}"
    local destination="$BACKUP_DIR/system/$relative"

    sudo mkdir -p "$(dirname "$destination")"

    if sudo cp -a "$source" "$destination"; then
        BACKED_UP=$((BACKED_UP + 1))

        # Make the backup readable/writable by the invoking user.
        sudo chown -R "$USER":"$(id -gn)" "$BACKUP_DIR/system" 2>/dev/null || true

        log_ok "backup: $source"
    else
        log_error "falha ao copiar: $source"
    fi
}

write_metadata() {
    [[ "$CHECK_ONLY" == true ]] && return 0

    cat > "$BACKUP_DIR/backup-info.txt" <<EOF
Lucoa Omarchy backup
====================

Created: $(date --iso-8601=seconds)
User:    $USER
Home:    $HOME
Host:    $(hostname 2>/dev/null || printf '%s' unknown)
Project: $ROOT_DIR

OS:
$(if [[ -f /etc/os-release ]]; then
    sed -n -e '/^NAME=/p' -e '/^PRETTY_NAME=/p' -e '/^ID=/p' -e '/^ID_LIKE=/p' /etc/os-release
fi)

Omarchy:
$(if command -v omarchy-version >/dev/null 2>&1; then
    omarchy-version 2>/dev/null | head -n 1 || true
elif [[ -f /usr/share/omarchy/version ]]; then
    head -n 1 /usr/share/omarchy/version 2>/dev/null || true
else
    printf '%s\n' unknown
fi)

Kernel:
$(uname -r 2>/dev/null || printf '%s\n' unknown)

Hyprland:
$(if command -v hyprland >/dev/null 2>&1; then
    hyprland --version 2>/dev/null | head -n 1 || true
else
    printf '%s\n' unavailable
fi)

Noctalia:
$(if [[ -x /usr/local/bin/noctalia ]]; then
    /usr/local/bin/noctalia --version 2>/dev/null | head -n 1 || true
elif command -v noctalia >/dev/null 2>&1; then
    noctalia --version 2>/dev/null | head -n 1 || true
else
    printf '%s\n' unavailable
fi)

Plymouth:
$(if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    plymouth-set-default-theme 2>/dev/null | head -n 1 || true
else
    printf '%s\n' unavailable
fi)
EOF
}

print_summary() {
    echo
    echo "============================================================"
    echo "Lucoa Omarchy — BACKUP"
    echo "============================================================"

    if [[ "$CHECK_ONLY" == true ]]; then
        log_ok "CHECK concluído. Nenhum arquivo foi copiado ou alterado."
        return 0
    fi

    if (( ERRORS > 0 )); then
        log_error "backup concluído com $ERRORS erro(s)."
        echo
        echo "Backup parcial:"
        echo "  $BACKUP_DIR"
        return 1
    fi

    log_ok "backup concluído."
    echo
    echo "Arquivos/diretórios salvos: $BACKED_UP"
    echo "Alvos ausentes/ignorados: $SKIPPED"
    echo "Local:"
    echo "  $BACKUP_DIR"
}

main() {
    echo "==> Lucoa Omarchy — backup"
    echo "    Root do projeto: $ROOT_DIR"
    echo "    Destino: $BACKUP_DIR"

    if [[ "$CHECK_ONLY" == true ]]; then
        echo "    Modo: CHECK (somente leitura)"
    else
        echo "    Modo: BACKUP"
    fi

    echo
    echo "==> Alvos do usuário..."

    for relative in "${USER_TARGETS[@]}"; do
        backup_user_target "$relative"
    done

    echo
    echo "==> Alvos do sistema..."

    for source in "${SYSTEM_TARGETS[@]}"; do
        backup_system_target "$source"
    done

    if [[ "$CHECK_ONLY" != true ]]; then
        mkdir -p "$BACKUP_DIR"
        write_metadata
    fi

    print_summary
}

main
