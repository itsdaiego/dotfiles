local M = {}

function M.setup(dap)
  -- nvim-dap-go already provides the basic configurations
  -- The path issue is likely because delve needs the process to be built with debug symbols
  -- and run from the correct directory
  
  local custom_configs = {
    {
      type = 'go',
      name = 'Debug Test (Verbose Output)',
      request = 'launch',
      mode = 'test',
      program = '${fileDirname}',
      args = { '-test.v' },
      buildFlags = '-gcflags="all=-N -l"',
    },
  }
  
  -- Just add our custom configs, don't override the default attach
  -- The issue is likely with how you're running the process, not the config
  vim.defer_fn(function()
    if dap.configurations.go then
      for _, config in ipairs(custom_configs) do
        table.insert(dap.configurations.go, config)
      end
    end
  end, 100)
end

return M
