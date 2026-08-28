return {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    config = function()
        local mason_path = vim.fn.stdpath("data") .. "/mason/bin"

        require("conform").setup({
            notify_on_error = true,
            format_on_save = {
                timeout_ms = 1000,
                lsp_format = "fallback"
            },
            formatters = {
                hclfmt = {
                    command = mason_path .. "/hclfmt",
                    args = {},
                    stdin = true
                }
            },
            formatters_by_ft = {
                javascript = { "eslint_d", "prettierd" },
                typescript = { "eslint_d", "prettierd" },
                javascriptreact = { "eslint_d", "prettierd" },
                typescriptreact = { "eslint_d", "prettierd" },
                go = { "goimports-reviser", "golines", "gofumpt" },
                templ = { "templ" },
                hcl = { "hclfmt" },
                terraform = { "terraform_fmt" },
                lua = { "stylua" },
                rust = { "rustfmt" },
                json = { "prettierd" },
                jsonc = { "prettierd" },
                yaml = { "prettierd" },
                markdown = { "prettierd" },
                html = { "prettierd" },
                css = { "prettierd" },
                scss = { "prettierd" },
                sh = { "shfmt" },
                bash = { "shfmt" },
                toml = { "taplo" },
                d2 = { "d2" }
            }
        })
    end
}
