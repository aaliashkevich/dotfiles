return {
    "folke/which-key.nvim",
    lazy = false,
    priority = 900,
    init = function()
        vim.o.timeout = true
        vim.o.timeoutlen = 500
    end,
    opts = {}
}
