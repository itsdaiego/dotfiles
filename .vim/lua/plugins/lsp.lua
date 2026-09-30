-- Native Neovim LSP, completion, formatting, and diagnostics.
-- CoC must stay absent: only one language client may attach to a buffer.
return {
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
    opts = {
      ensure_installed = {
        "bashls", "clangd", "cssls", "gopls", "html", "jsonls", "lua_ls",
        "pyright", "rust_analyzer", "ts_ls", "yamlls",
      },
      automatic_enable = false,
    },
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "saghen/blink.cmp" },
    config = function()
      local capabilities = require("blink.cmp").get_lsp_capabilities()
      local servers = {
        bashls = {},
        clangd = { cmd = { "/Library/Developer/CommandLineTools/usr/bin/clangd" } },
        cssls = {},
        gopls = {
          settings = {
            gopls = {
              completeUnimported = true,
              usePlaceholders = true,
              analyses = { unusedparams = true, shadow = true },
              staticcheck = true,
            },
          },
        },
        html = {},
        jsonls = {},
        lua_ls = { settings = { Lua = { diagnostics = { globals = { "vim" } } } } },
        pyright = {},
        rust_analyzer = {},
        ts_ls = {},
        yamlls = {},
      }

      vim.opt.signcolumn = "yes"
      vim.opt.updatetime = 300
      vim.diagnostic.config({
        severity_sort = true,
        underline = true,
        update_in_insert = false,
        virtual_text = false,
        float = { border = "rounded", focusable = false, source = "if_many" },
      })

      local diagnostics = vim.api.nvim_create_augroup("NativeLspDiagnostics", { clear = true })
      vim.api.nvim_create_autocmd("CursorHold", {
        group = diagnostics,
        callback = function(event)
          local cursor = vim.api.nvim_win_get_cursor(0)
          if #vim.diagnostic.get(event.buf, { lnum = cursor[1] - 1 }) > 0 then
            vim.diagnostic.open_float(event.buf, { scope = "cursor", focus = false })
          end
        end,
      })

      local function code_action(kind, apply)
        return function()
          vim.lsp.buf.code_action({
            apply = apply,
            context = { only = { kind } },
          })
        end
      end

      local group = vim.api.nvim_create_augroup("NativeLspKeymaps", { clear = true })
      vim.api.nvim_create_autocmd("LspAttach", {
        group = group,
        callback = function(event)
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = event.buf, silent = true, desc = desc })
          end

          map("n", "gd", vim.lsp.buf.definition, "LSP definition")
          map("n", "gy", vim.lsp.buf.type_definition, "LSP type definition")
          map("n", "gi", vim.lsp.buf.implementation, "LSP implementation")
          map("n", "gr", vim.lsp.buf.references, "LSP references")
          map("n", "K", vim.lsp.buf.hover, "LSP hover")
          map("n", "gl", function()
            vim.diagnostic.open_float(event.buf, { scope = "cursor", focus = false })
          end, "Line diagnostic")
          map("n", "<leader>rn", vim.lsp.buf.rename, "LSP rename")
          map({ "n", "x" }, "<leader>a", vim.lsp.buf.code_action, "LSP code action")
          map("n", "<leader>ac", vim.lsp.buf.code_action, "Cursor code action")
          map("n", "<leader>as", code_action("source", false), "Source code action")
          map("n", "<leader>qf", code_action("source.fixAll", true), "Fix all")
          map("n", "<leader>re", code_action("refactor", false), "Refactor code action")
          map({ "n", "x" }, "<leader>r", code_action("refactor", false), "Refactor selected")
          map("n", "<leader>cl", vim.lsp.codelens.run, "Run code lens")

          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client.server_capabilities.documentHighlightProvider then
            local highlights = vim.api.nvim_create_augroup("NativeLspHighlights" .. event.buf, { clear = true })
            vim.api.nvim_create_autocmd("CursorHold", {
              group = highlights,
              buffer = event.buf,
              callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd("CursorMoved", {
              group = highlights,
              buffer = event.buf,
              callback = vim.lsp.buf.clear_references,
            })
          end
          if client and client.server_capabilities.inlayHintProvider then
            vim.lsp.inlay_hint.enable(false, { bufnr = event.buf })
          end
          if client and client.server_capabilities.codeLensProvider then
            local lenses = vim.api.nvim_create_augroup("NativeLspCodeLens" .. event.buf, { clear = true })
            vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
              group = lenses,
              buffer = event.buf,
              callback = vim.lsp.codelens.refresh,
            })
          end
        end,
      })

      for name, config in pairs(servers) do
        config.capabilities = capabilities
        vim.lsp.config(name, config)
        vim.lsp.enable(name)
      end

      vim.keymap.set("n", "<space>a", vim.diagnostic.setqflist, { silent = true, desc = "Diagnostics" })
      vim.keymap.set("n", "<space>e", "<cmd>Mason<CR>", { silent = true, desc = "Language tools" })
      vim.keymap.set("n", "<space>c", "<cmd>Telescope commands<CR>", { silent = true, desc = "Commands" })
      vim.keymap.set("n", "<space>o", "<cmd>AerialToggle!<CR>", { silent = true, desc = "Document outline" })
      vim.keymap.set("n", "<space>s", "<cmd>Telescope lsp_document_symbols<CR>", { silent = true, desc = "Document symbols" })
      vim.keymap.set("n", "<space>j", function() vim.diagnostic.jump({ count = 1, float = true }) end, { silent = true, desc = "Next diagnostic" })
      vim.keymap.set("n", "<space>k", function() vim.diagnostic.jump({ count = -1, float = true }) end, { silent = true, desc = "Previous diagnostic" })
      vim.keymap.set("n", "<space>p", "<cmd>Telescope resume<CR>", { silent = true, desc = "Resume picker" })
      vim.api.nvim_create_user_command("OR", code_action("source.organizeImports", true), {})
    end,
  },
  {
    "saghen/blink.cmp",
    version = "v1.*",
    opts = {
      keymap = {
        preset = "default",
        ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<Tab>"] = { "select_next", "fallback" },
        ["<S-Tab>"] = { "select_prev", "fallback" },
      },
      completion = { documentation = { auto_show = true } },
      signature = { enabled = true },
    },
  },
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = {
      formatters_by_ft = {
        c = { "clang_format" },
        cpp = { "clang_format" },
        go = { "gofmt" },
        javascript = { "prettierd", "prettier" },
        json = { "prettierd", "prettier" },
        lua = { "stylua" },
        python = { "ruff_format", "black" },
        rust = { "rustfmt" },
        typescript = { "prettierd", "prettier" },
        yaml = { "prettierd", "prettier" },
      },
      format_on_save = { timeout_ms = 1000, lsp_format = "fallback" },
    },
    init = function()
      vim.api.nvim_create_user_command("Format", function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end, {})
    end,
  },
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufNewFile", "BufWritePost" },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = { python = { "ruff" }, sh = { "shellcheck" } }
      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
        group = vim.api.nvim_create_augroup("NativeLspLint", { clear = true }),
        callback = function(args)
          local linter = vim.bo[args.buf].filetype == "python" and "ruff"
            or vim.bo[args.buf].filetype == "sh" and "shellcheck"
          if linter and vim.fn.executable(linter) == 1 then
            lint.try_lint(linter)
          end
        end,
      })
    end,
  },
}
