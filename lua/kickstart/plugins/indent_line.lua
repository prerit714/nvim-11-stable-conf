---@type LazySpec
return {
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      scope = {
        enabled = false,
      },
    },
  },
}
