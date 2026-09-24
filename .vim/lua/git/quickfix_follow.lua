local M = {}

local function open_entry(quickfix_win, entry_index)
  vim.cmd("silent! " .. entry_index .. "cc")
  local source_win = vim.api.nvim_get_current_win()
  if source_win == quickfix_win then
    return
  end

  local source_buf = vim.api.nvim_win_get_buf(source_win)
  if vim.bo[source_buf].filetype == "" then
    local filetype = vim.filetype.match({ buf = source_buf })
    if filetype then
      vim.bo[source_buf].filetype = filetype
    end
  end
  pcall(vim.treesitter.start, source_buf)
  vim.api.nvim_win_call(source_win, function()
    vim.cmd("silent! GitGutter")
  end)
  pcall(function()
    require("gitsigns.actions").attach({ bufnr = source_buf, trigger = "QuickfixFollow" })
  end)
end

function M.preview(quickfix_win)
  local entry_index = vim.api.nvim_win_get_cursor(quickfix_win)[1]
  local entry = vim.fn.getqflist({ idx = 0, items = 0 }).items[entry_index]
  if not entry then
    return
  end

  if type(entry.user_data) == "table" and entry.user_data.git_target then
    require("git.branch_diff_quickfix").open_entry(entry.user_data)
  else
    open_entry(quickfix_win, entry_index)
  end

  if vim.api.nvim_win_is_valid(quickfix_win) then
    vim.api.nvim_set_current_win(quickfix_win)
  end
end

function M.setup()
  local quickfix_follow = vim.api.nvim_create_augroup("QuickfixFollow", { clear = true })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = quickfix_follow,
    callback = function(args)
      local quickfix_win = vim.api.nvim_get_current_win()
      if vim.bo[args.buf].buftype == "quickfix" and vim.fn.win_gettype(quickfix_win) == "quickfix" then
        M.preview(quickfix_win)
      end
    end,
  })
end

return M
