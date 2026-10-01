return {
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      local config_path = vim.fn.stdpath("config") .. "/.markdownlint-cli2.yaml"

      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.markdown = opts.linters_by_ft.markdown or { "markdownlint-cli2" }

      opts.linters = opts.linters or {}
      opts.linters["markdownlint-cli2"] = {
        args = { "--config", config_path, "-" },
      }

      opts.linters["prettier_markdown"] = {
        args = { "--config", config_path, "--print-width", "120" },
      }
    end,
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters = opts.formatters or {}
      opts.formatters.prettier_markdown = {
        command = "prettier",
        args = {
          "--stdin-filepath",
          "$FILENAME",
          "--print-width",
          "120",
          "--prose-wrap",
          "always",
        },
        stdin = true,
      }

      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.markdown = { "prettier_markdown" }
    end,
  },
}
