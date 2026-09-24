local M = {}

function M.setup()
  require("git.quickfix_follow").setup()

  vim.keymap.set("n", "<leader>gd", function()
    local branch_diff = require("git.branch_diff_quickfix")
    branch_diff.setup()
    branch_diff.select()
  end, { desc = "Branch diff to quickfix" })
  vim.keymap.set("n", "<leader>gq", function()
    require("git.branch_diff_quickfix").close()
  end, { desc = "Close branch quickfix" })
end

return M
