local M = {}

local function current_file_path()
  local file_path = vim.fn.expand('%:p')
  if file_path == '' then
    return nil
  end

  return file_path
end

local function current_file_dir()
  local file_path = current_file_path()
  if file_path then
    return vim.fn.fnamemodify(file_path, ':h')
  end

  return vim.fn.getcwd()
end

local function find_upward(start_dir, entries)
  local path = start_dir

  while path and path ~= '' do
    for _, entry in ipairs(entries) do
      local full_path = path .. '/' .. entry
      if vim.fn.filereadable(full_path) == 1 or vim.fn.isdirectory(full_path) == 1 then
        return path
      end
    end

    local parent = vim.fn.fnamemodify(path, ':h')
    if parent == path then
      break
    end
    path = parent
  end
end

local function find_python_project_root(start_dir)
  return find_upward(start_dir, {
    'pyproject.toml',
    'pytest.ini',
    'setup.cfg',
    'tox.ini',
    'requirements.txt',
    '.venv',
    'venv',
  })
end

local function find_django_root(start_dir)
  return find_upward(start_dir, { 'manage.py' })
end

local function resolve_python_root(start_dir)
  return find_django_root(start_dir) or find_python_project_root(start_dir) or vim.fn.getcwd()
end

local function relative_to(base, path)
  local prefix = base .. '/'
  if vim.startswith(path, prefix) then
    return path:sub(#prefix + 1)
  end

  return path
end

local function shell_command_output(root, command)
  local handle = io.popen(string.format('cd %s && %s', vim.fn.shellescape(root), command))
  if not handle then
    return nil
  end

  local output = handle:read('*a'):gsub('%s+$', '')
  handle:close()

  if output == '' then
    return nil
  end

  return output
end

local function find_python_executable(start_dir)
  local root = resolve_python_root(start_dir or current_file_dir())

  if vim.env.VIRTUAL_ENV then
    return vim.env.VIRTUAL_ENV .. '/bin/python'
  end

  for _, venv_name in ipairs({ '.venv', 'venv' }) do
    local python_path = root .. '/' .. venv_name .. '/bin/python'
    if vim.fn.executable(python_path) == 1 then
      return python_path
    end
  end

  local poetry_path = shell_command_output(root, 'poetry env info --path 2>/dev/null')
  if poetry_path then
    local poetry_python = poetry_path .. '/bin/python'
    if vim.fn.executable(poetry_python) == 1 then
      return poetry_python
    end
  end

  local home_dir = vim.fn.expand('~')
  local poetry_patterns = {
    home_dir .. '/Library/Caches/pypoetry/virtualenvs/corrogo-*/bin/python',
    home_dir .. '/Library/Caches/pypoetry/virtualenvs/erp-gateway-*/bin/python',
    home_dir .. '/Library/Caches/pypoetry/virtualenvs/shipwell-*/bin/python',
  }

  for _, pattern in ipairs(poetry_patterns) do
    local expanded = vim.fn.glob(pattern)
    if expanded ~= '' then
      for _, path in ipairs(vim.split(expanded, '\n')) do
        if vim.fn.executable(path) == 1 then
          return path
        end
      end
    end
  end

  local uv_python = shell_command_output(root, 'uv run python -c "import sys; print(sys.executable)" 2>/dev/null')
  if uv_python and uv_python:match('^/') then
    return uv_python
  end

  local pyenv_python = vim.fn.expand('~/.pyenv/versions/3.10.0/bin/python3')
  if vim.fn.executable(pyenv_python) == 1 then
    return pyenv_python
  end

  local python3 = vim.fn.exepath('python3')
  return python3 ~= '' and python3 or '/usr/bin/python3'
end

local function is_django_project(start_dir)
  local django_root = find_django_root(start_dir or current_file_dir())
  if not django_root then
    return false, nil, nil
  end

  return true, django_root .. '/manage.py', django_root
end

local function dotted_python_path(root, file_path)
  return relative_to(root, file_path):gsub('%.py$', ''):gsub('/', '.')
end

local function detect_python_test(node, ts_utils)
  local test_func
  local class_hierarchy = {}
  local has_pytest_markers = false
  local has_django_markers = false
  local has_unittest_markers = false

  -- Check file imports to help determine test framework
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 100, false)
  for _, line in ipairs(lines) do
    if line:match('import%s+pytest') or line:match('from%s+pytest') or line:match('pytestmark') then
      has_pytest_markers = true
    end
    if line:match('from%s+django%.test%s+import') or line:match('import%s+django') or line:match('from%s+rest_framework%.test%s+import') then
      has_django_markers = true
    end
    if line:match('from%s+unittest%s+import') or line:match('^%s*import%s+unittest') then
      has_unittest_markers = true
    end
  end

  while node do
    if node:type() == "function_definition" then
      local name_node = node:child(1)
      if name_node then
        local func_name = ts_utils.get_node_text(name_node)[1]
        if vim.startswith(func_name, "test_") and not test_func then
          test_func = func_name
        end
      end
    elseif node:type() == "class_definition" then
      local name_node = node:child(1)
      if name_node then
        table.insert(class_hierarchy, 1, ts_utils.get_node_text(name_node)[1])
      end
    end
    node = node:parent()
  end

  local test_class = #class_hierarchy > 0 and table.concat(class_hierarchy, '::') or nil
  local is_django = find_django_root(current_file_dir()) ~= nil
  local is_pytest

  if has_pytest_markers then
    is_pytest = true
  elseif is_django and (has_django_markers or has_unittest_markers) then
    is_pytest = false
  else
    is_pytest = true
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

local function find_node_package_root(start_dir)
  return find_upward(start_dir, { 'package.json' }) or vim.fn.getcwd()
end

local function find_jest_binary(start_dir)
  local path = start_dir

  while path and path ~= '' do
    local jest_bin = path .. '/node_modules/jest/bin/jest.js'
    if vim.fn.filereadable(jest_bin) == 1 then
      return jest_bin
    end

    local parent = vim.fn.fnamemodify(path, ':h')
    if parent == path then
      break
    end
    path = parent
  end

  return './node_modules/jest/bin/jest.js'
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

    if not test_func then
      vim.notify("No test function found at cursor position", vim.log.levels.ERROR)
      return
    end

    local file_path = current_file_path()
    local file_dir = current_file_dir()
    local project_root = resolve_python_root(file_dir)
    local pytest_target = relative_to(project_root, file_path)
    local python_path = function()
      return find_python_executable(file_dir)
    end

    if is_pytest then
      local test_path = test_class 
      and string.format('%s::%s::%s', pytest_target, test_class, test_func)
      or string.format('%s::%s', pytest_target, test_func)

      vim.notify(string.format("Running pytest: %s", test_path), vim.log.levels.INFO)

      dap.run({
        type = 'python',
        request = 'launch',
        name = 'Pytest Test',
        module = 'pytest',
        args = { test_path },
        pythonPath = python_path,
        console = 'integratedTerminal',
        cwd = project_root,
        justMyCode = false,
        env = {
          PYTHONPATH = project_root,
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
      -- Django test
      local is_django, manage_py_path, django_root = is_django_project(file_dir)

      if not is_django or not manage_py_path then
        vim.notify("No manage.py found. Falling back to pytest.", vim.log.levels.WARN)

        -- Fallback to pytest
        local test_path = test_class
          and string.format('%s::%s::%s', pytest_target, test_class, test_func)
          or string.format('%s::%s', pytest_target, test_func)

        dap.run({
          type = 'python',
          request = 'launch',
          name = 'Pytest Test (Fallback)',
          module = 'pytest',
          args = { test_path },
          pythonPath = python_path,
          console = 'integratedTerminal',
          cwd = project_root,
          justMyCode = false,
          env = { PYTHONPATH = project_root },
        })
        return
      end

      local dotted_module = dotted_python_path(django_root, file_path)
      local dotted_class = test_class and test_class:gsub('::', '.')
      local test_path = dotted_class
        and string.format('%s.%s.%s', dotted_module, dotted_class, test_func)
        or string.format('%s.%s', dotted_module, test_func)
      vim.notify(string.format("Running Django test: %s", test_path), vim.log.levels.INFO)

      dap.run({
        type = 'python',
        request = 'launch',
        name = 'Django Test',
        program = manage_py_path,
        args = { 'test', test_path, '--failfast', '--keepdb' },
        django = true,
        justMyCode = false,
        console = 'integratedTerminal',
        pythonPath = python_path,
        cwd = django_root,
        env = { PYTHONPATH = django_root },
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
    local file_path = current_file_path()
    local file_dir = current_file_dir()
    local package_root = find_node_package_root(file_dir)
    local jest_bin = find_jest_binary(file_dir)
    local test_file = relative_to(package_root, file_path)

    vim.notify(
      string.format("Running Jest test: %s (cwd=%s)", test_func, package_root),
      vim.log.levels.INFO
    )

    dap.run({
      type = "pwa-node",
      request = "launch",
      name = "Debug Jest Test",
      runtimeExecutable = "node",
      runtimeArgs = {
        jest_bin,
        "--runInBand",
        "--no-cache",
        "--config=" .. vim.fn.json_encode({
          transformIgnorePatterns = { "/node_modules/(?!@jridgewell)" },
          testEnvironment = "node",
        }),
        "--testNamePattern",
        test_func,
        test_file
      },
      rootPath = package_root,
      cwd = package_root,
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
