local M = {}

local function git_output(cwd, args)
  local output = vim.fn.systemlist(vim.list_extend({ "git", "-C", cwd }, args))
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return output
end

local function current_git_root()
  local paths = { vim.fn.getcwd() }
  local buffer_path = vim.api.nvim_buf_get_name(0)
  if buffer_path ~= "" then
    table.insert(paths, 1, vim.fs.dirname(buffer_path))
  end

  for _, path in ipairs(paths) do
    local output = git_output(path, { "rev-parse", "--show-toplevel" })
    if output and output[1] then
      return output[1]
    end
  end
end

local function quickfix_commit_files(commit)
  local files = git_output(commit.cwd, {
    "diff-tree", "--root", "--no-commit-id", "-r", "--name-only", commit.hash,
  })
  if not files then
    vim.notify("Could not list files for " .. commit.hash, vim.log.levels.ERROR, { title = "Git history" })
    return
  end

  local items = vim.tbl_map(function(file)
    return { filename = commit.cwd .. "/" .. file, lnum = 1, text = commit.subject }
  end, files)
  vim.fn.setqflist({}, "r", { items = items, title = "Files changed by " .. commit.short })
  vim.cmd("copen")
end

local function pick_commits(source)
  local commits = git_output(source.cwd, {
    "log", "--date-order", "--pretty=format:%H%x09%h%x09%s", source.ref,
  })
  if not commits then
    vim.notify("Could not list commits for " .. source.label, vim.log.levels.ERROR, { title = "Git history" })
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local previewers = require("telescope.previewers")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local config = require("telescope.config").values

  pickers.new({}, {
    prompt_title = "Commits: " .. source.label,
    finder = finders.new_table({
      results = commits,
      entry_maker = function(line)
        local hash, short, subject = line:match("([^\t]+)\t([^\t]+)\t?(.*)")
        local commit = {
          cwd = source.cwd,
          hash = hash,
          short = short,
          subject = subject,
        }
        return {
          value = commit,
          display = short .. " " .. subject,
          ordinal = short .. " " .. subject,
        }
      end,
    }),
    sorter = config.generic_sorter({}),
    previewer = previewers.new_termopen_previewer({
      get_command = function(entry)
        return {
          "git", "-C", entry.value.cwd, "--no-pager", "show", "--find-renames",
          "--format=fuller", "--patch", entry.value.hash,
        }
      end,
    }),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local commit = action_state.get_selected_entry().value
        actions.close(prompt_bufnr)
        quickfix_commit_files(commit)
      end)
      return true
    end,
  }):find()
end

local function pick_git_source()
  local root = current_git_root()
  if not root then
    vim.notify("Open a file inside a Git repository first.", vim.log.levels.WARN, { title = "Git history" })
    return
  end

  local sources = {}
  for _, line in ipairs(git_output(root, {
    "for-each-ref", "--sort=-committerdate",
    "--format=%(refname:short)%09%(objectname:short)%09%(subject)", "refs/heads",
  }) or {}) do
    local name, short, subject = line:match("([^\t]+)\t([^\t]+)\t?(.*)")
    if name then
      table.insert(sources, {
        cwd = root,
        ref = name,
        label = "branch " .. name,
        display = "branch    " .. name .. "  " .. short .. " " .. subject,
      })
    end
  end

  local worktree
  local function add_worktree()
    if not worktree or not worktree.path or not vim.uv.fs_stat(worktree.path) then
      return
    end
    local ref = worktree.branch or "HEAD"
    table.insert(sources, {
      cwd = worktree.path,
      ref = ref,
      label = "worktree " .. worktree.path,
      display = "worktree  " .. worktree.path .. "  " .. ref,
    })
  end

  for _, line in ipairs(git_output(root, { "worktree", "list", "--porcelain" }) or {}) do
    if line:sub(1, 9) == "worktree " then
      add_worktree()
      worktree = { path = line:sub(10) }
    elseif line:sub(1, 7) == "branch " and worktree then
      worktree.branch = line:sub(8):gsub("^refs/heads/", "")
    elseif line == "" then
      add_worktree()
      worktree = nil
    end
  end
  add_worktree()

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local config = require("telescope.config").values

  pickers.new({}, {
    prompt_title = "Git branch or worktree",
    finder = finders.new_table({
      results = sources,
      entry_maker = function(source)
        return { value = source, display = source.display, ordinal = source.display }
      end,
    }),
    sorter = config.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local source = action_state.get_selected_entry().value
        actions.close(prompt_bufnr)
        pick_commits(source)
      end)
      return true
    end,
  }):find()
end

function M.setup()
  vim.api.nvim_create_user_command("GitCommitHistory", pick_git_source, { force = true })
  vim.keymap.set("n", "<leader>gh", pick_git_source, { desc = "Git commit history" })
end

return M
