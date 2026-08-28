return {
    {
        "christoomey/vim-tmux-navigator",
        lazy = false
    },
    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        event = { "BufReadPost", "BufNewFile" },
        opts = {}
    },
    {
        "terrastruct/d2-vim",
        ft = "d2"
    }
}
