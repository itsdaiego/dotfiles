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
