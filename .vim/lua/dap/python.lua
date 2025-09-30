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
            name = 'Robocorp: Debug Task (via rcc)',
            console = 'integratedTerminal',
            cwd = '${workspaceFolder}',
            module = 'robocorp.tasks',
            -- Use rcc to wrap the execution
            python = function()
                -- Get rcc's Python path using correct syntax
                local cwd = vim.fn.getcwd()
                vim.notify("🔍 Discovering rcc Python environment...", vim.log.levels.INFO)
                local handle = io.popen(string.format('cd "%s" && rcc task script --silent -- python -c "import sys; print(sys.executable)" 2>&1 | head -1', cwd))
                local python_path = handle:read("*a"):gsub("%s+", "")
                handle:close()

                if python_path ~= "" and python_path:match("^/") then
                    vim.notify("✅ Found rcc Python: " .. python_path, vim.log.levels.INFO)
                    return python_path
                else
                    vim.notify("❌ Failed to discover rcc Python: " .. (python_path or "empty"), vim.log.levels.ERROR)
                    return "python3"
                end
            end,
            args = function()
                local task = vim.fn.input('Task name (or leave empty for default): ')
                local args = {'run', 'tasks.py'}
                if task ~= '' then
                    table.insert(args, '--task')
                    table.insert(args, task)
                end
                return args
            end,
            env = function()
                local env_vars = { RC_LOG_LEVEL = 'DEBUG' }
                -- Load rcc environment variables
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
                    vim.notify("✅ Loaded rcc environment variables", vim.log.levels.INFO)
                end
                return env_vars
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
