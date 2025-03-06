local M = {}

function M.setup(dap)
  dap.adapters.python = {
    type = 'executable',
    command = '/Users/daiego/Library/Caches/pypoetry/virtualenvs/corrogo-bwpqepX3-py3.12/bin/python',
    args = { '-m', 'debugpy.adapter' },
  }

  dap.configurations.python = {
    {
      -- Django configuration
      type = 'python',
      request = 'launch',
      name = 'Django Test',
      program = "${workspaceFolder}/shipwell_backend/manage.py",
      args = function()
        return { 'test', vim.fn.input('Test path: '), '--failfast', '--keepdb' }
      end,
      django = true,
      justMyCode = false,
      console = 'integratedTerminal',
      pythonPath = function()
        -- Try to find poetry venv
        local poetry_venv = '/Users/daiego/Library/Caches/pypoetry/virtualenvs/corrogo-bwpqepX3-py3.12/bin/python'
        if vim.fn.executable(poetry_venv) == 1 then
          return poetry_venv
        end
        -- Fallback to system python
        return '/usr/bin/python3'
      end,
      purpose = { "debug-test" },
      postDebugTask = "stopDebugging",
      showReturnValue = true,
      redirectOutput = true,
      stopOnEntry = false,
      subProcess = true,
    },
    {
      -- FastAPI Test configuration
      type = 'python',
      request = 'launch',
      name = 'FastAPI Test',
      module = 'pytest',
      args = function()
        local args = { vim.fn.input('Test path: ') }
        return args
      end,
      pythonPath = function()
        -- Try to find poetry venv
        local poetry_venv = '/Users/daiego/Library/Caches/pypoetry/virtualenvs/corrogo-bwpqepX3-py3.12/bin/python'
        if vim.fn.executable(poetry_venv) == 1 then
          return poetry_venv
        end
        return '/usr/bin/python3'
      end,
      console = 'integratedTerminal',
      justMyCode = false,
      env = {
        PYTHONPATH = "${workspaceFolder}"
      },
      showReturnValue = true,
      redirectOutput = true,
      stopOnEntry = false,
    },
    {
      -- FastAPI configuration
      type = 'python',
      request = 'launch',
      name = 'FastAPI',
      module = 'uvicorn',
      args = function()
        return {
          'main:app',
          '--port',
          '3000',
          '--host',
          '0.0.0.0',
          -- '--reload',
        }
      end,
      pythonPath = function()
        -- Try to find venv relative to current file
        local relative_venv = vim.fn.getcwd() .. '/venv/bin/python'
        if vim.fn.executable(relative_venv) == 1 then
          return relative_venv
        end
        vim.notify("Could not find venv using system's default")
        return '/usr/bin/python3'
      end,
      console = 'integratedTerminal',
      justMyCode = false,
      env = function()
        -- Try to load .env file from workspace
        local env = { PYTHONPATH = "${workspaceFolder}" }  -- Keep the default PYTHONPATH
        local env_file = io.open(vim.fn.getcwd() .. "/.env", "r")
        if env_file then
          for line in env_file:lines() do
            -- Skip comments and empty lines
            if not line:match("^%s*#") and line:match("%S") then
              local key, value = line:match("^%s*(%S+)%s*=%s*(.+)%s*$")
              if key and value then
                -- Remove quotes if they exist
                value = value:gsub("^[\"'](.+)[\"']$", "%1")
                env[key] = value
              end
            end
          end
          env_file:close()
        end
        return env
      end,
      subProcess = true,
      showReturnValue = true,
      redirectOutput = true,
      stopOnEntry = false,
    },
  }
end

return M 
