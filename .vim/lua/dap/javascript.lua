local M = {}

function M.setup(dap)
  -- Configure JavaScript/TypeScript
  for _, language in ipairs({ "typescript", "javascript", "javascript.jsx" }) do
    dap.configurations[language] = {
      {
        type = "pwa-node",
        request = "launch",
        name = "Launch file",
        program = "${file}",
        cwd = "${workspaceFolder}",
        sourceMaps = true,
        resolveSourceMapLocations = {
          "${workspaceFolder}/**",
          "!**/node_modules/**"
        },
      },
      {
        type = "pwa-node",
        request = "launch",
        name = "Debug Jest Tests",
        runtimeExecutable = "node",
        runtimeArgs = {
          "./node_modules/jest/bin/jest.js",
          "--config=" .. vim.fn.json_encode({
            transformIgnorePatterns = { "/node_modules/(?!@jridgewell)" },
            testEnvironment = "node",
          }),
          "--no-cache",
          "--testPathPattern",
          "${file}",
          "--runInBand",
        },
        rootPath = "${workspaceFolder}",
        cwd = "${workspaceFolder}",
        console = "integratedTerminal",
        internalConsoleOptions = "neverOpen",
        sourceMaps = true,
        resolveSourceMapLocations = {
          "${workspaceFolder}/**",
          "!**/node_modules/**"
        },
        skipFiles = { "<node_internals>/**", "**/node_modules/**" },
        autoAttachChildProcesses = true,
      },
      {
        type = "pwa-node",
        request = "attach",
        name = "Attach",
        processId = require('dap.utils').pick_process,
        cwd = "${workspaceFolder}",
        sourceMaps = true,
        resolveSourceMapLocations = {
          "${workspaceFolder}/**",
          "!**/node_modules/**"
        },
      }
    }
  end

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

  dap.configurations.javascript = {
    {
      type = "pwa-node",
      request = "launch",
      name = "Debug Jest Tests",
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
    }
  }

  dap.configurations.typescript = dap.configurations.javascript
  dap.configurations["javascript.jsx"] = dap.configurations.javascript
end

return M 