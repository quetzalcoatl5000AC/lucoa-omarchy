#!/usr/bin/env bash
set -euo pipefail

# Lucoa Omarchy — environment preflight
#
# Read-only safety check for the complete installer.
# This script does NOT:
#   - install packages
#   - invoke sudo for changes
#   - modify configuration files
#   - modify Plymouth
#   - modify initramfs
#   - modify the bootloader
#
# It is safe to run repeatedly.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$ROOT_DIR/config"
ASSETS_DIR="$ROOT_DIR/assets"
INSTALL_DIR="$ROOT_DIR/install"
NOCTALIA_PATCH="$ROOT_DIR/noctalia/lucoa-water-balloon.patch"

OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
OMARCHY_REQUIRED_FILES=(
    "$OMARCHY_PATH/default/hypr/bootstrap.lua"
)

CHECK_ONLY=true
VERBOSE=false
ERRORS=0
WARNINGS=0

usage() {
    cat <<'USAGE'
Uso:
  ./install/checks.sh
  ./install/checks.sh --verbose
  ./install/checks.sh --help

O script é somente leitura e faz um preflight do ambiente Omarchy
e da estrutura deste projeto antes da instalação.

Opções:
  --verbose     mostra versões e detalhes adicionais
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
    WARNINGS=$((WARNINGS + 1))
    printf '⚠ %s\n' "$1"
}

log_error() {
    ERRORS=$((ERRORS + 1))
    printf '✗ %s\n' "$1" >&2
}

has_command() {
    command -v "$1" >/dev/null 2>&1
}

version_of() {
    local command_name="$1"
    shift || true

    if ! has_command "$command_name"; then
        return 1
    fi

    "$command_name" "$@" 2>/dev/null | head -n 1 || true
}

check_user() {
    log_info "Verificando usuário..."

    if [[ $EUID -eq 0 ]]; then
        log_error "o instalador não deve ser executado como root."
        return
    fi

    if [[ -z "${HOME:-}" || ! -d "$HOME" ]]; then
        log_error "HOME não está configurado corretamente: ${HOME:-<vazio>}"
        return
    fi

    if [[ ! -w "$HOME" ]]; then
        log_error "HOME não é gravável pelo usuário atual: $HOME"
        return
    fi

    log_ok "usuário normal e HOME gravável: $HOME"
}

check_os() {
    log_info "Verificando sistema operacional..."

    if [[ ! -f /etc/os-release ]]; then
        log_error "/etc/os-release não existe."
        return
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    # Omarchy identifies itself as "omarchy" in /etc/os-release while
    # still being an Arch-based system. Accept Omarchy explicitly.
    if [[ "${ID:-}" == "omarchy" ]]; then
        log_ok "Omarchy (Arch-based) detectado."
    elif [[ "${ID:-}" == "arch" || "${ID_LIKE:-}" == *arch* ]]; then
        log_ok "Arch Linux detectado."
    else
        log_error "este setup exige Omarchy/Arch Linux; detectado: ${ID:-desconhecido}"
        return
    fi

    if [[ -n "${PRETTY_NAME:-}" ]]; then
        log_info "Sistema: $PRETTY_NAME"
    fi

    if [[ -n "${ID:-}" ]]; then
        log_info "OS ID: $ID${ID_LIKE:+ (ID_LIKE=$ID_LIKE)}"
    fi
}

check_omarchy() {
    log_info "Verificando Omarchy..."

    if [[ ! -d "$OMARCHY_PATH" ]]; then
        log_error "OMARCHY_PATH não encontrado: $OMARCHY_PATH"
        return
    fi

    if [[ ! -d "$OMARCHY_PATH/default" ]]; then
        log_error "estrutura padrão do Omarchy não encontrada: $OMARCHY_PATH/default"
        return
    fi

    local missing=false

    for file in "${OMARCHY_REQUIRED_FILES[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "arquivo essencial do Omarchy ausente: $file"
            missing=true
        fi
    done

    if [[ "$missing" == true ]]; then
        return
    fi

    log_ok "estrutura do Omarchy detectada em $OMARCHY_PATH"

    if has_command omarchy-version; then
        local version
        version="$(version_of omarchy-version)"
        [[ -n "$version" ]] && log_info "Omarchy: $version"
    elif [[ -f "$OMARCHY_PATH/version" ]]; then
        log_info "Omarchy version file: $(head -n 1 "$OMARCHY_PATH/version" 2>/dev/null || true)"
    else
        log_warn "não foi possível obter a versão do Omarchy; estrutura principal está presente."
    fi
}

check_commands() {
    log_info "Verificando comandos necessários..."

    local required_commands=(
        "bash"
        "sudo"
        "pacman"
        "systemctl"
        "git"
        "curl"
        "hyprland"
        "hyprctl"
    )

    local missing=false

    for command_name in "${required_commands[@]}"; do
        if has_command "$command_name"; then
            log_ok "$command_name"
        else
            log_error "comando ausente: $command_name"
            missing=true
        fi
    done

    if [[ "$missing" == true ]]; then
        log_info "alguns pacotes podem ser instalados pelos scripts individuais quando aplicável."
    fi
}

check_systemd() {
    log_info "Verificando systemd..."

    if [[ ! -d /run/systemd/system ]]; then
        log_error "systemd não está executando como PID 1."
        return
    fi

    if ! has_command systemctl; then
        log_error "systemctl não encontrado."
        return
    fi

    log_ok "systemd ativo."
}

check_wayland_session() {
    log_info "Verificando sessão gráfica..."

    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        log_ok "sessão Wayland detectada: $WAYLAND_DISPLAY"
        return
    fi

    if [[ -n "${XDG_SESSION_TYPE:-}" && "${XDG_SESSION_TYPE}" == "wayland" ]]; then
        log_ok "sessão Wayland detectada via XDG_SESSION_TYPE."
        return
    fi

    log_warn "nenhuma sessão Wayland ativa foi detectada."
    log_info "isso não impede o preflight; o instalador pode ser executado fora da sessão gráfica."
}

check_sudo_access() {
    log_info "Verificando disponibilidade do sudo..."

    if ! has_command sudo; then
        log_error "sudo não encontrado."
        return
    fi

    # Deliberately do not run "sudo -v" or any privileged command here.
    log_ok "sudo disponível (a senha será solicitada somente quando uma etapa privilegiada for necessária)."
}

check_pacman_database() {
    log_info "Verificando pacman..."

    if ! has_command pacman; then
        log_error "pacman não encontrado."
        return
    fi

    if [[ ! -r /var/lib/pacman/local ]]; then
        log_error "banco local do pacman não está acessível."
        return
    fi

    log_ok "pacman e banco local acessíveis."
}

check_disk_space() {
    log_info "Verificando espaço em disco..."

    local available_kb
    available_kb="$(df -Pk "$HOME" | awk 'NR==2 {print $4}')"

    if [[ ! "$available_kb" =~ ^[0-9]+$ ]]; then
        log_warn "não foi possível determinar o espaço livre em $HOME."
        return
    fi

    # Noctalia is built from source during installation. Keep this as a
    # conservative preflight warning rather than a hard failure.
    local available_gb=$((available_kb / 1024 / 1024))

    log_info "espaço livre em HOME: ${available_gb} GiB"

    if (( available_gb < 3 )); then
        log_warn "menos de 3 GiB livres; o build do Noctalia pode não ter espaço suficiente."
    else
        log_ok "espaço livre parece suficiente para o build."
    fi
}

check_project_layout() {
    log_info "Verificando estrutura do projeto..."

    local required_paths=(
        "$CONFIG_DIR"
        "$CONFIG_DIR/hypr"
        "$CONFIG_DIR/kitty"
        "$CONFIG_DIR/noctalia"
        "$CONFIG_DIR/rofi"
        "$ASSETS_DIR"
        "$ASSETS_DIR/wallpapers"
        "$ASSETS_DIR/plymouth"
        "$INSTALL_DIR"
        "$ROOT_DIR/plymouth/lucoa"
        "$ROOT_DIR/noctalia"
        "$NOCTALIA_PATCH"
    )

    local missing=false

    for required_path in "${required_paths[@]}"; do
        if [[ ! -e "$required_path" ]]; then
            log_error "item do projeto ausente: $required_path"
            missing=true
        fi
    done

    if [[ "$missing" == true ]]; then
        return
    fi

    log_ok "estrutura principal do projeto está completa."
}

check_config_files() {
    log_info "Verificando arquivos de configuração esperados..."

    local required_files=(
        "$CONFIG_DIR/hypr/autostart.lua"
        "$CONFIG_DIR/hypr/bindings.lua"
        "$CONFIG_DIR/hypr/hyprland.lua"
        "$CONFIG_DIR/hypr/input.lua"
        "$CONFIG_DIR/hypr/looknfeel.lua"
        "$CONFIG_DIR/hypr/monitors.lua"
        "$CONFIG_DIR/kitty/current-theme.conf"
        "$CONFIG_DIR/kitty/kitty.conf"
        "$CONFIG_DIR/noctalia/bar.toml"
        "$CONFIG_DIR/rofi/config.rasi"
        "$ROOT_DIR/plymouth/lucoa/omarchy.plymouth"
        "$ROOT_DIR/plymouth/lucoa/omarchy.script"
    )

    local missing=false

    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "arquivo de configuração ausente: $file"
            missing=true
        fi
    done

    if [[ "$missing" == true ]]; then
        return
    fi

    log_ok "arquivos de configuração esperados estão presentes."
}

check_plymouth_support() {
    log_info "Verificando Plymouth/Limine..."

    local required_commands=(
        "plymouth-set-default-theme"
        "limine-mkinitcpio"
        "limine-update"
    )

    local missing=false

    for command_name in "${required_commands[@]}"; do
        if has_command "$command_name"; then
            log_ok "$command_name"
        else
            log_error "comando necessário para Plymouth ausente: $command_name"
            missing=true
        fi
    done

    if [[ ! -d /usr/share/plymouth/themes/omarchy ]]; then
        log_error "tema Plymouth do Omarchy não encontrado em /usr/share/plymouth/themes/omarchy"
        missing=true
    fi

    if [[ "$missing" == true ]]; then
        return
    fi

    log_ok "Plymouth/Limine compatíveis com o instalador detectados."
}

check_hyprland_runtime() {
    log_info "Verificando Hyprland..."

    if ! has_command hyprland; then
        log_error "Hyprland não encontrado."
        return
    fi

    if ! has_command hyprctl; then
        log_error "hyprctl não encontrado."
        return
    fi

    if [[ "$VERBOSE" == true ]]; then
        local version
        version="$(version_of hyprland --version)"
        [[ -n "$version" ]] && log_info "Hyprland: $version"
    fi

    if has_command hyprctl; then
        if hyprctl version >/dev/null 2>&1; then
            log_ok "Hyprland responde via hyprctl."
        else
            log_warn "hyprctl existe, mas nenhuma instância acessível do Hyprland foi detectada."
        fi
    fi
}

check_optional_versions() {
    [[ "$VERBOSE" == true ]] || return 0

    echo
    log_info "Informações adicionais:"

    if has_command pacman; then
        log_info "pacman: $(pacman --version | head -n 1)"
    fi

    if has_command bash; then
        log_info "bash: $BASH_VERSION"
    fi

    if has_command git; then
        log_info "git: $(git --version)"
    fi

    if has_command meson; then
        log_info "meson: $(meson --version | head -n 1)"
    else
        log_info "meson: ainda não instalado (Noctalia installer providencia)."
    fi

    if has_command just; then
        log_info "just: $(just --version | head -n 1)"
    else
        log_info "just: ainda não instalado (Noctalia installer providencia)."
    fi

    if has_command gcc; then
        log_info "gcc: $(gcc --version | head -n 1)"
    else
        log_info "gcc: ainda não instalado (Noctalia installer providencia)."
    fi
}

print_summary() {
    echo
    echo "============================================================"
    echo "Lucoa Omarchy — CHECK"
    echo "============================================================"

    if (( ERRORS == 0 )); then
        log_ok "preflight concluído sem erros."
    else
        log_error "preflight encontrou $ERRORS erro(s)."
    fi

    if (( WARNINGS > 0 )); then
        log_warn "preflight encontrou $WARNINGS aviso(s)."
    else
        log_ok "nenhum aviso."
    fi

    echo
    if (( ERRORS > 0 )); then
        echo "Resultado: NÃO PROSSIGA com o install.sh ainda."
        return 1
    fi

    echo "Resultado: ambiente apto para o instalador."
    echo
    echo "Este script não alterou o sistema."
}

main() {
    case "${1:-}" in
        "")
            ;;
        --verbose)
            VERBOSE=true
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

    echo "==> Lucoa Omarchy — preflight"
    echo "    Root do projeto: $ROOT_DIR"
    echo "    Omarchy: $OMARCHY_PATH"
    echo "    Modo: somente leitura"

    check_user
    check_os
    check_omarchy
    check_commands
    check_systemd
    check_wayland_session
    check_sudo_access
    check_pacman_database
    check_disk_space
    check_project_layout
    check_config_files
    check_plymouth_support
    check_hyprland_runtime
    check_optional_versions
    print_summary
}

main "$@"
