local M = {}

function M.setup(dap)
  dap.adapters["pwa-node"] = {
    type = "server",
    host = "localhost",
    port = "${port}",
    executable = {
      command = "node",
      args = {
        require("mason-registry").get_package("js-debug-adapter"):get_install_path() .. "/js-debug/src/dapDebugServer.js",
        "${port}"
      },
    }
  }

  -- Base configurations for all JavaScript-like languages
  local base_config = {
    {
      -- Simple script debugging
      type = "pwa-node",
      request = "launch",
      name = "Debug Script",
      program = function()
        return vim.fn.input('Path to script: ', vim.fn.expand('%:p'), 'file')
      end,
      args = function()
        local args_string = vim.fn.input('Arguments: ')
        return vim.split(args_string, ' ', { trimempty = true })
      end,
      cwd = "${workspaceFolder}",
      sourceMaps = true,
      protocol = "inspector",
      console = "integratedTerminal",
      skipFiles = { "<node_internals>/**", "**/node_modules/**" },
      resolveSourceMapLocations = {
        "${workspaceFolder}/**",
        "!**/node_modules/**"
      },
    },
    {
      -- Jest test debugging
      type = "pwa-node",
      request = "launch",
      name = "Debug Jest Test",
      runtimeExecutable = "node",
      runtimeArgs = {
        "./node_modules/jest/bin/jest.js",
        "--runInBand",
        "--no-cache",
        "${file}"
      },
      rootPath = "${workspaceFolder}",
      cwd = "${workspaceFolder}",
      console = "integratedTerminal",
      internalConsoleOptions = "neverOpen",
      sourceMaps = true,
      protocol = "inspector",
      skipFiles = { "<node_internals>/**" },
      resolveSourceMapLocations = {
        "${workspaceFolder}/**",
        "!**/node_modules/**"
      }
    },
    {
      -- Remote debugging
      type = "pwa-node",
      request = "attach",
      name = "Attach to Remote",
      address = function()
        return vim.fn.input('Host [localhost]: ') or 'localhost'
      end,
      port = function()
        return tonumber(vim.fn.input('Port [9229]: ')) or 9229
      end,
      remoteRoot = function()
        return vim.fn.input('Remote root directory: ')
      end,
      localRoot = "${workspaceFolder}",
      sourceMaps = true,
      protocol = "inspector",
      resolveSourceMapLocations = {
        "${workspaceFolder}/**",
        "!**/node_modules/**"
      },
    },
    {
      -- Process attach
      type = "pwa-node",
      request = "attach",
      name = "Attach to Process",
      processId = require('dap.utils').pick_process,
      cwd = "${workspaceFolder}",
      sourceMaps = true,
      resolveSourceMapLocations = {
        "${workspaceFolder}/**",
        "!**/node_modules/**"
      },
    }
  }

  -- Apply the base config to all JavaScript-like languages
  for _, language in ipairs({ "typescript", "javascript", "javascript.jsx" }) do
    dap.configurations[language] = base_config
  end

  -- Chrome debugging configuration
  dap.configurations.chrome = {
    {
      type = "pwa-chrome",
      request = "attach",
      name = "Attach to Chrome",
      program = "${file}",
      cwd = "${workspaceFolder}",
      sourceMaps = true,
      webRoot = "${workspaceFolder}",
    }
  }
end

return M 