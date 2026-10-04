-- ╔══════════════════════════════════════════════════════════════╗
-- ║ 🐉 LUCOA HYPRLAND                                               ║
-- ║ Omarchy defaults + Lucoa overrides                              ║
-- ╚══════════════════════════════════════════════════════════════╝

dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Keep Omarchy's default bindings enabled.
-- Our bindings.lua removes/replaces only the shortcuts we customize.
--
require("default.hypr.helpers")

local require_optional = require("default.hypr.require_optional")

-- Omarchy defaults, sem o autostart do Omarchy Shell
if _G.omarchy_default_bindings ~= false then
  require("default.hypr.bindings.media")
  require("default.hypr.bindings.clipboard")
  require("default.hypr.bindings.tiling")
  require("default.hypr.bindings.utilities")
  require("default.hypr.bindings.voxtype")
  require_optional.module("default.hypr.bindings.applications")
end

require("default.hypr.envs")
require("default.hypr.looknfeel")
require("default.hypr.input")
require("default.hypr.windows")

-- Tema atual do Omarchy
require_optional.module("omarchy.current.theme.hyprland")

require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

require("default.hypr.toggles")

hl.on("hyprland.start", function()
  hl.exec_cmd("noctalia")
end)
