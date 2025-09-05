--
-- @afternoon's neovim config 2024-2025
--

--
-- OPTIONS
--

-- enable mouse in all modes
vim.opt.mouse = "a"

-- show line numbers
vim.opt.number = true

-- tabs to spaces
vim.opt.expandtab = true

-- sane indentation
local tabstop = 2
vim.opt.tabstop = tabstop
vim.opt.shiftwidth = tabstop
vim.opt.softtabstop = tabstop

-- ignore case when searching
vim.opt.ignorecase = true

-- global substitute default on
vim.opt.gdefault = true

-- highlight matching bracket
vim.opt.showmatch = true

-- disable line wrapping
vim.opt.wrap = false

-- autoread files changed outside vim
vim.opt.autoread = true

-- write files when moving around file lists
vim.opt.autowrite = true
vim.opt.autowriteall = true

-- always show sign column
vim.opt.signcolumn = "yes"

-- use ripgrep for :grep
vim.opt.grepprg = "rg --vimgrep --no-heading --smart-case"

-- show color column
vim.opt.textwidth = 100
vim.opt.colorcolumn = "101"
vim.api.nvim_set_hl(0, "ColorColumn", { ctermbg=7, bg="#111111" })

--
-- KEYBINDINGS
--

-- possibly unnecessary - https://bit.ly/3KcTPnM
local map = function(key)
  -- get the extra options
  local opts = {noremap = true, silent = true}
  for i, v in pairs(key) do
    if type(i) == "string" then opts[i] = v end
  end

  -- basic support for buffer-scoped keybindings
  local buffer = opts.buffer
  opts.buffer = nil

  if buffer then
    vim.api.nvim_buf_set_keymap(0, key[1], key[2], key[3], opts)
  else
    vim.api.nvim_set_keymap(key[1], key[2], key[3], opts)
  end
end

-- comma as leader
vim.g.mapleader = ","

-- use <§> as <Esc> because my silly Apple laptop has a silly DouchBar
map {"n", "§", "<Esc>"}
map {"v", "§", "<Esc>gV"}
map {"o", "§", "<Esc>"}
map {"c", "§", "<C-c><Esc>"}
map {"i", "§", "<Esc>`^"}

-- Normal mode

-- window splitting, closing, moving
map {"n", "<Leader>v", "<C-w>v<C-w>l"}
map {"n", "<Leader>s", "<C-w>s<C-w>j"}
map {"n", "<Leader>c", "<C-w>c"}
map {"n", "<C-h>", "<C-w>h"}
map {"n", "<C-j>", "<C-w>j"}
map {"n", "<C-k>", "<C-w>k"}
map {"n", "<C-l>", "<C-w>l"}

-- move between buffers with J/K
map {"n", "<S-l>", ":bnext<CR>"}
map {"n", "<S-h>", ":bprev<CR>"}

-- shortcuts for deleting, saving, etc
map {"n", "<Leader>q", ":wqa!<CR>"}
map {"n", "<Leader>w", ":w!<CR>"}
map {"n", "<Leader><Esc>", ":q!<CR>"}
map {"n", "<Leader>d", ":bd!<CR>"}
map {"n", "<Leader>D", ":bufdo bd<CR>"}

-- telescope
map {"n", "<Leader>f", ":Telescope find_files<CR>"}
map {"n", "<Leader>g", ":Telescope live_grep<CR>"}
map {"n", "<Leader>b", ":Telescope buffers<CR>"}

-- hide search highlighting
map {"n", "<Leader>l", ":nohlsearch<CR>"}

-- open/close quickfix window
map {"n", "<Leader>z", ":copen<CR>"}
map {"n", "<Leader>x", ":cclose<CR>"}

-- toggle file tree view
map {"n", "<Leader><Space>", ":NvimTreeToggle<CR>"}

-- show search results in the centre of the window
map {"n", "n", "nzz"}
map {"n", "N", "Nzz"}
map {"n", "*", "*zz"}
map {"n", "#", "#zz"}
map {"n", "g*", "g*zz"}
map {"n", "g#", "g#zz"}

-- Visual mode

-- keep visual selection after indent
map {"v", ">", ">gv"}
map {"v", "<", "<gv"}

-- don"t overwrite register when replacing a selection
map {"v", "p", '"_dP'}

-- sort visual selection
map {"v", "<Leader>s", ":sort<CR>"}

--
-- Bootstrap lazy.nvim
--

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    -- fancy colorscheme
    {
      "navarasu/onedark.nvim",
      lazy = false,
      priority = 1000,
      opts = { style = "darker" },
      config = function ()
        vim.cmd([[colorscheme onedark]])
      end
    },

    -- auto-save
    { "pocco81/auto-save.nvim" },

    -- fancy fuzzy finding
    {
      "nvim-telescope/telescope.nvim",
      tag = "0.1.8",
      dependencies = { "nvim-lua/plenary.nvim" }
    },

    -- tpope: Vim plugin artist
    { "tpope/vim-abolish" },
    { "tpope/vim-commentary" },
    { "tpope/vim-repeat" },
    { "tpope/vim-surround" },
    { "tpope/vim-unimpaired" },

    -- file tree viewer
    {
      "nvim-tree/nvim-tree.lua",
      lazy = false,
      dependencies = { "nvim-tree/nvim-web-devicons" },
      opts = {},
    },

    -- fugitive
    { "tpope/vim-fugitive" },

    -- git info in gutter
    {
      "lewis6991/gitsigns.nvim",
      dependencies = { "nvim-lua/plenary.nvim" },
    },

    -- fancy git diff view
    {
      "sindrets/diffview.nvim",
      dependencies = { "nvim-lua/plenary.nvim" },
    },

    -- highlight/strip trailing whitespace
    { "ntpeters/vim-better-whitespace" },

    -- syntax highlight everything
    -- see config below, apparently using lazy.nvim opts doesn't work
    {
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
      lazy = false,
    },

    -- fancy bracket completion
    {
      "windwp/nvim-autopairs",
      event = "InsertEnter",
      config = true,
    },

    -- fancy HTML tag completion - requires nvim-treesitter
    {
      "windwp/nvim-ts-autotag",
      config = true,
    },

    -- tpope: AI plugin artist
    { "github/copilot.vim" },

    -- lsp-zero v4
    { "VonHeikemen/lsp-zero.nvim", branch = "v4.x" },
    { "neovim/nvim-lspconfig" },

    -- language server management
    { "williamboman/mason.nvim" },
    { "williamboman/mason-lspconfig.nvim" },

    -- additional completions
    {
      "hrsh7th/nvim-cmp",
      event = "InsertEnter",
      dependencies = {
        { "hrsh7th/cmp-buffer" },
        { "hrsh7th/cmp-nvim-lsp" },
        { "hrsh7th/cmp-nvim-lua" },
        { "hrsh7th/cmp-path" },
      },
      config = function()
        local cmp = require("cmp")
        local cmp_action = require("lsp-zero").cmp_action()

        cmp.setup({
          sources = {
            { name = "nvim_lsp" },
            { name = "nvim_lua" },
            { name = "path" },
            { name = "buffer" },
          },
        })
      end
    },
  },

  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = {
    colorscheme = { "onedark" }
  },

  -- automatically check for plugin updates
  checker = {
    enabled = true
  },
})

-- load onedark theme, for some reason I can't get the lazy.nvim config to do this automatically
require("onedark").setup {
  style = "darker"
}
require("onedark").load()

-- configure lspzero
local lsp_zero = require("lsp-zero")
lsp_zero.extend_lspconfig({
  sign_text = true,
  lsp_attach = function(client, bufnr)
    lsp_zero.default_keymaps({ buffer = bufnr })
  end,
  capabilities = require("cmp_nvim_lsp").default_capabilities(),
})

-- configure mason
require("mason").setup({})
require("mason-lspconfig").setup({
  handlers = {
    function(server_name)
      require("lspconfig")[server_name].setup({})
    end,
  },
})

require("nvim-treesitter.configs").setup {
  auto_install = true,
  ensure_installed = {
    "astro",
    "bash",
    "css",
    "dockerfile",
    "go",
    "html",
    "javascript",
    "json",
    "lua",
    "markdown",
    "python",
    "rust",
    "scss",
    "toml",
    "tsx",
    "typescript",
    "yaml"
  },
  highlight = {
      enable = true,
    }
}
