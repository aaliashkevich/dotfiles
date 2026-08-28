vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Highlight area of yank",
    group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
    callback = function()
        vim.hl.on_yank()
    end
})

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("MakefileSettings", { clear = true }),
    pattern = "make",
    command = "setlocal noexpandtab tabstop=4 shiftwidth=4 softtabstop=4",
})
