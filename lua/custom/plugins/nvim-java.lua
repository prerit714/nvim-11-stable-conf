---@type LazySpec
return {
  "nvim-java/nvim-java",
  -- Only needed for Java buffers. jdtls is excluded from mason-lspconfig's
  -- automatic_enable (lspconfig.lua) so it is enabled here, after setup.
  ft = "java",
  config = function()
    require("java").setup()
    vim.lsp.enable("jdtls")
  end,
}
