local M = {}

-- Dynamic Python path detection (shared with python.lua)
local function find_python_executable()
    local cwd = vim.fn.getcwd()
    
    -- 1. Check for .venv in current directory
    local local_venv = cwd .. '/.venv/bin/python'
    if vim.fn.executable(local_venv) == 1 then
        return local_venv
    end
    
    -- 2. Check for venv in current directory
    local local_venv_alt = cwd .. '/venv/bin/python'
    if vim.fn.executable(local_venv_alt) == 1 then
        return local_venv_alt
    end
    
    -- 3. Try to detect Poetry virtualenv
    local handle = io.popen("cd " .. cwd .. " && poetry env info --path 2>/dev/null")
    if handle then
        local poetry_path = handle:read("*a"):gsub("%s+", "")
        handle:close()
        if poetry_path ~= "" then
            local poetry_python = poetry_path .. '/bin/python'
            if vim.fn.executable(poetry_python) == 1 then
                return poetry_python
            end
        end
    end
    
    -- 4. Check common Poetry cache locations for known projects
    local poetry_patterns = {
        '/Users/daiego/Library/Caches/pypoetry/virtualenvs/corrogo-*/bin/python',
        '/Users/daiego/Library/Caches/pypoetry/virtualenvs/erp-gateway-*/bin/python',
        '/Users/daiego/Library/Caches/pypoetry/virtualenvs/shipwell-*/bin/python'
    }
    
    for _, pattern in ipairs(poetry_patterns) do
        local expanded = vim.fn.glob(pattern)
        if expanded ~= "" then
            local paths = vim.split(expanded, '\n')
            for _, path in ipairs(paths) do
                if vim.fn.executable(path) == 1 then
                    return path
                end
            end
        end
    end

    -- 5. Try pyenv if available
    local pyenv_python = vim.fn.expand("~/.pyenv/versions/3.10.0/bin/python3")
    if vim.fn.executable(pyenv_python) == 1 then
        return pyenv_python
    end

    -- 6. Fallback to system python
    return '/usr/bin/python3'
end

local function detect_python_test(node, ts_utils)
  local is_pytest = false
  local test_func, test_class

  while node do
    if node:type() == "function_definition" then
      local name_node = node:child(1)
      if name_node then
        local func_name = ts_utils.get_node_text(name_node)[1]
        -- pytest starts with "async def" so we need to check for the next node
        if func_name == "def" then
          is_pytest = true
          func_name = ts_utils.get_node_text(node:child(2))[1]
        end
        vim.notify(func_name, vim.log.levels.INFO)
        if vim.startswith(func_name, "test_") then
          test_func = func_name
        end
      end
    elseif node:type() == "class_definition" then
      local name_node = node:child(1)
      if name_node then test_class = ts_utils.get_node_text(name_node)[1] end
    end
    node = node:parent()
  end

  return test_func, test_class, is_pytest
end

local function detect_go_test(node, ts_utils)
  local test_func
  while node do
    if node:type() == "function_declaration" then
      local name_node = node:child(1)
      if name_node then
        local func_name = ts_utils.get_node_text(name_node)[1]
        if vim.startswith(func_name, "Test") then
          test_func = func_name
          break
        end
      end
    end
    node = node:parent()
  end
  return test_func
end

local function detect_js_test(node, ts_utils)
  local test_func
  while node do
    if node:type() == "expression_statement" then
      local call = node:child(0)
      if call and call:type() == "call_expression" then
        local func = call:child(0)
        if func and func:type() == "identifier" then
          local func_name = ts_utils.get_node_text(func)[1]
          if func_name == "it" or func_name == "test" then
            local args = call:child(1)
            if args and args:named_child_count() > 0 then
              local desc = args:named_child(0)
              if desc then
                test_func = vim.trim(ts_utils.get_node_text(desc)[1], '"\'')
                break
              end
            end
          end
        end
      end
    elseif node:type() == "call_expression" then
      local func = node:child(0)
      if func and func:type() == "identifier" then
        local func_name = ts_utils.get_node_text(func)[1]
        if func_name == "it" or func_name == "test" then
          local args = node:child(1)
          if args and args:named_child_count() > 0 then
            local desc = args:named_child(0)
            if desc then
              test_func = vim.trim(ts_utils.get_node_text(desc)[1], '"\'')
              break
            end
          end
        end
      end
    end
    node = node:parent()
  end
  return test_func
end

function M.run_nearest_test(dap)
  local ts_utils = require('nvim-treesitter.ts_utils')
  local node = ts_utils.get_node_at_cursor()

  if not node then
    vim.notify("No treesitter node found at cursor", vim.log.levels.ERROR)
    return
  end

  local filetype = vim.bo.filetype

  if filetype == "python" then
    local test_func, test_class, is_pytest = detect_python_test(node, ts_utils)

    if not test_class or not test_func then
      vim.notify("No test function found at cursor position", vim.log.levels.ERROR)
      return
    end

    if is_pytest then
      local file_path = vim.fn.expand('%:p')
      local test_path = test_class 
      and string.format('%s::%s::%s', file_path, test_class, test_func)
      or string.format('%s::%s', file_path, test_func)

      vim.notify(string.format("Running pytest: %s", test_path), vim.log.levels.INFO)

      dap.run({
        type = 'python',
        request = 'launch',
        name = 'FastAPI Test',
        module = 'pytest',
        args = { test_path },
        pythonPath = find_python_executable,
        console = 'integratedTerminal',
        justMyCode = false,
        env = {
          PYTHONPATH = "${workspaceFolder}",
          INITIALIZE_TEST_DB = "1"
        },
        showReturnValue = true,
        redirectOutput = true,
        stopOnEntry = false,
        subProcess = true,
        exceptionOptions = {
          { path = { "pytest.*" }, breakMode = "never" },
          { path = { "pluggy.*" }, breakMode = "never" },
          { path = { "_pytest.*" }, breakMode = "never" },
          { path = { "<module>" }, breakMode = "never" },
          { 
            path = { "<module>" },
            breakMode = "never",
            exceptionTypes = { "SystemExit" }
          }
        }
      })
    else
      local test_path = string.format('%s.%s.%s', vim.fn.expand('%:r'):gsub('/', '.'), test_class, test_func)
      test_path = test_path:gsub('shipwell_backend.', '')
      vim.notify(string.format("Running Django test: %s", test_path), vim.log.levels.INFO)

      dap.run({
        type = 'python',
        request = 'launch',
        name = 'Django Test',
        program = vim.fn.getcwd() .. "/shipwell_backend/manage.py",
        -- program = vim.fn.getcwd() .. "/admin_buy/manage.py",
        args = { 'test', test_path, '--failfast', '--keepdb' },
        django = true,
        justMyCode = false,
        console = 'integratedTerminal',
        pythonPath = find_python_executable,
        cwd = vim.fn.getcwd(),
        purpose = { "debug-test" },
        postDebugTask = "stopDebugging",
        showReturnValue = true,
        redirectOutput = true,
        stopOnEntry = false,
        subProcess = true,
      })
    end

  elseif filetype == "go" then
    local test_func = detect_go_test(node, ts_utils)

    if not test_func then
      vim.notify("No test function found at cursor position", vim.log.levels.ERROR)
      return
    end

    vim.notify(string.format("Running Go test: %s", test_func), vim.log.levels.INFO)

    dap.run({
      type = 'go',
      request = 'launch',
      name = 'Debug Go Test',
      mode = 'test',
      program = '${fileDirname}',
      args = {'-test.run', test_func},
      backend = 'default',
      gcflags = {'all=-N'},
    })

  elseif filetype == "typescript" or filetype == "javascript" or filetype == "javascript.jsx" then
    local test_func = detect_js_test(node, ts_utils)

    if not test_func then
      vim.notify("No test function found at cursor position", vim.log.levels.ERROR)
      return
    end

    test_func = test_func:gsub("^['\"]", ""):gsub("['\"]$", "")
    vim.notify(string.format("Running Jest test: %s", test_func), vim.log.levels.INFO)

    dap.run({
      type = "pwa-node",
      request = "launch",
      name = "Debug Jest Test",
      runtimeExecutable = "node",
      runtimeArgs = {
        "./node_modules/jest/bin/jest.js",
        "--runInBand",
        "--no-cache",
        "--config=" .. vim.fn.json_encode({
          transformIgnorePatterns = { "/node_modules/(?!@jridgewell)" },
          testEnvironment = "node",
        }),
        "--testNamePattern",
        "" .. test_func .. "",
        "${file}"
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
      protocol = "inspector",
      skipFiles = { "<node_internals>/**", "**/node_modules/**" },
    })
  end
end

return M 
