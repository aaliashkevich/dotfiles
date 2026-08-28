return {
    "f-person/git-blame.nvim",
    event = "VeryLazy",
    config = function()
        local blame = require("gitblame")
        local wk = require("which-key")

        blame.setup({
            enabled = false,
            date_format = "%r",
            message_template = "<author> • <date> • <sha> • <summary>",
            message_when_not_committed = "Local Changes",
            highlight_group = "Comment",
            display_virtual_text = 1,
            virtual_text_column = 80
        })

        vim.keymap.set("n", "<leader>gb", blame.toggle)

        wk.add({
            { "<leader>g",  group = "git" },
            { "<leader>gb", desc = "git: blame" }
        })
    end
}
