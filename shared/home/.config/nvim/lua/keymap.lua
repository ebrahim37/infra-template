local map = vim.keymap.set

vim.api.nvim_create_user_command('ToggleAllSide', function()
	vim.o.relativenumber = not vim.o.relativenumber
	vim.o.number = not vim.o.number
	if vim.o.signcolumn == 'yes' then
		vim.o.signcolumn = 'no'
	else
		vim.o.signcolumn = 'yes'
	end
end, { desc = 'toggle relative numbers, numbers, and signcolumn' })

vim.api.nvim_create_user_command('ToggleNumbers', function()
	vim.o.relativenumber = not vim.o.relativenumber
	vim.o.number = not vim.o.number
end, { desc = 'toggle relative numbers, numbers, and signcolumn' })

vim.api.nvim_create_user_command('ToggleSignColumn', function()
	if vim.o.signcolumn == 'yes' then
		vim.o.signcolumn = 'no'
	else
		vim.o.signcolumn = 'yes'
	end
end, { desc = 'toggle relative numbers, numbers, and signcolumn' })

map('i', '<C-b>', '<ESC>^i', { desc = 'move beginning of line' })
map('i', '<C-e>', '<End>', { desc = 'move end of line' })
map('i', '<C-h>', '<Left>', { desc = 'move left' })
map('i', '<C-l>', '<Right>', { desc = 'move right' })
map('i', '<C-j>', '<Down>', { desc = 'move down' })
map('i', '<C-k>', '<Up>', { desc = 'move up' })

map('t', '<Esc>', '<C-\\><C-n>', { desc = 'makes <Esc> exit terminal mode back to normal mode' })
map('t', '<C-o>', '<C-\\><C-o>', { desc = 'lets you run one normal mode command in terminal mode, then return to terminal input' })

local shared_term = require('toggleterm.terminal').Terminal:new({ hidden = true, count = 42 })
local function toggle_shared(direction)
	shared_term.direction = direction
	shared_term:toggle()
end
map({ 'n', 't' }, '<A-i>', function() toggle_shared('float') end, { desc = 'shared terminal float' })
map({ 'n', 't' }, '<A-v>', function() toggle_shared('vertical') end, { desc = 'shared terminal vertical' })
map({ 'n', 't' }, '<A-s>', function() toggle_shared('horizontal') end, { desc = 'shared terminal horizontal' })

map('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'clear highlights on search' })

map('n', '<Tab>', ':bnext<CR>', { desc = 'buffer goto next' })
map('n', '<S-Tab>', ':bprevious<CR>', { desc = 'buffer goto previous' })

map('n', '<C-h>', '<C-w><C-h>', { desc = 'move focus to the left window' })
map('n', '<C-l>', '<C-w><C-l>', { desc = 'move focus to the right window' })
map('n', '<C-j>', '<C-w><C-j>', { desc = 'move focus to the lower window' })
map('n', '<C-k>', '<C-w><C-k>', { desc = 'move focus to the upper window' })

local function goto_buffer(n)
	local buffers = vim.fn.getbufinfo({ buflisted = 1 })
	table.sort(buffers, function(a, b) return a.bufnr < b.bufnr end) -- same order as :ls
	local target = buffers[n]
	if target then
		vim.api.nvim_set_current_buf(target.bufnr)
	end
end
for i = 1, 9 do
	vim.keymap.set('n', '<A-' .. i .. '>', function() goto_buffer(i) end, { desc = 'go to buffer ' .. i })
end
vim.keymap.set('n', '<A-0>', function() goto_buffer(10) end, { desc = 'go to buffer 10' })

map('n', '<leader>-', function()
	vim.o.lines = vim.o.lines
	vim.o.columns = vim.o.columns
	vim.defer_fn(function()
		vim.o.lines = vim.o.lines
		vim.o.columns = vim.o.columns
	end, 50)
end, { desc = 'shrink window padding' })
map('n', '<leader>=', function()
	vim.o.lines = 57
	vim.o.columns = 230
	vim.defer_fn(function()
		vim.o.lines = 57
		vim.o.columns = 230
	end, 50)
end, { desc = 'set window size to 230x57 cells' })

map('n', '<leader>?', function() require('which-key').show({ global = false }) end, { desc = 'see the buffer-local keymaps' })
map('n', '<leader>b', ':enew<CR>', { desc = 'new buffer' })
map('n', '<leader>e', ':Oil<CR>', { desc = 'open Oil in current window' })
-- map('n', '<leader>w', ':write<CR>', { desc = 'write current buffer' })
map('n', '<leader>w', function()
	local ok, err = pcall(vim.cmd.write)

	if ok then
		return
	end

	if vim.fn.exists(":SudaWrite") == 2 then
		vim.cmd("SudaWrite")
	else
		vim.notify(err, vim.log.levels.ERROR)
	end
end, { desc = "write current buffer, sudo if needed" })
map('n', '<leader>q', ':quit<CR>', { desc = 'quit current window' })
map('n', '<leader>v', function() vim.cmd('TermNew direction=vertical') end, { desc = 'terminal new vertical' })
map('n', '<leader>s', function() vim.cmd('TermNew direction=horizontal') end, { desc = 'terminal new horizontal' })
map('n', '<leader>x', function()
	vim.cmd('bdelete')
	if vim.fn.bufnr('$') == -1 then
		vim.cmd('enew')
	end
end, { desc = 'close buffer (ensure window stays open)' })
map('n', '<leader>/', 'gcc', { desc = 'toggle comment', remap = true })
map('v', '<leader>/', 'gc', { desc = 'toggle comment', remap = true })
map('n', '<leader>lf', vim.lsp.buf.format, { desc = 'format current buffer' })
map('n', '<leader>ds', vim.diagnostic.setloclist, { desc = 'LSP diagnostic loclist' })
map('n', '<leader>ff', ':Pick files<CR>', { desc = 'search files in cwd' })
map('n', '<leader>fg', ':Pick grep_live<CR>', { desc = 'live grep in cwd' })
map('n', '<leader>fh', ':Pick help<CR>', { desc = 'search help pages' })

-- map({ 'n', 'v' }, '<leader>n', ':norm ', { desc = 'run :norm on selection or line' })
-- map({ 'n', 'v' }, '<leader>c', '1z=', { desc = 'correct last spelling error' })
-- map({ 'n', 'v' }, '<leader>o', ':update<CR> :source<CR>', { desc = 'save and source current file' })