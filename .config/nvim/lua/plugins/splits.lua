return {
  "smart-splits-nvim/smart-splits.nvim",
  lazy = false,
  build = "./kitty/install-kittens.bash",
  dependencies = { "smart-splits-nvim/backend-ghostty" },
  config = function()
    require("smart-splits").setup({})
    if vim.env.TERM_PROGRAM == "ghostty" then
      require("ghostty-smart-splits").setup()
    end
  end,
  keys = {
    {
      "<C-h>",
      function()
        require("smart-splits").move_cursor_left()
      end,
      desc = "Move to left split",
    },
    {
      "<C-j>",
      function()
        require("smart-splits").move_cursor_down()
      end,
      desc = "Move to split below",
    },
    {
      "<C-k>",
      function()
        require("smart-splits").move_cursor_up()
      end,
      desc = "Move to split above",
    },
    {
      "<C-l>",
      function()
        require("smart-splits").move_cursor_right()
      end,
      desc = "Move to right split",
    },
  },
}
