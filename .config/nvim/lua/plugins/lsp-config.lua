return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        tsc = { mason = false },
        eslint = {
          -- Scoped to the santander monorepo only.
          --
          -- pnpm keeps packages in an isolated store and doesn't link a
          -- resolvable node_modules/eslint there (eslint + its plugins are
          -- transitive deps), so the LSP reports "Unable to find ESLint
          -- library" and then "Cannot find module '@typescript-eslint/...'".
          -- The CLI works because pnpm's bin shim exposes the flat virtual
          -- store via NODE_PATH; we replicate that for the language server.
          --
          -- cmd-as-function receives the resolved config (incl. root_dir), so
          -- NODE_PATH is injected ONLY when the server roots inside santander.
          -- Every other project spawns with an untouched environment.
          cmd = function(dispatchers, config)
            local bin = vim.fn.exepath("vscode-eslint-language-server")
            if bin == "" then
              bin = "vscode-eslint-language-server"
            end
            local env
            local root = config and config.root_dir
            local santander = vim.fn.expand("~/code/santander")
            if root and vim.startswith(root, santander) then
              local store = santander .. "/node_modules/.pnpm/node_modules"
              if vim.fn.isdirectory(store) == 1 then
                env = { NODE_PATH = store }
              end
            end
            return vim.lsp.rpc.start({ bin, "--stdio" }, dispatchers, { env = env })
          end,
        },
      },
    },
  },
}
