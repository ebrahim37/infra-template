vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

if vim.env.SSH_TTY or vim.env.SSH_CONNECTION then
	vim.g.clipboard = 'osc52'
end
vim.o.clipboard = 'unnamedplus'

vim.o.number = true
vim.o.relativenumber = true
vim.o.signcolumn = 'yes'

vim.opt.shortmess:append 'sI'

vim.o.laststatus = 2

vim.o.showmode = false

vim.o.splitkeep = 'screen'

vim.o.undofile = true
vim.o.swapfile = false

vim.o.list = true
vim.opt.listchars = { tab = '  ' }

vim.o.ignorecase = true
vim.o.smartcase  = true

vim.o.splitbelow = true
vim.o.splitright = true

vim.o.cursorline = true
vim.o.cursorlineopt = 'both'
vim.o.cursorcolumn = false

vim.o.wrap = true
vim.o.linebreak = true
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.smartindent = true
vim.opt.fixendofline = false
vim.opt.endofline = false

vim.o.termguicolors = true
vim.o.winborder = 'rounded'

vim.opt.completeopt = {'menu', 'menuone', 'noselect'}

vim.opt.whichwrap:append '<>[]hl'

vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
