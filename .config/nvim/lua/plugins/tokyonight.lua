return {
  "folke/tokyonight.nvim",
  lazy = true,
  opts = {
    style = "moon",
    transparent = true,
    styles = {
      sidebars = "transparent",
      floats = "transparent",
    },
    on_highlights = function(hl, c)
      hl.WinSeparator = { fg = c.fg_gutter, bold = true }
    end,
  },
}
