local keymap = vim.keymap.set

keymap('i', 'jj', '<Esc>', { desc = 'Exit insert mode with jj' })
keymap('t', 'jj', '<C-\\><C-n>', { desc = 'Exit terminal mode with jj' })

local builtin = require('telescope.builtin')
keymap('n', '<leader>f', builtin.find_files, { desc = 'Find files' })
keymap('n', '<leader>g', builtin.live_grep, { desc = 'Live grep' })
keymap('n', '<leader>s', builtin.git_status, { desc = 'Git status' })
keymap('n', '<leader>b', builtin.buffers, { desc = 'Buffers' })
keymap('n', '<leader>h', builtin.help_tags, { desc = 'Help tags' })
keymap('n', '<leader>t', ':Telescope file_browser path=%:p:h select_buffer=true<CR>',
  { noremap = true, desc = 'File browser' })

keymap('n', '<leader>q', ':Git blame<CR>', { desc = 'Git blame' })

keymap('n', 'gd', '<Plug>(coc-definition)', { silent = true, desc = 'Go to definition' })
keymap('n', 'gy', '<Plug>(coc-type-definition)', { silent = true, desc = 'Go to type definition' })
keymap('n', 'gi', '<Plug>(coc-implementation)', { silent = true, desc = 'Go to implementation' })
keymap('n', 'gr', '<Plug>(coc-references)', { silent = true, desc = 'Go to references' })

keymap('n', 'K', ':call v:lua.show_documentation()<CR>', { silent = true, desc = 'Show documentation' })

keymap('n', '<leader>rn', '<Plug>(coc-rename)', { desc = 'Rename symbol' })

keymap('x', '<leader>a', '<Plug>(coc-codeaction-selected)', { desc = 'Code action (visual)' })
keymap('n', '<leader>a', '<Plug>(coc-codeaction-selected)', { desc = 'Code action' })
keymap('n', '<leader>ac', '<Plug>(coc-codeaction-cursor)', { desc = 'Code action at cursor' })
keymap('n', '<leader>as', '<Plug>(coc-codeaction-source)', { desc = 'Code action source' })
keymap('n', '<leader>qf', '<Plug>(coc-fix-current)', { desc = 'Quick fix' })
keymap('n', '<leader>re', '<Plug>(coc-codeaction-refactor)', { silent = true, desc = 'Refactor' })
keymap('x', '<leader>r', '<Plug>(coc-codeaction-refactor-selected)', { silent = true, desc = 'Refactor (visual)' })
keymap('n', '<leader>r', '<Plug>(coc-codeaction-refactor-selected)', { silent = true, desc = 'Refactor' })
keymap('n', '<leader>cl', '<Plug>(coc-codelens-action)', { desc = 'Code lens action' })

keymap('n', '<space>a', ':<C-u>CocList diagnostics<cr>', { silent = true, nowait = true, desc = 'CoC diagnostics' })
keymap('n', '<space>e', ':<C-u>CocList extensions<cr>', { silent = true, nowait = true, desc = 'CoC extensions' })
keymap('n', '<space>c', ':<C-u>CocList commands<cr>', { silent = true, nowait = true, desc = 'CoC commands' })
keymap('n', '<space>o', ':<C-u>CocList outline<cr>', { silent = true, nowait = true, desc = 'CoC outline' })
keymap('n', '<space>s', ':<C-u>CocList -I symbols<cr>', { silent = true, nowait = true, desc = 'CoC symbols' })
keymap('n', '<space>j', ':<C-u>CocNext<CR>', { silent = true, nowait = true, desc = 'CoC next' })
keymap('n', '<space>k', ':<C-u>CocPrev<CR>', { silent = true, nowait = true, desc = 'CoC prev' })
keymap('n', '<space>p', ':<C-u>CocListResume<CR>', { silent = true, nowait = true, desc = 'CoC resume' })

keymap('n', '<leader>dh', ':lua require"dap".toggle_breakpoint()<CR>', { desc = 'Toggle breakpoint' })
keymap('n', '<S-j>', ':lua require"dap".step_over()<CR>', { desc = 'Step over' })
keymap('n', '<leader>ds', ':lua require"dap".stop()<CR>', { desc = 'Stop debugging' })
keymap('n', '<leader>dn', ':lua require"dap".continue()<CR>', { desc = 'Continue debugging' })
keymap('n', '<leader>dk', ':lua require"dap".up()<CR>', { desc = 'Debug up' })
keymap('n', '<leader>dj', ':lua require"dap".down()<CR>', { desc = 'Debug down' })
keymap('n', '<leader>d_', ':lua require"dap".disconnect();require"dap".stop();require"dap".run_last()<CR>', { desc = 'Restart debugging' })
keymap('n', '<leader>dr', ':lua require"dap".repl.open({}, "vsplit")<CR><C-w>l', { desc = 'Open REPL' })
keymap('n', '<leader>dw', ':lua require"dap.ui.widgets".hover()<CR>', { desc = 'Debug hover' })
keymap('v', '<leader>di', ':lua require"dap.ui.variables".visual_hover()<CR>', { desc = 'Debug visual hover' })
keymap('s', '<leader>d?', ':lua require"dap.ui.variables".scopes()<CR>', { desc = 'Debug scopes' })
keymap('n', '<leader>df', ':Telescope dap frames<CR>', { desc = 'DAP frames' })
keymap('n', '<leader>db', ':Telescope dap list_breakpoints<CR>', { desc = 'DAP breakpoints' })

_G.show_documentation = function()
	local cw = vim.fn.expand('<cword>')
	if vim.fn.index({'vim', 'help'}, vim.bo.filetype) >= 0 then
		vim.cmd('h ' .. cw)
	elseif vim.api.nvim_eval('coc#rpc#ready()') then
		vim.fn.CocActionAsync('doHover')
	else
		vim.cmd('!' .. vim.o.keywordprg .. ' ' .. cw)
	end
end
