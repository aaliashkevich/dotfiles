return {
	"nvim-tree/nvim-tree.lua",
	lazy = false,
	priority = 800,
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		local wk = require("which-key")
		local api = require("nvim-tree.api")

		require("nvim-tree").setup({
			view = {
				width = 40,
			},
			renderer = {
				highlight_opened_files = "name",
			},
		})

		vim.api.nvim_create_autocmd("VimEnter", {
			group = vim.api.nvim_create_augroup("nvim-tree-open", { clear = true }),
			callback = function()
				if vim.fn.argc() == 0 and vim.bo.filetype ~= "NvimTree" then
					api.tree.open()
				end
			end,
		})

		vim.keymap.set("n", "§", vim.cmd.NvimTreeToggle)

		wk.add({
			{ "§", desc = "nvim-tree: toggle" },
		})
	end,
}
