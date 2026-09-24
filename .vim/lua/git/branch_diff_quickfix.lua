local M = {}

local sign_group = "BranchDiffQuickfix"
local reviewed_buffers = {}
local review_hunks = {}
local snapshot_buffers = {}
local return_state

local function repo_root(path)
  local root = vim.fn.systemlist({ "git", "-C", path, "rev-parse", "--show-toplevel" })
  if vim.v.shell_error == 0 and root[1] then
    return root[1]
  end
end

local function current_repo_root()
  if vim.b.git_review_root then
    return vim.b.git_review_root
  end
  local buffer_name = vim.api.nvim_buf_get_name(0)
  local candidates = { vim.fn.getcwd() }
  if buffer_name ~= "" then
    table.insert(candidates, 1, vim.fs.dirname(vim.fs.normalize(buffer_name)))
  end

  for _, path in ipairs(candidates) do
    local root = repo_root(path)
    if root then
      return root
    end
  end
end

local function default_base(root)
  local base = vim.fn.systemlist({ "git", "-C", root, "symbolic-ref", "--short", "refs/remotes/origin/HEAD" })
  if vim.v.shell_error == 0 and base[1] then
    return base[1]
  end
  return "master"
end

local function choices(root)
  local result = {}
  local worktree
  local worktree_lines = vim.fn.systemlist({ "git", "-C", root, "worktree", "list", "--porcelain" })
  for _, line in ipairs(worktree_lines) do
    local path = line:match("^worktree (.+)$")
    local branch = line:match("^branch refs/heads/(.+)$")
    if path then
      worktree = { root = path }
    elseif branch and worktree then
      worktree.ref = branch
    elseif line == "" and worktree then
      if worktree.ref then
        worktree.label = "Worktree  " .. worktree.ref .. "  —  " .. worktree.root
        table.insert(result, worktree)
      end
      worktree = nil
    end
  end
  if worktree and worktree.ref then
    worktree.label = "Worktree  " .. worktree.ref .. "  —  " .. worktree.root
    table.insert(result, worktree)
  end

  local branches = vim.fn.systemlist({ "git", "-C", root, "for-each-ref", "--format=%(refname:short)", "refs/heads" })
  for _, branch in ipairs(branches) do
    table.insert(result, {
      root = root,
      ref = branch,
      virtual = true,
      label = "Branch     " .. branch,
    })
  end
  return result
end

local function set_gitgutter(buffer, enabled)
  vim.api.nvim_buf_call(buffer, function()
    vim.cmd("silent! " .. (enabled and "GitGutterBufferEnable" or "GitGutterBufferDisable"))
  end)
end

local function clear_hunks()
  for buffer in pairs(reviewed_buffers) do
    if vim.api.nvim_buf_is_valid(buffer) then
      vim.fn.sign_unplace(sign_group, { buffer = buffer })
      set_gitgutter(buffer, true)
    end
  end
  reviewed_buffers = {}
  review_hunks = {}
end

local function wipe_snapshots()
  for _, buffer in pairs(snapshot_buffers) do
    if vim.api.nvim_buf_is_valid(buffer) then
      vim.api.nvim_buf_delete(buffer, { force = true })
    end
  end
  snapshot_buffers = {}
end

-- A nofile scratch buffer keeps the builtin LSP from attaching to a Git snapshot.
local function snapshot_buffer(root, ref, path)
  local key = ref .. ":" .. path
  local existing = snapshot_buffers[key]
  if existing and vim.api.nvim_buf_is_valid(existing) then
    return existing
  end

  local lines = vim.fn.systemlist({ "git", "-C", root, "show", key })
  if vim.v.shell_error ~= 0 then
    lines = { "Cannot read " .. key }
  end

  local buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[buffer].bufhidden = "hide"
  -- ALE starts its own pyright client even on nofile buffers.
  vim.b[buffer].ale_enabled = 0
  vim.b[buffer].coc_enabled = 0
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.bo[buffer].modifiable = false
  vim.api.nvim_buf_set_name(buffer, "gitreview://" .. ref:sub(1, 10) .. "/" .. path)
  vim.b[buffer].git_review_root = root
  local filetype = vim.filetype.match({ filename = path, buf = buffer })
  if filetype then
    vim.bo[buffer].filetype = filetype
  end
  snapshot_buffers[key] = buffer
  return buffer
end

local function review_window()
  if return_state and vim.api.nvim_win_is_valid(return_state.win) then
    return return_state.win
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.fn.win_gettype(win) == "" then
      return win
    end
  end
end

local function source_has_path(root, ref, path)
  vim.fn.system({ "git", "-C", root, "cat-file", "-e", ref .. ":" .. path })
  return vim.v.shell_error == 0
end

-- Mirrors vim-gitgutter's s:process_hunk so review signs match the normal gutter.
local function hunk_signs(old_start, old_count, new_start, new_count, source_is_base)
  local signs = {}
  if source_is_base then
    for offset = 0, old_count - 1 do
      table.insert(signs, { old_start + offset, "GitGutterLineRemoved" })
    end
  elseif old_count == 0 then
    for offset = 0, new_count - 1 do
      table.insert(signs, { new_start + offset, "GitGutterLineAdded" })
    end
  elseif new_count == 0 then
    if new_start == 0 then
      table.insert(signs, { 1, "GitGutterLineRemovedFirstLine" })
    else
      table.insert(signs, { new_start, "GitGutterLineRemoved" })
    end
  else
    for offset = 0, new_count - 1 do
      local name = offset < old_count and "GitGutterLineModified" or "GitGutterLineAdded"
      table.insert(signs, { new_start + offset, name })
    end
    if old_count > new_count then
      signs[#signs][2] = "GitGutterLineModifiedRemoved"
    end
  end
  return signs
end

function M.show_hunks(buffer, review)
  if not vim.api.nvim_buf_is_valid(buffer) then
    return
  end

  vim.fn.sign_unplace(sign_group, { buffer = buffer })
  set_gitgutter(buffer, false)
  reviewed_buffers[buffer] = true
  local hunk_starts = {}
  review_hunks[buffer] = hunk_starts

  local command = { "git", "-C", review.git_root, "diff", "--no-ext-diff", "--no-color", "--unified=0", review.git_base }
  if review.virtual then
    table.insert(command, review.git_target)
  end
  vim.list_extend(command, { "--", review.git_path })

  local priority = (vim.g.gitgutter_sign_priority or 10) + 1
  for _, line in ipairs(vim.fn.systemlist(command)) do
    local old_start, old_count, new_start, new_count = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
    if new_start then
      local signs = hunk_signs(
        tonumber(old_start),
        tonumber(old_count) or 1,
        tonumber(new_start),
        tonumber(new_count) or 1,
        review.source_is_base
      )
      for _, sign in ipairs(signs) do
        vim.fn.sign_place(0, sign_group, sign[2], buffer, { lnum = sign[1], priority = priority })
      end
      if signs[1] then
        table.insert(hunk_starts, signs[1][1])
      end
    end
  end
end

-- Returns false outside a reviewed buffer so the caller falls back to Gitsigns.
function M.nav_hunk(direction)
  local hunk_starts = review_hunks[vim.api.nvim_get_current_buf()]
  if not hunk_starts then
    return false
  end
  if #hunk_starts == 0 then
    vim.notify("No hunks", vim.log.levels.INFO, { title = "Git review" })
    return true
  end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  local target
  if direction == "next" then
    target = hunk_starts[1]
    for _, start in ipairs(hunk_starts) do
      if start > line then
        target = start
        break
      end
    end
  else
    target = hunk_starts[#hunk_starts]
    for index = #hunk_starts, 1, -1 do
      if hunk_starts[index] < line then
        target = hunk_starts[index]
        break
      end
    end
  end
  vim.api.nvim_win_set_cursor(0, { target, 0 })
  vim.cmd("normal! zz")
  return true
end

function M.open_entry(review)
  local win = review_window()
  if not win then
    return
  end

  local buffer
  if review.virtual then
    buffer = snapshot_buffer(review.git_root, review.source_ref, review.git_path)
  else
    buffer = vim.fn.bufadd(review.git_root .. "/" .. review.git_path)
  end
  if vim.api.nvim_win_get_buf(win) ~= buffer then
    vim.api.nvim_win_call(win, function()
      vim.cmd("silent! keepjumps buffer " .. buffer)
    end)
  end
  if vim.bo[buffer].filetype == "" then
    local filetype = vim.filetype.match({ buf = buffer })
    if filetype then
      vim.bo[buffer].filetype = filetype
    end
  end
  pcall(vim.treesitter.start, buffer)
  M.show_hunks(buffer, review)
end

local function open_review(review)
  local names = vim.fn.systemlist({ "git", "-C", review.root, "diff", "--name-only", review.base, review.target, "--" })
  if vim.v.shell_error ~= 0 then
    vim.notify(table.concat(names, "\n"), vim.log.levels.ERROR, { title = "Git review" })
    return
  end

  local items = {}
  for _, path in ipairs(names) do
    local deleted = not source_has_path(review.root, review.target, path)
    local virtual = review.virtual or deleted
    local source_ref = deleted and review.base or review.target
    -- Pointing the entry at the reviewed buffer keeps Enter, clicks and :cc on the buffer with the signs.
    local item = {
      lnum = 1,
      module = path,
      user_data = {
        git_root = review.root,
        git_base = review.base,
        git_target = review.target,
        git_path = path,
        virtual = virtual,
        source_ref = source_ref,
        source_is_base = deleted,
      },
    }
    if virtual then
      item.bufnr = snapshot_buffer(review.root, source_ref, path)
    else
      item.filename = review.root .. "/" .. path
    end
    table.insert(items, item)
  end

  if #items == 0 then
    vim.notify(review.label .. " has no changes.", vim.log.levels.INFO, { title = "Git review" })
    return
  end

  clear_hunks()
  if not return_state then
    return_state = {
      win = vim.api.nvim_get_current_win(),
      buf = vim.api.nvim_get_current_buf(),
      cursor = vim.api.nvim_win_get_cursor(0),
    }
  end
  vim.fn.setqflist({}, " ", { title = review.label, items = items })
  vim.cmd("botright copen")
  require("git.quickfix_follow").preview(vim.api.nvim_get_current_win())
end

local function select_commit(choice, base, ref)
  local lines = vim.fn.systemlist({ "git", "-C", choice.root, "log", "--format=%H%x1f%s", base .. ".." .. ref })
  local commits = {}
  for _, line in ipairs(lines) do
    local hash, subject = line:match("^(%x+)%c(.+)$")
    if hash and subject then
      table.insert(commits, { hash = hash, subject = subject })
    end
  end

  if #commits == 0 then
    vim.notify("No commits to review.", vim.log.levels.INFO, { title = "Git review" })
    return
  end

  vim.ui.select(commits, {
    prompt = "Review commit:",
    format_item = function(commit) return commit.hash:sub(1, 10) .. "  " .. commit.subject end,
  }, function(commit)
    if not commit then
      return
    end
    vim.schedule(function() open_review({
      root = choice.root,
      base = commit.hash .. "^",
      target = commit.hash,
      virtual = true,
      label = "Commit: " .. commit.hash:sub(1, 10) .. "  " .. commit.subject,
    }) end)
  end)
end

local function select_scope(choice)
  local base = default_base(choice.root)
  local ref = choice.virtual and choice.ref or "HEAD"
  vim.ui.select({
    { label = "Whole branch", kind = "branch" },
    { label = "One commit", kind = "commit" },
  }, {
    prompt = "Review " .. choice.ref .. ":",
    format_item = function(scope) return scope.label end,
  }, function(scope)
    if not scope then
      return
    end
    if scope.kind == "commit" then
      vim.schedule(function() select_commit(choice, base, ref) end)
      return
    end
    local merge_base = vim.fn.systemlist({ "git", "-C", choice.root, "merge-base", base, ref })[1]
    if vim.v.shell_error ~= 0 or not merge_base then
      vim.notify("No merge-base between " .. base .. " and " .. ref .. ".", vim.log.levels.ERROR, { title = "Git review" })
      return
    end
    vim.schedule(function() open_review({
      root = choice.root,
      base = merge_base,
      target = ref,
      virtual = choice.virtual,
      label = "Branch: " .. choice.ref .. " (" .. base .. "..." .. ref .. ")",
    }) end)
  end)
end

function M.select()
  local root = current_repo_root()
  if not root then
    vim.notify("Open a file in a Git repository first.", vim.log.levels.WARN, { title = "Git review" })
    return
  end

  vim.ui.select(choices(root), {
    prompt = "Select worktree or branch:",
    format_item = function(choice) return choice.label end,
  }, function(choice)
    if choice then
      vim.schedule(function() select_scope(choice) end)
    end
  end)
end

function M.close()
  vim.cmd("cclose")
  clear_hunks()
  if return_state and vim.api.nvim_win_is_valid(return_state.win) then
    vim.api.nvim_set_current_win(return_state.win)
    if vim.api.nvim_buf_is_valid(return_state.buf) then
      vim.api.nvim_win_set_buf(return_state.win, return_state.buf)
      local line_count = vim.api.nvim_buf_line_count(return_state.buf)
      local line = math.max(1, math.min(return_state.cursor[1], line_count))
      local text = vim.api.nvim_buf_get_lines(return_state.buf, line - 1, line, false)[1] or ""
      local column = math.min(return_state.cursor[2], #text)
      vim.api.nvim_win_set_cursor(return_state.win, { line, column })
    end
  end
  return_state = nil
  wipe_snapshots()
end

function M.setup()
  vim.api.nvim_create_user_command("BranchDiffQuickfix", M.select, { force = true })
  vim.api.nvim_create_user_command("BranchDiffQuickfixClose", M.close, { force = true })
end

return M
