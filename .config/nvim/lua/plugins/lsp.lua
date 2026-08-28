local mason_path = vim.fn.stdpath("data") .. "/mason/bin"

local tools = {
	"lua_ls",
	"bashls",
	"dockerls",
	"jsonls",
	"cssls",
	"html",
	"tailwindcss",
	"marksman",
	"gopls",
	"templ",
	"sqlls",
	"rust_analyzer",
	"taplo",
	"wgsl_analyzer",
	"terraform-ls",
	"ansible-language-server",
	"just-lsp",
	"ts_ls",
	"eslint",
	"eslint_d",
	"prettierd",
	"gofumpt",
	"goimports-reviser",
	"golines",
	"hclfmt",
	"stylua",
	"shfmt",
	"ansible-lint",
	"shellcheck",
}

return {
	{
		"mason-org/mason.nvim",
		lazy = false,
		opts = {},
	},
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		lazy = false,
		dependencies = { "mason-org/mason.nvim", "mason-org/mason-lspconfig.nvim" },
		opts = { ensure_installed = tools },
	},
	{
		"mason-org/mason-lspconfig.nvim",
		lazy = false,
		dependencies = {
			"mason-org/mason.nvim",
			"neovim/nvim-lspconfig",
			"saghen/blink.cmp",
		},
		config = function()
			local wk = require("which-key")

			vim.diagnostic.config({
				virtual_text = false,
				float = { border = "rounded" },
			})

			vim.lsp.config("*", {
				capabilities = require("blink.cmp").get_lsp_capabilities(),
			})

			vim.lsp.config("gopls", {
				settings = {
					gopls = {
						completeUnimported = true,
						usePlaceholders = true,
						analyses = {
							unusedparams = true,
						},
						staticcheck = true,
						vulncheck = "Imports",
						gofumpt = true,
					},
				},
			})

			vim.lsp.config("tailwindcss", {
				on_attach = function(client)
					client.server_capabilities.documentFormattingProvider = false
				end,
			})

			vim.lsp.config("eslint", {
				on_attach = function(client)
					client.server_capabilities.documentFormattingProvider = false
				end,
			})

			vim.lsp.config("ansiblels", {
				cmd = { mason_path .. "/ansible-language-server", "--stdio" },
				filetypes = { "yaml.ansible" },
			})

			require("mason-lspconfig").setup({
				automatic_enable = true,
			})

			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
				callback = function(event)
					vim.keymap.set("n", "g<Tab>", vim.lsp.buf.rename, { buffer = event.buf })
				end,
			})

			wk.add({
				{ "g<Tab>", desc = "rename symbol" },
			})
		end,
	},
}
