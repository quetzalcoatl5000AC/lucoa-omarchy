-- ╔══════════════════════════════════════════════════════════════╗
-- ║ 🐉 LUCOA LOOK & FEEL                                      ║
-- ║ WATER BALLOON • BIG OVERSHOOT • JIGGLE • SOFT             ║
-- ║ Hyprland 0.55+                                             ║
-- ╚══════════════════════════════════════════════════════════════╝
--
-- Objetivo:
--   • bastante overshoot
--   • várias oscilações decrescentes
--   • movimento macio
--   • sensação de balão de água
--   • troca de janela também elástica
--   • troca de workspace com wobble forte
--   • nada seco/metálico
--
-- IMPORTANTE:
--   Hyprland 0.55 usa Lua e suporta spring curves.
--   Não usamos decoration.wobble aqui porque o seu Hyprland 0.55
--   não aceita essa opção. O wobble visual vem das spring curves.


-- ==============================================================
-- 🌙 GENERAL
-- ==============================================================

hl.config({
  general = {
    gaps_in = 7,
    gaps_out = 12,
    border_size = 2,
    layout = "dwindle",
    resize_on_border = true,
    allow_tearing = false,

    col = {
      active_border = {
        colors = {
          "rgba(9b7edeff)",
          "rgba(63e6d7ff)",
          "rgba(72efddff)",
          "rgba(ff8fd8ff)",
          "rgba(ffd166ff)"
        },
        angle = 135
      },

      inactive_border = "rgba(6f4fa355)"
    }
  },

  -- ============================================================
  -- ✨ DECORATION
  -- ============================================================

  decoration = {
    rounding = 18,

    active_opacity = 0.74,
    inactive_opacity = 0.62,
    fullscreen_opacity = 1.0,

    shadow = {
      enabled = true,
      range = 24,
      render_power = 4,
      color = "rgba(00000078)"
    },

    blur = {
      enabled = true,
      size = 5,
      passes = 2,
      vibrancy = 0.30,
      noise = 0.018
    }
  },

  -- ============================================================
  -- 🌌 MISC
  -- ============================================================

  misc = {
    vrr = 0,
    disable_hyprland_logo = true,
    background_color = "rgba(15121fff)"
  },

  -- ============================================================
  -- 🖱️ CURSOR
  -- ============================================================

  cursor = {
    hide_on_key_press = true,
    hide_on_touch = true
  },

  -- ============================================================
  -- 🎞️ ANIMATION MASTER
  -- ============================================================

  animations = {
    enabled = true
  }
})


-- ==============================================================
-- 🫧 WATER BALLOON — PRINCIPAL
-- ==============================================================
-- Bastante movimento, mas ainda agradável no uso diário.

hl.curve("lucoaWater", {
  type = "spring",
  mass = 1.0,
  stiffness = 52,
  dampening = 3.2
})


-- ==============================================================
-- 💥 WATER BALLOON — EXTREME
-- ==============================================================
-- Curva mais solta para workspace e troca de foco.
-- Menos damping = mais rebote e mais oscilações.
-- Stiffness menor = sensação mais molinha.

hl.curve("lucoaWaterExtreme", {
  type = "spring",
  mass = 1.0,
  stiffness = 44,
  dampening = 2.8
})


-- ==============================================================
-- 🌸 WATER SOFT
-- ==============================================================
-- Usada em fechamento/sombra para não transformar tudo em gelatina.

hl.curve("lucoaWaterSoft", {
  type = "spring",
  mass = 1.0,
  stiffness = 72,
  dampening = 4.8
})


-- ==============================================================
-- 🎀 SILK
-- ==============================================================

hl.curve("lucoaSilk", {
  type = "bezier",
  points = {
    { 0.12, 0.76 },
    { 0.22, 1.00 }
  }
})


-- ==============================================================
-- 🌸 VELVET
-- ==============================================================

hl.curve("lucoaVelvet", {
  type = "bezier",
  points = {
    { 0.20, 0.90 },
    { 0.28, 1.00 }
  }
})


-- ==============================================================
-- 🌊 FLOAT
-- ==============================================================

hl.curve("lucoaFloat", {
  type = "bezier",
  points = {
    { 0.18, 0.88 },
    { 0.30, 1.02 }
  }
})


-- ==============================================================
-- 🌫️ FADE
-- ==============================================================

hl.curve("lucoaFade", {
  type = "bezier",
  points = {
    { 0.25, 0.46 },
    { 0.45, 0.94 }
  }
})


-- ==============================================================
-- 🐉 WINDOWS
-- ==============================================================
-- Movimento geral das janelas.
-- Spring + slide = janela entra, passa um pouco e assenta.

hl.animation({
  leaf = "windows",
  enabled = true,
  speed = 9,
  spring = "lucoaWater",
  style = "slide"
})


-- ==============================================================
-- 🌸 WINDOWS IN
-- ==============================================================
-- Entrada com bastante elasticidade.

hl.animation({
  leaf = "windowsIn",
  enabled = true,
  speed = 9,
  spring = "lucoaWater",
  style = "popin 76%"
})


-- ==============================================================
-- 🌙 WINDOWS OUT
-- ==============================================================

hl.animation({
  leaf = "windowsOut",
  enabled = true,
  speed = 7,
  spring = "lucoaWaterSoft",
  style = "popin 92%"
})


-- ==============================================================
-- 🫧 WINDOWS MOVE
-- ==============================================================
-- Drag / resize ainda com sensação líquida.

hl.animation({
  leaf = "windowsMove",
  enabled = true,
  speed = 7,
  spring = "lucoaWaterSoft"
})


-- ==============================================================
-- 🌸 LAYERS
-- ==============================================================

hl.animation({
  leaf = "layers",
  enabled = true,
  speed = 8,
  bezier = "lucoaSilk",
  style = "slide"
})

hl.animation({
  leaf = "layersIn",
  enabled = true,
  speed = 8,
  bezier = "lucoaVelvet",
  style = "popin 82%"
})

hl.animation({
  leaf = "layersOut",
  enabled = true,
  speed = 7,
  bezier = "lucoaFade",
  style = "fade"
})


-- ==============================================================
-- 🌫️ FADE
-- ==============================================================

hl.animation({
  leaf = "fade",
  enabled = true,
  speed = 6,
  bezier = "lucoaFade"
})

hl.animation({
  leaf = "fadeIn",
  enabled = true,
  speed = 7,
  bezier = "lucoaVelvet"
})

hl.animation({
  leaf = "fadeOut",
  enabled = true,
  speed = 5,
  bezier = "lucoaFade"
})


-- ==============================================================
-- 💥 TROCA DE JANELA ATIVA
-- ==============================================================
-- A troca de foco usa a spring EXTREME para dar aquele
-- "jiggle" visual sem precisar deformar a geometria da janela.

hl.animation({
  leaf = "fadeSwitch",
  enabled = true,
  speed = 8,
  spring = "lucoaWaterExtreme"
})


-- ==============================================================
-- 🌑 SHADOW NA TROCA DE FOCO
-- ==============================================================

hl.animation({
  leaf = "fadeShadow",
  enabled = true,
  speed = 8,
  spring = "lucoaWaterSoft"
})


-- ==============================================================
-- 🌫️ DIM INATIVO
-- ==============================================================

hl.animation({
  leaf = "fadeDim",
  enabled = true,
  speed = 8,
  bezier = "lucoaFade"
})


-- ==============================================================
-- 🫧 POPUPS / LAYERS
-- ==============================================================

hl.animation({
  leaf = "fadeLayers",
  enabled = true,
  speed = 7,
  bezier = "lucoaFade"
})

hl.animation({
  leaf = "fadeLayersIn",
  enabled = true,
  speed = 7,
  bezier = "lucoaVelvet"
})

hl.animation({
  leaf = "fadeLayersOut",
  enabled = true,
  speed = 6,
  bezier = "lucoaFade"
})

hl.animation({
  leaf = "fadePopups",
  enabled = true,
  speed = 6,
  bezier = "lucoaFade"
})

hl.animation({
  leaf = "fadePopupsIn",
  enabled = true,
  speed = 7,
  bezier = "lucoaVelvet"
})

hl.animation({
  leaf = "fadePopupsOut",
  enabled = true,
  speed = 5,
  bezier = "lucoaFade"
})


-- ==============================================================
-- 💜 BORDER
-- ==============================================================

hl.animation({
  leaf = "border",
  enabled = true,
  speed = 8,
  bezier = "lucoaSilk"
})

hl.animation({
  leaf = "borderangle",
  enabled = true,
  speed = 10,
  bezier = "lucoaFloat",
  style = "once"
})


-- ==============================================================
-- 🪄 WORKSPACES — MUITO WOBBLE
-- ==============================================================
-- A principal mudança:
-- workspace deixa de usar a Bezier Float e passa a usar
-- uma spring bem mais solta.
--
-- O slidefade continua porque dá o deslocamento lateral;
-- a spring é que faz o overshoot + rebote.

hl.animation({
  leaf = "workspaces",
  enabled = true,
  speed = 9,
  spring = "lucoaWaterExtreme",
  style = "slidefade 25%"
})

hl.animation({
  leaf = "workspacesIn",
  enabled = true,
  speed = 9,
  spring = "lucoaWaterExtreme",
  style = "slidefade 25%"
})

hl.animation({
  leaf = "workspacesOut",
  enabled = true,
  speed = 8,
  spring = "lucoaWaterExtreme",
  style = "slidefade 25%"
})


-- ==============================================================
-- 🌌 SPECIAL WORKSPACE
-- ==============================================================
-- Mesmo comportamento elástico nos workspaces especiais.

hl.animation({
  leaf = "specialWorkspace",
  enabled = true,
  speed = 9,
  spring = "lucoaWaterExtreme",
  style = "slidefadevert 22%"
})

hl.animation({
  leaf = "specialWorkspaceIn",
  enabled = true,
  speed = 9,
  spring = "lucoaWaterExtreme",
  style = "slidefadevert 22%"
})

hl.animation({
  leaf = "specialWorkspaceOut",
  enabled = true,
  speed = 8,
  spring = "lucoaWaterExtreme",
  style = "slidefadevert 22%"
})


-- ==============================================================
-- 🌌 DPMS
-- ==============================================================

hl.animation({
  leaf = "fadeDpms",
  enabled = true,
  speed = 8,
  bezier = "lucoaFade"
})


-- ==============================================================
-- 💜 LUCOA PALETTE
-- ==============================================================
-- Purple    #9b7ede
-- Aqua      #63e6d7
-- Cyan      #72efdd
-- Pink      #ff8fd8
-- Gold      #ffd166
-- Midnight  #15121f


-- ==============================================================
-- 🫧 WATER BALLOON PHYSICS
-- ==============================================================
-- PRINCIPAL:
--   mass       = 1.0
--   stiffness  = 52
--   dampening  = 3.2
--
-- EXTREME:
--   mass       = 1.0
--   stiffness  = 44
--   dampening  = 2.8
--
-- SOFT:
--   mass       = 1.0
--   stiffness  = 72
--   dampening  = 4.8
--
-- Resultado esperado:
--   • overshoot forte
--   • vários rebotes
--   • amplitude decrescente
--   • movimento macio
--   • troca de foco elástica
--   • abertura elástica
--   • troca de workspace com wobble visível
--   • fechamento mais controlado
--
-- Limitação importante:
--   spring curve NÃO deforma fisicamente as bordas da janela.
--   O wobble geométrico real é outro recurso (decoration.wobble),
--   que não entra neste arquivo por compatibilidade com o seu 0.55.
