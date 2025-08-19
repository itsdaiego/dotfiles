local M = {}

function M.setup(dap)
    -- Verify that JavaScript adapters are available (they should be set up in main dap.lua)
    if not dap.adapters['pwa-node'] then
        vim.notify("JavaScript debug adapters not found. Ensure js-debug-adapter is installed.", vim.log.levels.WARN)
        return
    end

    -- Add the filterable attach configuration
    local custom_configs = {
        {
            type = 'pwa-node',
            request = 'attach',
            name = 'Attach',
            processId = function()
                return coroutine.create(function(dap_run_co)
                    -- Get list of node processes
                    local handle = io.popen("ps aux | grep -E '[n]ode|[n]pm|[y]arn' | grep -v grep")
                    if not handle then
                        vim.notify("Failed to get process list", vim.log.levels.ERROR)
                        coroutine.resume(dap_run_co, nil)
                        return
                    end
                    
                    local processes = {}
                    
                    for line in handle:lines() do
                        local pid = line:match("^%S+%s+(%d+)")
                        local cmd = line:match("%d+:%d+%.%d+%s+(.+)$")
                        if pid and cmd then
                            table.insert(processes, { 
                                pid = tonumber(pid), 
                                cmd = cmd,
                                display = string.format("%s: %s", pid, cmd:sub(1, 80))
                            })
                        end
                    end
                    handle:close()
                    
                    if #processes == 0 then
                        vim.notify("No Node.js processes found", vim.log.levels.WARN)
                        coroutine.resume(dap_run_co, nil)
                        return
                    end
                    
                    -- Use telescope for filtering
                    local has_telescope = pcall(require, "telescope")
                    if has_telescope then
                        local pickers = require("telescope.pickers")
                        local finders = require("telescope.finders")
                        local conf = require("telescope.config").values
                        local actions = require("telescope.actions")
                        local action_state = require("telescope.actions.state")
                        
                        pickers.new({}, {
                            prompt_title = "Select Node.js Process",
                            finder = finders.new_table({
                                results = processes,
                                entry_maker = function(entry)
                                    return {
                                        value = entry,
                                        display = entry.display,
                                        ordinal = entry.display,
                                    }
                                end,
                            }),
                            sorter = conf.generic_sorter({}),
                            attach_mappings = function(prompt_bufnr, map)
                                actions.select_default:replace(function()
                                    actions.close(prompt_bufnr)
                                    local selection = action_state.get_selected_entry()
                                    if selection then
                                        local selected_pid = selection.value.pid
                                        vim.notify(string.format("Attaching to PID %d", selected_pid), vim.log.levels.INFO)
                                        coroutine.resume(dap_run_co, selected_pid)
                                    else
                                        vim.notify("No process selected", vim.log.levels.WARN)
                                        coroutine.resume(dap_run_co, nil)
                                    end
                                end)
                                
                                -- Handle escape/cancel
                                map('i', '<esc>', function()
                                    actions.close(prompt_bufnr)
                                    vim.notify("Process selection cancelled", vim.log.levels.INFO)
                                    coroutine.resume(dap_run_co, nil)
                                end)
                                
                                return true
                            end,
                        }):find()
                    else
                        -- Fallback to inputlist (non-blocking)
                        vim.schedule(function()
                            local process_list = {}
                            for _, proc in ipairs(processes) do
                                table.insert(process_list, proc.display)
                            end
                            
                            local choice = vim.fn.inputlist(vim.tbl_flatten({"Select process:", process_list}))
                            if choice < 1 or choice > #processes then
                                vim.notify("Invalid selection", vim.log.levels.ERROR)
                                coroutine.resume(dap_run_co, nil)
                            else
                                local selected_pid = processes[choice].pid
                                vim.notify(string.format("Attaching to PID %d", selected_pid), vim.log.levels.INFO)
                                coroutine.resume(dap_run_co, selected_pid)
                            end
                        end)
                    end
                end)
            end,
            cwd = '${workspaceFolder}',
        },
    }

    -- Add the filterable attach config to existing configurations
    vim.defer_fn(function()
        local js_filetypes = {'javascript', 'typescript', 'javascriptreact', 'typescriptreact'}
        for _, filetype in ipairs(js_filetypes) do
            if dap.configurations[filetype] then
                for _, config in ipairs(custom_configs) do
                    table.insert(dap.configurations[filetype], config)
                end
            end
        end
    end, 100)
end

return M