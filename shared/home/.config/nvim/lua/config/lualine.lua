local colors = {
	red = '#ec5f67',
	yellow = '#ECBE7B',
	cyan = '#008080',
}

local buffer_not_empty = function()
	return vim.fn.empty(vim.fn.expand('%:t')) ~= 1
end

require('lualine').setup({
	options = {
		theme = 'auto',
		component_separators = '',
	},
	sections = {
		lualine_a = {
			{
				'mode',
			},
		},
		lualine_b = {
			{
				'branch',
			},
			{
				'diagnostics',
				sources = { 'nvim_diagnostic' },
				symbols = { error = ' ', warn = ' ', info = ' ' },
				diagnostics_color = {
					error = { fg = colors.red },
					warn = { fg = colors.yellow },
					info = { fg = colors.cyan },
				},
			}
		},
		lualine_c = {
			{
				'filename',
				path = 1,
				cond = buffer_not_empty,
			}
		},
		lualine_x = {
			{
				'lsp_status',
				-- padding = { right = 15 },
			},
			{
				'fileformat',
				fmt = string.upper,
				icons_enabled = false, -- I think icons are cool but Eviline doesn't have them. sigh
			},
		},
		lualine_y = {
			{
				'progress',
			}
		},
		lualine_z = {
			{
				'location'
			}
		}
	},
	inactive_sections = {
		lualine_a = {},
		lualine_b = {},
		lualine_c = {
			{
				'filename',
				path = 1,
				cond = buffer_not_empty,
			}
		},
		lualine_x = {
			{
				'location'
			}
		},
		lualine_y = {},
		lualine_z = {}
	},
	tabline = {
		lualine_a = {
			{
				'buffers',
				mode = 2,
				use_mode_colors = true,
			}
		},
		lualine_b = {},
		lualine_c = {},
		lualine_x = {},
		lualine_y = {},
		lualine_z = {
			{
				'tabs',
				use_mode_colors = true,
			}
		}
	},
})