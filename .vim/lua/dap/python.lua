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

local function resolve_python_root()
    local start_dir = current_file_dir()

    return find_upward(start_dir, { 'manage.py' })
        or find_upward(start_dir, { 'pyproject.toml', 'pytest.ini', 'setup.cfg', 'tox.ini', 'requirements.txt', '.venv', 'venv' })
        or vim.fn.getcwd()
end

local function relative_to(base, path)
    local prefix = base .. '/'
    if vim.startswith(path, prefix) then
        return path:sub(#prefix + 1)
    end

    return path
end

local function absolutize(root, path)
    if path:match('^/') then
        return path
    end

    return root .. '/' .. path
end

local function command_output(root, command)
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

local function get_python_path(root)
    root = root or resolve_python_root()

    if vim.env.VIRTUAL_ENV then
        return vim.env.VIRTUAL_ENV .. '/bin/python'
    end

    for _, venv_name in ipairs({ '.venv', 'venv' }) do
        local python_path = root .. '/' .. venv_name .. '/bin/python'
        if vim.fn.executable(python_path) == 1 then
            return python_path
        end
    end

    local poetry_env = command_output(root, 'poetry env info --path 2>/dev/null')
    if poetry_env then
        local poetry_python = poetry_env .. '/bin/python'
        if vim.fn.executable(poetry_python) == 1 then
            return poetry_python
        end
    end

    local uv_python = command_output(root, 'uv run python -c "import sys; print(sys.executable)" 2>/dev/null')
    if uv_python and uv_python:match('^/') then
        return uv_python
    end

    local python3 = vim.fn.exepath('python3')
    return python3 ~= '' and python3 or 'python3'
end

local function get_rcc_python(root, silent)
    local command = silent
        and 'rcc task script --silent -- python -c "import sys; print(sys.executable)" 2>&1 | head -1'
        or 'rcc task script -- python -c "import sys; print(sys.executable)" 2>&1 | head -1'
    local python_path = command_output(root, command)

    if python_path and python_path:match('^/') then
        return python_path
    end

    return get_python_path(root)
end

local function collect_rcc_env(root)
    local env_vars = { RC_LOG_LEVEL = 'DEBUG' }
    local handle = io.popen(string.format('cd %s && rcc task shell-variable 2>/dev/null', vim.fn.shellescape(root)))

    if not handle then
        return env_vars
    end

    for line in handle:lines() do
        local key, value = line:match('^export ([^=]+)="?([^"]*)"?$')
        if key and value then
            env_vars[key] = value
        end
    end

    handle:close()
    return env_vars
end

function M.setup(dap)
    -- nvim-dap-python already provides:
    -- - "Python: Current File"
    -- - "Python: Module" 
    -- - "Python: Attach" (to process by PID)
    -- - Test debugging via dap_python.test_method() and dap_python.test_class()
    
    -- We only need to add remote server attach (for debugging running servers like FastAPI)
    local custom_configs = {
        {
            type = 'python',
            request = 'attach',
            name = 'Python: Attach to Remote Server',
            connect = {
                host = function()
                    local host = vim.fn.input('Host [127.0.0.1]: ')
                    return host ~= '' and host or '127.0.0.1'
                end,
                port = function()
                    local port = tonumber(vim.fn.input('Port [5678]: ')) or 5678

                    -- Test connection
                    local test_cmd = string.format("nc -z 127.0.0.1 %d 2>/dev/null", port)
                    if os.execute(test_cmd) ~= 0 then
                        print(string.format("⚠️  Add to your server: import debugpy; debugpy.listen(('0.0.0.0', %d))", port))
                    end

                    return port
                end,
            },
            justMyCode = false,
        },
        {
            type = 'python',
            request = 'launch',
            name = 'Robocorp: Debug Current File (via rcc)',
            console = 'integratedTerminal',
            cwd = resolve_python_root,
            program = function()
                local root = resolve_python_root()
                local current_file = vim.fn.expand('%:p')
                local file_input = vim.fn.input('File to debug [' .. vim.fn.fnamemodify(current_file, ':t') .. ']: ')
                if file_input == '' then
                    return current_file
                end

                return absolutize(root, file_input)
            end,
            python = function()
                return get_rcc_python(resolve_python_root(), false)
            end,
            args = function()
                local args_input = vim.fn.input('Arguments (optional): ')
                if args_input ~= '' then
                    local args = {}
                    for arg in args_input:gmatch("%S+") do
                        table.insert(args, arg)
                    end
                    return args
                end
                return {}
            end,
            env = function()
                return collect_rcc_env(resolve_python_root())
            end,
            justMyCode = false,
        },
        {
            type = 'python',
            request = 'launch',
            name = 'Robot Framework: Debug with -L DEBUG',
            console = 'integratedTerminal',
            cwd = resolve_python_root,
            module = 'robot',
            python = function()
                return get_rcc_python(resolve_python_root(), true)
            end,
            args = function()
                local test_file = vim.fn.input('Robot file [tasks.robot]: ')
                if test_file == '' then
                    test_file = 'tasks.robot'
                end
                return {'-L', 'DEBUG', test_file}
            end,
            env = function()
                return collect_rcc_env(resolve_python_root())
            end,
            justMyCode = false,
        },
        {
            type = 'python',
            request = 'launch',
            name = 'UV: Debug File (default src/task.py)',
            console = 'integratedTerminal',
            cwd = resolve_python_root,
            program = function()
                local root = resolve_python_root()
                local default_file = 'src/task.py'
                local current_file = vim.fn.expand('%:p')

                -- Check if default file exists
                local full_default = root .. '/' .. default_file
                local default_exists = vim.fn.filereadable(full_default) == 1

                -- Determine the best default to show
                local suggested_file
                if default_exists then
                    suggested_file = default_file
                else
                    suggested_file = relative_to(root, current_file)
                end

                local file_input = vim.fn.input('File to debug [' .. suggested_file .. ']: ')

                if file_input == '' then
                    if default_exists then
                        return full_default
                    else
                        return current_file
                    end
                end

                return absolutize(root, file_input)
            end,
            python = function()
                return get_python_path(resolve_python_root())
            end,
            args = function()
                local args_input = vim.fn.input('Arguments (optional): ')
                if args_input ~= '' then
                    local args = {}
                    for arg in args_input:gmatch("%S+") do
                        table.insert(args, arg)
                    end
                    return args
                end
                return {}
            end,
            justMyCode = false,
        },
    }
    
    -- Extend existing configurations
    vim.defer_fn(function()
        if dap.configurations.python then
            for _, config in ipairs(dap.configurations.python) do
                if config.name == 'Python: Current File' or config.name == 'Launch file' then
                    config.cwd = resolve_python_root
                    config.python = function()
                        return get_python_path(resolve_python_root())
                    end
                    config.pythonPath = function()
                        return get_python_path(resolve_python_root())
                    end
                end
            end

            for _, config in ipairs(custom_configs) do
                table.insert(dap.configurations.python, config)
            end
        end
    end, 100)
end

return M
