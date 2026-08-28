local wk = require("which-key")

vim.cmd("ca Q q")
vim.cmd("ca W w")
vim.cmd("ca WQ wq")
vim.cmd("ca Wq wq")
vim.cmd("ca QA qa")
vim.cmd("ca Qa qa")

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

vim.keymap.set("n", "J", "mzJ`z")
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

vim.keymap.set("x", "<leader>p", "\"_dP")

vim.keymap.set("n", "<leader>y", "\"+y")
vim.keymap.set("v", "<leader>y", "\"+y")
vim.keymap.set("n", "<leader>Y", "\"+Y")

vim.keymap.set("n", "Q", "<nop>")

vim.keymap.set("n", "<leader>c", function()
    require("conform").format({ lsp_format = "fallback" })
end)

vim.keymap.set("n", "<leader>s", ":%s/\\<<C-r><C-w>\\>/<C-r><C-w>/cgI<Left><Left><Left>")

vim.keymap.set("n", "[d", function()
    vim.diagnostic.jump({ count = -1, float = true })
end)

vim.keymap.set("n", "]d", function()
    vim.diagnostic.jump({ count = 1, float = true })
end)

wk.add({
    { "<leader>y", desc = "yank: text into clipboard" },
    { "<leader>Y", desc = "yank: lines into clipboard" },
    { "<leader>s", desc = "replace all occurences under cursor" },
    { "<leader>c", desc = "format code" },
    { "[d",        desc = "jump to previous diagnostic" },
    { "]d",        desc = "jump to next diagnostic" },
})
