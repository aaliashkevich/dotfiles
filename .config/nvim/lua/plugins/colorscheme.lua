return {
	"AlexvZyl/nordic.nvim",
	lazy = false,
	priority = 1000,
	config = function()
		require("nordic").setup({
			bold_keywords = false,
			italic_comments = true,
			transparent = { bg = false, float = false },
			bright_border = false,
			reduced_blue = true,
			cursorline = { theme = "dark", blend = 0.85 },
			telescope = { style = "flat" },
			ts_context = { dark_background = true },
		})
		require("nordic").load()

		local palette = require("nordic.colors")

		vim.api.nvim_set_hl(0, "LineNrAbove", { fg = palette.blue1, bold = true })
		vim.api.nvim_set_hl(0, "LineNr", { fg = palette.white3, bold = true })
		vim.api.nvim_set_hl(0, "LineNrBelow", { fg = palette.magenta.base, bold = true })
	end,
}
