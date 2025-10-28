local M = {}

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
            cwd = '${workspaceFolder}',
            program = function()
                local current_file = vim.fn.expand('%:p')
                local file_input = vim.fn.input('File to debug [' .. vim.fn.fnamemodify(current_file, ':t') .. ']: ')
                if file_input == '' then
                    return current_file
                end
                -- If relative path, make it absolute
                if not file_input:match('^/') then
                    return vim.fn.getcwd() .. '/' .. file_input
                end
                return file_input
            end,
            python = function()
                local cwd = vim.fn.getcwd()
                local handle = io.popen(string.format('cd "%s" && rcc task script -- python -c "import sys; print(sys.executable)" 2>&1 | head -1', cwd))
                local python_path = handle:read("*a"):gsub("%s+", "")
                handle:close()

                if python_path ~= "" and python_path:match("^/") then
                    return python_path
                else
                    return "python3"
                end
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
                local env_vars = { RC_LOG_LEVEL = 'DEBUG' }
                local cwd = vim.fn.getcwd()
                local handle = io.popen(string.format('cd "%s" && rcc task shell-variable 2>/dev/null', cwd))
                if handle then
                    for line in handle:lines() do
                        local key, value = line:match("^export ([^=]+)=\"?([^\"]*)\"?$")
                        if key and value then
                            env_vars[key] = value
                        end
                    end
                    handle:close()
                end
                return env_vars
            end,
            justMyCode = false,
        },
        {
            type = 'python',
            request = 'launch',
            name = 'Robot Framework: Debug with -L DEBUG',
            console = 'integratedTerminal',
            cwd = '${workspaceFolder}',
            module = 'robot',
            python = function()
                local cwd = vim.fn.getcwd()
                local handle = io.popen(string.format('cd "%s" && rcc task script --silent -- python -c "import sys; print(sys.executable)" 2>&1 | head -1', cwd))
                local python_path = handle:read("*a"):gsub("%s+", "")
                handle:close()

                if python_path ~= "" and python_path:match("^/") then
                    return python_path
                else
                    return "python3"
                end
            end,
            args = function()
                local test_file = vim.fn.input('Robot file [tasks.robot]: ')
                if test_file == '' then
                    test_file = 'tasks.robot'
                end
                return {'-L', 'DEBUG', test_file}
            end,
            env = function()
                local env_vars = { RC_LOG_LEVEL = 'DEBUG' }
                local cwd = vim.fn.getcwd()
                local handle = io.popen(string.format('cd "%s" && rcc task shell-variable 2>/dev/null', cwd))
                if handle then
                    for line in handle:lines() do
                        local key, value = line:match("^export ([^=]+)=\"?([^\"]*)\"?$")
                        if key and value then
                            env_vars[key] = value
                        end
                    end
                    handle:close()
                end
                return env_vars
            end,
            justMyCode = false,
        },
        {
            type = 'python',
            request = 'launch',
            name = 'UV: Debug File (default src/task.py)',
            console = 'integratedTerminal',
            cwd = '${workspaceFolder}',
            program = function()
                local default_file = 'src/task.py'
                local cwd = vim.fn.getcwd()
                local current_file = vim.fn.expand('%:p')

                -- Check if default file exists
                local full_default = cwd .. '/' .. default_file
                local default_exists = vim.fn.filereadable(full_default) == 1

                -- Determine the best default to show
                local suggested_file
                if default_exists then
                    suggested_file = default_file
                else
                    suggested_file = vim.fn.fnamemodify(current_file, ':.')
                end

                local file_input = vim.fn.input('File to debug [' .. suggested_file .. ']: ')

                if file_input == '' then
                    if default_exists then
                        return full_default
                    else
                        return current_file
                    end
                end

                -- If relative path, make it absolute
                if not file_input:match('^/') then
                    return cwd .. '/' .. file_input
                end
                return file_input
            end,
            python = function()
                local cwd = vim.fn.getcwd()
                -- Get the Python interpreter that uv would use
                local handle = io.popen(string.format('cd "%s" && uv run python -c "import sys; print(sys.executable)" 2>&1', cwd))
                local python_path = handle:read("*a"):gsub("%s+", "")
                handle:close()

                if python_path ~= "" and python_path:match("^/") then
                    return python_path
                else
                    return "python3"
                end
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
            for _, config in ipairs(custom_configs) do
                table.insert(dap.configurations.python, config)
            end
        end
    end, 100)
end

return M
