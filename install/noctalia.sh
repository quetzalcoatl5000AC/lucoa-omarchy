#!/usr/bin/env bash
set -euo pipefail

NOCTALIA_VERSION="v5.0.1"
NOCTALIA_REPO="https://github.com/noctalia-dev/noctalia.git"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH_FILE="$ROOT_DIR/noctalia/lucoa-water-balloon.patch"

BUILD_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/lucoa-omarchy"
SRC_DIR="$BUILD_ROOT/noctalia-$NOCTALIA_VERSION"

CUSTOM_NOCTALIA="/usr/local/bin/noctalia"
CUSTOM_ASSETS="/usr/local/share/noctalia/assets"

echo "==> Lucoa Noctalia installer"
echo "    Version: $NOCTALIA_VERSION"

if [[ ! -f "$PATCH_FILE" ]]; then
    echo
    echo "ERRO: patch não encontrado:"
    echo "  $PATCH_FILE"
    exit 1
fi

echo
echo "==> Instalando dependências de build..."

sudo pacman -S --needed --noconfirm \
    git \
    meson \
    ninja \
    gcc \
    just \
    wayland \
    wayland-protocols \
    libglvnd \
    freetype2 \
    fontconfig \
    cairo \
    pango \
    harfbuzz \
    libxkbcommon \
    glib2 \
    libsecret \
    libsodium \
    sdbus-cpp \
    libpipewire \
    wireplumber \
    polkit \
    pam \
    curl \
    libwebp \
    libjxl \
    libsndfile \
    librsvg \
    libqalculate \
    libxml2 \
    md4c \
    tomlplusplus \
    libical \
    nlohmann-json \
    stb \
    jemalloc

mkdir -p "$BUILD_ROOT"

echo
echo "==> Preparando fonte limpa do Noctalia $NOCTALIA_VERSION..."

rm -rf "$SRC_DIR"

git clone \
    --depth 1 \
    --branch "$NOCTALIA_VERSION" \
    "$NOCTALIA_REPO" \
    "$SRC_DIR"

cd "$SRC_DIR"

echo
echo "==> Aplicando patch Lucoa Water Balloon..."

git apply --check "$PATCH_FILE"
git apply "$PATCH_FILE"

echo
echo "==> Configurando build release..."

just configure release

echo
echo "==> Compilando Noctalia..."

just build release

echo
echo "==> Instalando Noctalia em /usr/local..."

sudo just install release

echo
echo "==> Validando instalação..."

if [[ ! -x "$CUSTOM_NOCTALIA" ]]; then
    echo
    echo "ERRO: Noctalia customizado não foi encontrado:"
    echo "  $CUSTOM_NOCTALIA"
    exit 1
fi

if [[ ! -d "$CUSTOM_ASSETS" ]]; then
    echo
    echo "ERRO: assets do Noctalia não foram encontrados:"
    echo "  $CUSTOM_ASSETS"
    exit 1
fi

echo
echo "✓ Noctalia customizado instalado:"
echo "  $CUSTOM_NOCTALIA"

echo
echo "==> Versão instalada:"
"$CUSTOM_NOCTALIA" --version

echo
echo "==> Assets:"
echo "  $CUSTOM_ASSETS"

echo
echo "==> Limpando source temporário..."

rm -rf "$SRC_DIR"

echo
echo "✓ Noctalia Lucoa instalado com sucesso."
