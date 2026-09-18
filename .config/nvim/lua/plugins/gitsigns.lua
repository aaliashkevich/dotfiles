return {
	"lewis6991/gitsigns.nvim",
	event = "VeryLazy",
	config = function()
		local gitsigns = require("gitsigns")
		local wk = require("which-key")

		gitsigns.setup({
			signs = {
				add = { text = "█" },
				change = { text = "█" },
				delete = { text = "█" },
				topdelete = { text = "█" },
				changedelete = { text = "█" },
				untracked = { text = "█" },
			},
			signs_staged = {
				add = { text = "█" },
				change = { text = "█" },
				delete = { text = "█" },
				topdelete = { text = "█" },
				changedelete = { text = "█" },
			},
			signs_staged_enable = true,
			attach_to_untracked = true,
			preview_config = { border = vim.o.winborder },
		})

		vim.keymap.set("n", "[h", function()
			gitsigns.nav_hunk("prev")
		end)

		vim.keymap.set("n", "]h", function()
			gitsigns.nav_hunk("next")
		end)

		vim.keymap.set("n", "<leader>gp", gitsigns.preview_hunk)
		vim.keymap.set("n", "<leader>gs", gitsigns.stage_hunk)
		vim.keymap.set("n", "<leader>gr", gitsigns.reset_hunk)
		vim.keymap.set("n", "<leader>gd", gitsigns.diffthis)

		wk.add({
			{ "<leader>g", group = "git" },
			{ "<leader>gp", desc = "git: preview hunk" },
			{ "<leader>gs", desc = "git: stage hunk" },
			{ "<leader>gr", desc = "git: reset hunk" },
			{ "<leader>gd", desc = "git: diff this file" },
			{ "[h", desc = "jump to previous hunk" },
			{ "]h", desc = "jump to next hunk" },
		})
	end,
}
