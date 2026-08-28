return {
	"nvim-lualine/lualine.nvim",
	event = "VeryLazy",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		local wk = require("which-key")
		local line = require("lualine")

		line.setup({
			options = {
				theme = "nordic",
			},
			sections = {
				lualine_a = { "mode" },
				lualine_b = { "buffers" },
				lualine_c = {},
				lualine_x = {},
				lualine_y = {},
				lualine_z = { "progress" },
			},
		})

		vim.keymap.set("n", "<leader>bb", "<cmd>bnext<CR>")
		vim.keymap.set("n", "<leader>bx", "<cmd>bd<CR>")

		vim.keymap.set("n", "<leader>bc", function()
			local current_buffer = vim.api.nvim_get_current_buf()

			for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_loaded(buffer) and current_buffer ~= buffer then
					vim.cmd("bd " .. buffer)
				end
			end
		end)

		wk.add({
			{ "<leader>b", group = "buffer" },
			{ "<leader>bb", desc = "cycle buffers" },
			{ "<leader>bx", desc = "close current buffer" },
			{ "<leader>bc", desc = "close all buffers except current" },
		})
	end,
}
