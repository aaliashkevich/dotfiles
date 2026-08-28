return {
    "folke/todo-comments.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
        local todo = require("todo-comments")
        local wk = require("which-key")

        todo.setup({})

        vim.keymap.set("n", "]t", todo.jump_next)
        vim.keymap.set("n", "[t", todo.jump_prev)

        wk.add({
            { "]t", desc = "jump to next todo" },
            { "[t", desc = "jump to prev todo" }
        })
    end
}
