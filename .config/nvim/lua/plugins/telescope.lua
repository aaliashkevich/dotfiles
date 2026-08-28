return {
    "nvim-telescope/telescope.nvim",
    event = "VeryLazy",
    dependencies = {
        "nvim-lua/plenary.nvim",
        {
            "nvim-telescope/telescope-fzf-native.nvim",
            build = "make"
        }
    },
    config = function()
        local telescope = require("telescope")
        local builtin = require("telescope.builtin")
        local wk = require("which-key")

        vim.keymap.set("n", "<leader>fc", builtin.current_buffer_fuzzy_find, {})
        vim.keymap.set("n", "<leader>ff", builtin.find_files, {})
        vim.keymap.set("n", "<leader>fg", builtin.git_files, {})
        vim.keymap.set("n", "<leader>fb", builtin.buffers, {})
        vim.keymap.set("n", "<leader>fd", builtin.lsp_document_symbols, {})
        vim.keymap.set("n", "<leader>fw", builtin.lsp_dynamic_workspace_symbols, {})
        vim.keymap.set("n", "<leader>ft", "<cmd>TodoTelescope<CR>")
        vim.keymap.set("n", "<leader>fs", function()
            builtin.grep_string({ search = vim.fn.input("grep > ") })
        end)

        telescope.setup({
            defaults = {
                history = false
            },
            pickers = {
                grep_string = {
                    file_ignore_patterns = { "node_modules", ".git" },
                    additional_args = function(_)
                        return { "--hidden" }
                    end
                },
                find_files = {
                    file_ignore_patterns = { "node_modules", ".git" },
                    hidden = true
                }
            },
            extensions = {
                fzf = {}
            }
        })

        pcall(telescope.load_extension, "fzf")

        wk.add({
            { "<leader>f",  group = "find" },
            { "<leader>fc", desc = "find in current buffer" },
            { "<leader>ff", desc = "find file by name" },
            { "<leader>fg", desc = "find git file by name" },
            { "<leader>fb", desc = "find buffer by name" },
            { "<leader>fd", desc = "find in document" },
            { "<leader>fw", desc = "find in workspace" },
            { "<leader>ft", desc = "find in todos" },
            { "<leader>fs", desc = "find in files" }
        })
    end
}
