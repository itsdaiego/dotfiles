return {
  "williamboman/mason.nvim",
  dependencies = {
    "williamboman/mason-registry",
    "jay-babu/mason-nvim-dap.nvim",
  },
  cmd = "Mason",
  opts = {
    ensure_installed = {
      "js-debug-adapter",
      "delve",
      "debugpy"
    },
    ui = {
      border = "rounded",
      icons = {
        package_installed = "✓",
        package_pending = "➜",
        package_uninstalled = "✗"
      }
    }
  },
  config = function(_, opts)
    require("mason").setup(opts)
    local mr = require("mason-registry")
    for _, tool in ipairs(opts.ensure_installed) do
      local p = mr.get_package(tool)
      if not p:is_installed() then
        p:install()
      end
    end
  end,
}
