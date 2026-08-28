return {
    "saghen/blink.cmp",
    version = "*",
    event = "InsertEnter",
    opts = {
        keymap = { preset = "default" },
        completion = {
            list = { selection = { preselect = false, auto_insert = true } },
            documentation = { auto_show = true }
        },
        sources = {
            default = { "lsp", "path", "buffer" }
        },
        fuzzy = { implementation = "prefer_rust_with_warning" }
    }
}
