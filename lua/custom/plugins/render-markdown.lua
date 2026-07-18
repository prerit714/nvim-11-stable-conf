return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown" },
  opts = {
    -- Only render in Normal mode; raw markdown in Insert mode
    render_modes = { "n" },
    heading = {
      -- Keep heading icons but drop full-width backgrounds
      backgrounds = {},
      sign = false,
    },
    code = {
      -- Disable code-block backgrounds & language headers entirely
      style = "none",
    },
    bullet = { enabled = false },
    pipe_table = { enabled = false },
    quote = { enabled = false },
    checkbox = { enabled = false },
    link = { enabled = false },
    dash = { enabled = false },
    sign = { enabled = false },
    latex = { enabled = false },
  },
}
