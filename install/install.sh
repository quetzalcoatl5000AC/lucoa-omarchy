#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Lucoa Omarchy — installation maestro
#
# Orquestra os instaladores individuais da release.
#
# Ordem:
#   1. Noctalia customizado
#   2. Kitty
#   3. Rofi
#   4. Plymouth
#   5. Hyprland
#
# O modo normal é seguro para uso standalone:
#   - roda o preflight;
#   - cria o backup persistente;
#   - instala cada etapa na ordem;
#   - deixa os rollbacks específicos para os instaladores individuais.
#
# Quando chamado pelo bootstrap, as variáveis:
#   LUCOA_INSTALL_SKIP_PREFLIGHT=1
#   LUCOA_INSTALL_SKIP_BACKUP=1
# evitam repetir as etapas que o bootstrap já executou.
#
# Uso:
#   ./install/install.sh
#   ./install/install.sh --check
#   ./install/install.sh --help
# ============================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="$ROOT_DIR/install"

CHECK_ONLY=false
FAILED_STEP=""

SKIP_PREFLIGHT="${LUCOA_INSTALL_SKIP_PREFLIGHT:-0}"
SKIP_BACKUP="${LUCOA_INSTALL_SKIP_BACKUP:-0}"

# ------------------------------------------------------------
# Cores — paleta Lucoa
# ------------------------------------------------------------
RESET=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[38;5;251m'
PINK=$'\033[38;5;205m'
HOT_PINK=$'\033[38;5;198m'
MAGENTA=$'\033[38;5;163m'
PURPLE=$'\033[38;5;135m'
LILAC=$'\033[38;5;183m'
WHITE=$'\033[38;5;255m'
GREEN=$'\033[38;5;120m'
YELLOW=$'\033[38;5;222m'
RED=$'\033[38;5;203m'
CYAN=$'\033[38;5;159m'

usage() {
    cat <<'USAGE'
Lucoa Omarchy — installation maestro

Uso:
  ./install/install.sh
  ./install/install.sh --check
  ./install/install.sh --help

Modos:
  --check       valida a estrutura e executa o CHECK de cada etapa
  -h, --help    mostra esta ajuda

Fluxo normal:
  preflight → backup → Noctalia → Kitty → Rofi → Plymouth → Hyprland

Variáveis internas:
  LUCOA_INSTALL_SKIP_PREFLIGHT=1
  LUCOA_INSTALL_SKIP_BACKUP=1

Essas variáveis são usadas pelo bootstrap para não repetir
o preflight e o backup já executados por ele.
USAGE
}

die() {
    printf '\n%b\n' "${RED}${BOLD}✗ ERRO:${RESET} ${WHITE}$1${RESET}" >&2
    exit 1
}

log_ok() {
    printf '%b\n' "${GREEN}✓${RESET} ${WHITE}$1${RESET}"
}

log_info() {
    printf '%b\n' "${CYAN}•${RESET} ${WHITE}$1${RESET}"
}

log_warn() {
    printf '%b\n' "${YELLOW}⚠${RESET} ${WHITE}$1${RESET}"
}

section() {
    printf '\n%b\n' "${HOT_PINK}${BOLD}╭─ $1${RESET}"
}

show_header() {
    clear 2>/dev/null || true

    printf '%b\n' "${MAGENTA}${BOLD}"
    cat <<'LUCOA'
      ╭──────────────────────────────────────────────────────╮
      │                                                      │
      │                 L U C O A   R I C E                 │
      │                                                      │
      │                 installation maestro                │
      │                                                      │
      ╰──────────────────────────────────────────────────────╯
LUCOA
    printf '%b\n' "${RESET}"
    printf '%b\n\n' "${LILAC}      “primeiro o motor, depois o resto do carro.”${RESET}"
}

finish_line() {
    printf '%b\n' "${MAGENTA}╰──────────────────────────────────────────────────────────${RESET}"
}

# ------------------------------------------------------------
# Argumentos
# ------------------------------------------------------------
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
    die "execute o maestro como usuário normal; os instaladores usam sudo quando necessário."
fi

if [[ "$SKIP_PREFLIGHT" != 0 && "$SKIP_PREFLIGHT" != 1 ]]; then
    die "LUCOA_INSTALL_SKIP_PREFLIGHT deve ser 0 ou 1."
fi

if [[ "$SKIP_BACKUP" != 0 && "$SKIP_BACKUP" != 1 ]]; then
    die "LUCOA_INSTALL_SKIP_BACKUP deve ser 0 ou 1."
fi

# ------------------------------------------------------------
# Tratamento de erro
# ------------------------------------------------------------
on_error() {
    local exit_code=$?
    trap - ERR

    printf '\n%b\n' "${RED}${BOLD}✗ A etapa falhou.${RESET}"

    if [[ -n "$FAILED_STEP" ]]; then
        printf '%b\n' "${DIM}  etapa: ${FAILED_STEP}${RESET}"
    fi

    printf '%b\n' "${DIM}  código: ${exit_code}${RESET}"
    printf '%b\n' "${YELLOW}⚠${RESET} ${WHITE}O backup persistente, quando já criado, permanece disponível.${RESET}"
    printf '%b\n' "${DIM}  Os instaladores individuais podem executar rollback próprio quando suportado.${RESET}"

    exit "$exit_code"
}

trap on_error ERR

# ------------------------------------------------------------
# Estrutura esperada
# ------------------------------------------------------------
declare -a INSTALLERS=(
    "noctalia.sh"
    "kitty.sh"
    "rofi.sh"
    "plymouth.sh"
    "hyprland.sh"
)

declare -a REQUIRED_TOP_LEVEL_DIRS=(
    "assets"
    "config"
    "noctalia"
    "plymouth"
)

declare -a REQUIRED_INSTALL_SCRIPTS=(
    "checks.sh"
    "backup.sh"
    "noctalia.sh"
    "kitty.sh"
    "rofi.sh"
    "plymouth.sh"
    "hyprland.sh"
)

validate_structure() {
    section "Validando a estrutura do instalador"

    [[ -d "$ROOT_DIR" ]] \
        || die "raiz do projeto não encontrada: $ROOT_DIR"

    [[ -d "$INSTALL_DIR" ]] \
        || die "diretório install/ não encontrado: $INSTALL_DIR"

    for dir in "${REQUIRED_TOP_LEVEL_DIRS[@]}"; do
        [[ -d "$ROOT_DIR/$dir" ]] \
            || die "diretório obrigatório ausente: $ROOT_DIR/$dir"

        log_ok "$dir/"
    done

    for script in "${REQUIRED_INSTALL_SCRIPTS[@]}"; do
        local path="$INSTALL_DIR/$script"

        [[ -f "$path" ]] \
            || die "instalador obrigatório ausente: $path"

        [[ -r "$path" ]] \
            || die "instalador obrigatório não pode ser lido: $path"

        # Chamamos os scripts com bash explicitamente, então o bit
        # executável não é requisito para a release.
        log_ok "install/$script"
    done

    [[ -f "$ROOT_DIR/noctalia/lucoa-water-balloon.patch" ]] \
        || die "patch do Noctalia ausente: $ROOT_DIR/noctalia/lucoa-water-balloon.patch"

    [[ -s "$ROOT_DIR/noctalia/lucoa-water-balloon.patch" ]] \
        || die "patch do Noctalia está vazio."

    log_ok "noctalia/lucoa-water-balloon.patch"
}

run_check_suite() {
    section "Executando CHECK de todas as etapas"

    FAILED_STEP="preflight geral"
    "$INSTALL_DIR/checks.sh"
    log_ok "preflight geral: OK."

    # backup.sh --check é somente leitura e confirma quais alvos
    # o pacote considera gerenciados.
    FAILED_STEP="backup --check"
    "$INSTALL_DIR/backup.sh" --check
    log_ok "backup --check: OK."

    for installer in "${INSTALLERS[@]}"; do
        FAILED_STEP="$installer --check"

        printf '\n%b\n' "${PURPLE}${BOLD}▸ $FAILED_STEP${RESET}"
        bash "$INSTALL_DIR/$installer" --check

        log_ok "$installer: CHECK OK."
    done

    FAILED_STEP=""
}

run_preflight_and_backup() {
    if [[ "$SKIP_PREFLIGHT" == 0 ]]; then
        section "Executando preflight"

        FAILED_STEP="preflight geral"
        "$INSTALL_DIR/checks.sh"
        log_ok "preflight concluído."
    else
        log_info "preflight geral já foi executado pelo bootstrap; pulando."
    fi

    if [[ "$SKIP_BACKUP" == 0 ]]; then
        section "Criando backup"

        FAILED_STEP="backup"
        "$INSTALL_DIR/backup.sh"
        log_ok "backup persistente criado."
    else
        log_info "backup já foi criado pelo bootstrap; pulando."
    fi

    FAILED_STEP=""
}

run_installer() {
    local file="$1"
    local label="$2"

    FAILED_STEP="$label"

    section "Instalando $label"
    bash "$INSTALL_DIR/$file"

    log_ok "$label concluído."
    FAILED_STEP=""
}

# ------------------------------------------------------------
# Execução
# ------------------------------------------------------------
show_header
validate_structure

if [[ "$CHECK_ONLY" == true ]]; then
    run_check_suite

    printf '\n%b\n' "${GREEN}${BOLD}╭──────────────────────────────────────────────────────────╮${RESET}"
    printf '%b\n' "${GREEN}${BOLD}│${RESET} ${WHITE}${BOLD}✓ TODOS OS CHECKS CONCLUÍDOS.${RESET}"
    printf '%b\n' "${GREEN}${BOLD}│${RESET} ${DIM}Nenhuma configuração foi instalada.${RESET}"
    printf '%b\n' "${GREEN}${BOLD}╰──────────────────────────────────────────────────────────╯${RESET}"
    exit 0
fi

printf '%b\n' "${DIM}Projeto : ${WHITE}$ROOT_DIR${RESET}"
printf '%b\n' "${DIM}Fluxo  : ${WHITE}Noctalia → Kitty → Rofi → Plymouth → Hyprland${RESET}"

run_preflight_and_backup

run_installer "noctalia.sh" "Noctalia customizado"
run_installer "kitty.sh" "Kitty"
run_installer "rofi.sh" "Rofi"
run_installer "plymouth.sh" "Plymouth"
run_installer "hyprland.sh" "Hyprland"

finish_line

printf '\n%b\n' "${PINK}${BOLD}╭──────────────────────────────────────────────────────────╮${RESET}"
printf '%b\n' "${PINK}${BOLD}│${RESET} ${WHITE}${BOLD}✓ LUCOA OMARCHY INSTALADO.${RESET}"
printf '%b\n' "${PINK}${BOLD}│${RESET} ${DIM}Todos os instaladores da release foram executados.${RESET}"
printf '%b\n' "${PINK}${BOLD}│${RESET} ${DIM}Hyprland foi aplicado por último.${RESET}"
printf '%b\n' "${PINK}${BOLD}╰──────────────────────────────────────────────────────────╯${RESET}"
printf '\n%b\n' "${LILAC}      feito com carinho, caos controlado e bastante rosa. 💗${RESET}"
