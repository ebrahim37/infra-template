if vim.g.neovide or vim.loop.os_gethostname() == 'vps1' then
	vim.o.guifont = 'Consolas Nerd Font:h11.5'
	vim.o.linespace = 2
	
	vim.schedule(function()
		vim.o.columns = 118
		vim.o.lines = 57
	end)
	
	vim.g.neovide_profiler = false
	vim.g.neovide_input_macos_option_key_is_meta = 'both'
	vim.g.neovide_normal_opacity = 1
	vim.g.neovide_remember_window_size = false
	
	vim.g.neovide_position_animation_length = 0
	vim.g.neovide_cursor_animation_length = 0.00
	vim.g.neovide_cursor_trail_size = 0
	vim.g.neovide_cursor_animate_in_insert_mode = false
	vim.g.neovide_cursor_animate_command_line = false
	vim.g.neovide_scroll_animation_far_lines = 0
	vim.g.neovide_scroll_animation_length = 0.00
end

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.o.number = true
vim.o.relativenumber = true
vim.o.signcolumn = 'yes'

vim.opt.shortmess:append 'sI'

vim.o.laststatus = 2

vim.o.showmode = false

vim.o.splitkeep = 'screen'

vim.schedule(function()
	vim.o.clipboard = 'unnamedplus'
end)

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

vim.o.wrap = false
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.smartindent = true
vim.opt.fixendofline = false
vim.opt.endofline = false

vim.o.termguicolors = true
vim.o.winborder = 'rounded'

vim.opt.completeopt = {'menu', 'menuone', 'noselect'}
vim.opt.guicursor = {
	'n-v-c:block-Cursor/lCursor',	 -- normal/visual mode: block
	'i:ver25-CursorBlink/lCursorBlink', -- insert mode: vertical bar, 25% width, blinking
	'r-cr:hor20-CursorBlink/lCursorBlink', -- replace mode: horizontal underline
}

vim.opt.whichwrap:append '<>[]hl'

vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1