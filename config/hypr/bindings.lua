-- ╔══════════════════════════════════════════════════════════════╗
-- ║ 🐉 LUCOA KEYBINDS                                             ║
-- ║ Classic Omarchy muscle memory                                 ║
-- ╚══════════════════════════════════════════════════════════════╝

-- Compatibility version:
-- Some Omarchy releases do not provide o.rebind().
-- We therefore remove conflicting defaults with hl.unbind()
-- and then add our preferred binding with o.bind().

-- ==============================================================
-- 🐉 CORE WINDOWS
-- ==============================================================

-- SUPER + C → close
hl.unbind("SUPER + C")
o.bind(
  "SUPER + C",
  "Close window",
  hl.dsp.window.close()
)

-- SUPER + Q → Kitty
hl.unbind("SUPER + Q")
o.bind(
  "SUPER + Q",
  "Kitty terminal",
  { launch = "kitty" }
)

-- SUPER + F → fullscreen
hl.unbind("SUPER + F")
o.bind(
  "SUPER + F",
  "Fullscreen",
  hl.dsp.window.fullscreen({ mode = "fullscreen" })
)

-- SUPER + T → floating
hl.unbind("SUPER + T")
o.bind(
  "SUPER + T",
  "Toggle floating",
  hl.dsp.window.float({ action = "toggle" })
)

-- SUPER + P → pseudo
hl.unbind("SUPER + P")
o.bind(
  "SUPER + P",
  "Pseudo window",
  hl.dsp.window.pseudo()
)

-- ==============================================================
-- 💜 APPS
-- ==============================================================

-- SUPER + R → Omarchy application launcher
hl.bind("SUPER + R", hl.dsp.exec_cmd("rofi -show drun"), {
  description = "Abrir Rofi"
})

-- Keep these classic app shortcuts.
o.bind(
  "SUPER + B",
  "Browser",
  { omarchy = "browser" }
)

o.bind(
  "SUPER + E",
  "File manager",
  { omarchy = "nautilus" }
)

o.bind(
  "SUPER + N",
  "Editor",
  { omarchy = "editor" }
)

-- SUPER + SHIFT + R → reload
hl.unbind("SUPER + SHIFT + R")
o.bind(
  "SUPER + SHIFT + R",
  "Reload Hyprland",
  "hyprctl reload"
)

-- ==============================================================
-- 🎯 FOCUS
-- ==============================================================

hl.unbind("SUPER + LEFT")
o.bind(
  "SUPER + LEFT",
  "Focus left",
  hl.dsp.focus({ direction = "l" })
)

hl.unbind("SUPER + RIGHT")
o.bind(
  "SUPER + RIGHT",
  "Focus right",
  hl.dsp.focus({ direction = "r" })
)

hl.unbind("SUPER + UP")
o.bind(
  "SUPER + UP",
  "Focus up",
  hl.dsp.focus({ direction = "u" })
)

hl.unbind("SUPER + DOWN")
o.bind(
  "SUPER + DOWN",
  "Focus down",
  hl.dsp.focus({ direction = "d" })
)

-- ==============================================================
-- 🔢 WORKSPACES
-- ==============================================================

for workspace = 1, 9 do
  local key = tostring(workspace)

  hl.unbind("SUPER + " .. key)
  o.bind(
    "SUPER + " .. key,
    "Workspace " .. workspace,
    hl.dsp.focus({
      workspace = key
    })
  )

  hl.unbind("SUPER + SHIFT + " .. key)
  o.bind(
    "SUPER + SHIFT + " .. key,
    "Move window to workspace " .. workspace,
    hl.dsp.window.move({
      workspace = key
    })
  )
end

-- Workspace 10
hl.unbind("SUPER + 0")
o.bind(
  "SUPER + 0",
  "Workspace 10",
  hl.dsp.focus({
    workspace = "10"
  })
)

hl.unbind("SUPER + SHIFT + 0")
o.bind(
  "SUPER + SHIFT + 0",
  "Move window to workspace 10",
  hl.dsp.window.move({
    workspace = "10"
  })
)

-- ==============================================================
-- 🔄 WORKSPACE CYCLING
-- ==============================================================

hl.unbind("SUPER + TAB")
o.bind(
  "SUPER + TAB",
  "Next workspace",
  hl.dsp.focus({
    workspace = "e+1"
  })
)

hl.unbind("SUPER + SHIFT + TAB")
o.bind(
  "SUPER + SHIFT + TAB",
  "Previous workspace",
  hl.dsp.focus({
    workspace = "e-1"
  })
)

-- ==============================================================
-- 📐 RESIZE
-- ==============================================================

hl.unbind("SUPER + CTRL + LEFT")
o.bind(
  "SUPER + CTRL + LEFT",
  "Resize left",
  "hyprctl dispatch resizeactive -40 0"
)

hl.unbind("SUPER + CTRL + RIGHT")
o.bind(
  "SUPER + CTRL + RIGHT",
  "Resize right",
  "hyprctl dispatch resizeactive 40 0"
)

hl.unbind("SUPER + CTRL + UP")
o.bind(
  "SUPER + CTRL + UP",
  "Resize up",
  "hyprctl dispatch resizeactive 0 -40"
)

hl.unbind("SUPER + CTRL + DOWN")
o.bind(
  "SUPER + CTRL + DOWN",
  "Resize down",
  "hyprctl dispatch resizeactive 0 40"
)

-- ==============================================================
-- 🔒 SYSTEM
-- ==============================================================

hl.unbind("SUPER + L")
o.bind(
  "SUPER + L",
  "Lock screen",
  "omarchy-lock-screen"
)

hl.unbind("SUPER + SHIFT + S")
o.bind(
  "SUPER + SHIFT + S",
  "Screenshot",
  "omarchy-cmd-screenshot"
)

-- SHIFT + Z → Lucoa area screenshot
hl.unbind("SHIFT + Z")
hl.bind(
  "SHIFT + Z",
  hl.dsp.exec_cmd("~/.local/bin/lucoa-screenshot"),
  {
    description = "Lucoa screenshot"
  }
)
-- ==============================================================
-- 🔊 MEDIA
-- ==============================================================
-- Omarchy's default media bindings are intentionally left alone.
-- ==============================================================
