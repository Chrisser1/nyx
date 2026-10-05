local function rgb(hex) return "rgb(" .. hex .. ")" end

local primary = rgb("{{colors.primary.default.hex_stripped}}")
local secondary = rgb("{{colors.secondary.default.hex_stripped}}")
local error = rgb("{{colors.error.default.hex_stripped}}")
local surface = rgb("{{colors.surface.default.hex_stripped}}")
local inactive = rgb("{{colors.outline_variant.default.hex_stripped}}")
local on_secondary = rgb("{{colors.on_secondary.default.hex_stripped}}")
local on_surface = rgb("{{colors.on_surface.default.hex_stripped}}")
local on_error = rgb("{{colors.on_error.default.hex_stripped}}")

hl.config({
  general = {
    col = {
      active_border = primary,
      inactive_border = inactive,
    },
  },
  group = {
    col = {
      border_active = secondary,
      border_inactive = inactive,
      border_locked_active = error,
      border_locked_inactive = inactive,
    },
    groupbar = {
      col = {
        active = secondary,
        inactive = surface,
        locked_active = error,
        locked_inactive = surface,
      },
      text_color = on_secondary,
      text_color_inactive = on_surface,
      text_color_locked_active = on_error,
      text_color_locked_inactive = on_surface,
    },
  },
})
