return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      -- Install the desired parsers
      local parsers = {
        "bash",
        "c",
        "diff",
        "html",
        "lua",
        "luadoc",
        "markdown",
        "markdown_inline",
        "query",
        "vim",
        "vimdoc",
        "javascript",
        "typescript",
        "tsx",
        "python",
        "rust",
        "go",
        "gomod",
        "gowork",
        "toml",
        "java",
      }
      require("nvim-treesitter").install(parsers)

      -- Automatically start treesitter highlighting and indentation for any
      -- filetype that has an installed parser (including kulala.nvim's http parser).
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          local buf, filetype = args.buf, args.match
          local language = vim.treesitter.language.get_lang(filetype)
          if not language then
            return
          end

          local installed = require("nvim-treesitter").get_installed("parsers")
          if not vim.tbl_contains(installed, language) then
            return
          end

          -- Enable syntax highlighting
          vim.treesitter.start(buf, language)

          -- Enable treesitter-based indentation if queries are available.
          -- Skip Ruby as it still relies on legacy regex indent rules.
          if
            vim.treesitter.query.get(language, "indents") ~= nil
            and filetype ~= "ruby"
          then
            vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
}
