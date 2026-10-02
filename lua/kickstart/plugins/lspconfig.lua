---@type LazySpec
return {
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        -- Load lazy.nvim's annotations (LazySpec, LazyPluginSpec, ...) so the
        -- `---@type LazySpec` headers on the plugin spec files resolve.
        { path = "lazy.nvim", words = { "LazySpec" } },
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      { "mason-org/mason.nvim", opts = {} },
      "mason-org/mason-lspconfig.nvim",
      "WhoIsSethDaniel/mason-tool-installer.nvim",

      { "j-hui/fidget.nvim", opts = {} },

      "saghen/blink.cmp",
    },
    config = function()
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup(
          "kickstart-lsp-attach",
          { clear = true }
        ),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or "n"
            vim.keymap.set(
              mode,
              keys,
              func,
              { buffer = event.buf, desc = "LSP: " .. desc }
            )
          end

          map("grn", vim.lsp.buf.rename, "[R]e[n]ame")

          map(
            "gra",
            vim.lsp.buf.code_action,
            "[G]oto Code [A]ction",
            { "n", "x" }
          )

          map(
            "grr",
            require("telescope.builtin").lsp_references,
            "[G]oto [R]eferences"
          )

          map(
            "gri",
            require("telescope.builtin").lsp_implementations,
            "[G]oto [I]mplementation"
          )

          map(
            "grd",
            require("telescope.builtin").lsp_definitions,
            "[G]oto [D]efinition"
          )

          map("grD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

          map(
            "gO",
            require("telescope.builtin").lsp_document_symbols,
            "Open Document Symbols"
          )

          map(
            "gW",
            require("telescope.builtin").lsp_dynamic_workspace_symbols,
            "Open Workspace Symbols"
          )

          map(
            "grt",
            require("telescope.builtin").lsp_type_definitions,
            "[G]oto [T]ype Definition"
          )

          ---@param client vim.lsp.Client
          ---@param method vim.lsp.protocol.Method
          ---@param bufnr? integer some lsp support methods only in specific files
          ---@return boolean
          local function client_supports_method(client, method, bufnr)
            if vim.fn.has("nvim-0.11") == 1 then
              ---@diagnostic disable-next-line: param-type-mismatch
              return client:supports_method(method, bufnr)
            else
              ---@diagnostic disable-next-line: param-type-mismatch
              return client.supports_method(method, { bufnr = bufnr })
            end
          end

          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if
            client
            and client_supports_method(
              client,
              vim.lsp.protocol.Methods.textDocument_documentHighlight,
              event.buf
            )
          then
            local highlight_augroup = vim.api.nvim_create_augroup(
              "kickstart-lsp-highlight",
              { clear = false }
            )
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd("LspDetach", {
              group = vim.api.nvim_create_augroup(
                "kickstart-lsp-detach",
                { clear = true }
              ),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds({
                  group = "kickstart-lsp-highlight",
                  buffer = event2.buf,
                })
              end,
            })
          end

          -- Map unconditionally: some servers (e.g. ty, jdtls) register the
          -- inlayHint capability dynamically after LspAttach, so gating on
          -- supports_method here would silently drop the keymap. Buffers
          -- without a supporting client simply show nothing.
          map("<leader>th", function()
            vim.lsp.inlay_hint.enable(
              not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
            )
          end, "[T]oggle Inlay [H]ints")
        end,
      })

      vim.diagnostic.config({
        severity_sort = true,
        float = { border = "rounded", source = "if_many" },
        underline = { severity = vim.diagnostic.severity.ERROR },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "E",
            [vim.diagnostic.severity.WARN] = "W",
            [vim.diagnostic.severity.INFO] = "I",
            [vim.diagnostic.severity.HINT] = "H",
          },
        },
        virtual_text = {
          source = "if_many",
          spacing = 2,
          format = function(diagnostic)
            local diagnostic_message = {
              [vim.diagnostic.severity.ERROR] = diagnostic.message,
              [vim.diagnostic.severity.WARN] = diagnostic.message,
              [vim.diagnostic.severity.INFO] = diagnostic.message,
              [vim.diagnostic.severity.HINT] = diagnostic.message,
            }
            return diagnostic_message[diagnostic.severity]
          end,
        },
      })

      local capabilities = require("blink.cmp").get_lsp_capabilities()

      -- Shared by vtsls's typescript and javascript sections; servers only
      -- send inlay hints for the kinds explicitly enabled here.
      local ts_inlay_hints = {
        parameterNames = { enabled = "all" },
        parameterTypes = { enabled = true },
        variableTypes = { enabled = true },
        propertyDeclarationTypes = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        enumMemberValues = { enabled = true },
      }

      local servers = {
        lua_ls = {
          settings = {
            Lua = {
              completion = {
                callSnippet = "Replace",
              },
              hint = { enable = true },
            },
          },
        },
        ty = {},
        ruff = {
          -- ty owns hover/completion; ruff only contributes lint diagnostics,
          -- code actions and formatting so its hover does not double up.
          on_attach = function(client)
            client.server_capabilities.hoverProvider = false
          end,
        },
        vtsls = {
          settings = {
            typescript = { inlayHints = ts_inlay_hints },
            javascript = { inlayHints = ts_inlay_hints },
          },
        },
        cssls = {},
        tailwindcss = {},
        -- angularls = {}, --[[ Dont want this right now --]]
        jdtls = {
          settings = {
            java = {
              inlayHints = { parameterNames = { enabled = "all" } },
            },
          },
        },
        -- rust_analyzer and clangd emit inlay hints by default.
        rust_analyzer = {},
        gopls = {
          settings = {
            gopls = {
              hints = {
                assignVariableTypes = true,
                compositeLiteralFields = true,
                compositeLiteralTypes = true,
                constantValues = true,
                functionTypeParameters = true,
                parameterNames = true,
                rangeVariableTypes = true,
              },
            },
          },
        },
        clangd = {},
      }

      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        "stylua",
        "prettierd",
        "eslint_d",
        "goimports",
        "gofumpt",
        "golangci-lint",
        "google-java-format",
        "npm-groovy-lint",
      })
      require("mason-tool-installer").setup({
        ensure_installed = ensure_installed,
      })

      -- Register per-server overrides on top of nvim-lspconfig's defaults.
      -- mason-lspconfig v2 dropped the `handlers` option; it now just calls
      -- vim.lsp.enable() for every installed server, so config must be
      -- registered through vim.lsp.config() before that happens.
      vim.lsp.config("*", { capabilities = capabilities })
      for server_name, server in pairs(servers) do
        vim.lsp.config(server_name, server)
      end

      require("mason-lspconfig").setup({
        ensure_installed = {},
        automatic_installation = false,
      })
    end,
  },
}
