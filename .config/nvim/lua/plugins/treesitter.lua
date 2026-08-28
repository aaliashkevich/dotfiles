local parsers = {
    "bash",
    "gitattributes",
    "gitignore",
    "c",
    "make",
    "markdown",
    "markdown_inline",
    "regex",
    "lua",
    "vim",
    "vimdoc",
    "query",
    "jq",
    "json",
    "html",
    "css",
    "scss",
    "jsdoc",
    "javascript",
    "typescript",
    "tsx",
    "sql",
    "go",
    "gomod",
    "gosum",
    "gowork",
    "templ",
    "rust",
    "wgsl",
    "toml",
    "yaml",
    "dockerfile",
    "hcl",
    "terraform",
    "just"
}

return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        lazy = false,
        build = ":TSUpdate",
        config = function()
            local treesitter = require("nvim-treesitter")

            vim.filetype.add({
                extension = {
                    wgsl = "wgsl",
                    templ = "templ"
                }
            })

            treesitter.setup({})

            local installed = {}
            for _, parser in ipairs(treesitter.get_installed("parsers")) do
                installed[parser] = true
            end

            local missing = vim.tbl_filter(function(parser)
                return not installed[parser]
            end, parsers)

            if #missing > 0 then
                treesitter.install(missing)
            end

            vim.api.nvim_create_autocmd("FileType", {
                group = vim.api.nvim_create_augroup("treesitter-start", { clear = true }),
                callback = function(event)
                    local lang = vim.treesitter.language.get_lang(vim.bo[event.buf].filetype)

                    if lang and vim.treesitter.language.add(lang) then
                        pcall(vim.treesitter.start, event.buf, lang)
                        vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                    end
                end
            })
        end
    },
    {
        "nvim-treesitter/nvim-treesitter-context",
        event = "VeryLazy",
        opts = {}
    }
}
