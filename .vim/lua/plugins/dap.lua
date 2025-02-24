return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "theHamsta/nvim-dap-virtual-text",
      "nvim-telescope/telescope-dap.nvim",
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "mfussenegger/nvim-dap-python",
      "nvim-treesitter/nvim-treesitter",
    },
    keys = {
      { "<Leader>dc", function() require("dap").continue() end, desc = "Debug: Continue" },
      { "<Leader>dn", function() require("dap").step_over() end, desc = "Debug: Step Over" },
      { "<Leader>dN", function() require("dap").step_into() end, desc = "Debug: Step Into" },
      { "<Leader>do", function() require("dap").step_out() end, desc = "Debug: Step Out" },
      { "<Leader>db", function() require("dap").toggle_breakpoint() end, desc = "Debug: Toggle Breakpoint" },
      { "<Leader>dB", function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, desc = "Debug: Set Conditional Breakpoint" },
      { "<Leader>dr", function() require("dap").repl.open() end, desc = "Debug: Open REPL" },
      { "<Leader>dl", function() require("dap").run_last() end, desc = "Debug: Run Last" },
      { "<Leader>du", function() require("dapui").toggle() end, desc = "Debug: Toggle UI" },
      { "<Leader>tn", function()
        local dap = require('dap')
        local ts_utils = require('nvim-treesitter.ts_utils')
        local node = ts_utils.get_node_at_cursor()

        if not node then
          vim.notify("No treesitter node found at cursor", vim.log.levels.ERROR)
          return
        end

        local filetype = vim.bo.filetype

       if filetype == "python" then
         is_pytest = false

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
             args = { 
               test_path, 
             },
             pythonPath = function()
               -- change as needed
               local poetry_venv = '/Users/daiego/Library/Caches/pypoetry/virtualenvs/corrogo-bwpqepX3-py3.12/bin/python'
               -- local poetry_venv = '/Users/daiego/Library/Caches/pypoetry/virtualenvs/erp-gateway-uuC0M-NL-py3.12/bin/python'
               if vim.fn.executable(poetry_venv) == 1 then
                 return poetry_venv
               end
               return '/usr/bin/python3'
             end,
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
           return
         else
           local test_path = string.format('%s.%s.%s', vim.fn.expand('%:r'):gsub('/', '.'), test_class, test_func)
           test_path = test_path:gsub('shipwell_backend.', '')
           vim.notify(string.format("Running Django test: %s", test_path), vim.log.levels.INFO)

           dap.run({
             type = 'python',
             request = 'launch',
             name = 'Django Test',
             program = vim.fn.getcwd() .. "/shipwell_backend/manage.py",
             args = { 'test', test_path, '--failfast', '--keepdb' },
             django = true,
             justMyCode = false,
             console = 'integratedTerminal',
             pythonPath = function()
               -- Try to find poetry venv
               local poetry_venv = '/Users/daiego/Documents/code-stuff/shipwell/backend-core/.venv/bin/python'
               if vim.fn.executable(poetry_venv) == 1 then
                 return poetry_venv
               end
               vim.notify("Did not found venv")
               vim.fn.getchar()
               -- Fallback to system python
               return '/usr/bin/python3'
             end,
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

         if not test_func then
           vim.notify("No test function found at cursor position", vim.log.levels.ERROR)
           return
         end

         local file_path = vim.fn.expand('%:p')
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
       end

      end, desc = "Debug: Run Nearest Test" },
    },
    config = function()
      local dap, dapui = require("dap"), require("dapui")

      require("nvim-dap-virtual-text").setup({
        enabled = true,
        enabled_commands = true,
        highlight_changed_variables = true,
        highlight_new_as_changed = true,
        show_stop_reason = true,
        commented = false,
        only_first_definition = true,
        all_references = false,
        clear_on_continue = false,
        display_callback = function(variable, buf, stackframe, node, options)
          if variable.type == '' then
            return ''
          end
          if options.virt_text_pos == 'inline' then
            return ' = ' .. variable.value
          else
            return variable.name .. ' = ' .. variable.value
          end
        end,
        virt_text_pos = 'eol',
        all_frames = false,
        virt_lines = false,
        virt_text_win_col = nil
      })

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
          -- FastAPI configuration
          type = 'python',
          request = 'launch',
          name = 'FastAPI',
          program = function()
            return vim.fn.input('Path to FastAPI app file: ', vim.fn.getcwd() .. '/main.py', 'file')
          end,
          args = { },
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
            PYTHONPATH = "${workspaceFolder}",
            PORT = "8000"
          },
          showReturnValue = true,
          redirectOutput = true,
          stopOnEntry = false,
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
        }
      }

      dap.adapters.go = function(callback, config)
        local stdout = vim.loop.new_pipe(false)
        local handle
        local pid_or_err
        local port = 38697
        -- Find dlv in GOPATH or GOBIN
        local dlv_path = vim.fn.exepath('dlv')
        if dlv_path == '' then
          -- Try in GOPATH
          local gopath = os.getenv("GOPATH") or (os.getenv("HOME") .. "/go")
          dlv_path = gopath .. "/bin/dlv"
          if vim.fn.executable(dlv_path) ~= 1 then
            error("dlv not found. Please install Delve (go install github.com/go-delve/delve/cmd/dlv@latest)")
            return
          end
        end
        local opts = {
          stdio = {nil, stdout},
          args = {"dap", "--check-go-version=false", "-l", "127.0.0.1:" .. port},
          detached = true
        }
        handle, pid_or_err = vim.loop.spawn(dlv_path, opts, function(code)
          stdout:close()
          handle:close()
          if code ~= 0 then
            print('dlv exited with code', code)
          end
        end)
        assert(handle, 'Error running dlv: ' .. tostring(pid_or_err))
        stdout:read_start(function(err, chunk)
          assert(not err, err)
          if chunk then
            vim.schedule(function()
              require('dap.repl').append(chunk)
            end)
          end
        end)
        -- Wait for delve to start
        vim.defer_fn(
          function()
            callback({
              type = "server",
              host = "127.0.0.1",
              port = port,
              args = {
                mode = "debug",
                backend = "default",
                gcflags = "all=-N"
              }
            })
          end,
          100)
      end

      -- Configure Go
      dap.configurations.go = {
        {
          type = "go",
          name = "Debug Package",
          request = "launch",
          program = "${fileDirname}",
          args = function()
            local args = {}
            local args_str = vim.fn.input('Arguments: ')
            if args_str ~= '' then
              for arg in args_str:gmatch("%S+") do
                table.insert(args, arg)
              end
            end
            return args
          end,
        },
        {
          type = "go",
          name = "Debug Test",
          request = "launch",
          mode = "test",
          program = "${file}",
          args = function()
            local args = {'-test.v'}
            local test_name = vim.fn.input('Test name (optional): ')
            if test_name ~= '' then
              table.insert(args, '-test.run')
              table.insert(args, test_name)
            end
            return args
          end,
          buildFlags = '-tags=integration'
        },
        {
          type = "go",
          name = "Debug Test (Package)",
          request = "launch",
          mode = "test",
          program = "${fileDirname}",
          args = {"-test.v"},
          buildFlags = '-tags=integration'
        },
        {
          type = "go",
          name = "Attach",
          mode = "local",
          request = "attach",
          processId = require('dap.utils').pick_process,
        },
        {
          type = "go",
          name = "Remote Attach",
          mode = "remote",
          request = "attach",
          port = function()
            return tonumber(vim.fn.input('Port: '))
          end,
          host = function()
            return vim.fn.input('Host: ')
          end,
        },
      }

      dapui.setup({
        layouts = {
          { elements = {
              { id = "scopes", size = 0.5 },
              { id = "repl", size = 0.5 },
              -- { id = "stacks", size = 0.25 },
              -- { id = "watches", size = 0.25 },
            },
            position = "left",
            size = 60
          },
          { elements = {
              { id = "breakpoints", size = 0.25 },
              { id = "console", size = 0.25 },
            },
            position = "bottom",
            size = 20
          }
        },
        force_buffers = true,
      })

      dap.listeners.after.event_initialized['dapui_config'] = function()
        vim.notify("Debug session started", vim.log.levels.INFO)
        dapui.open()
      end

      local function close_dapui()
        dapui.close()
        vim.cmd('silent! lua require("nvim-dap-virtual-text").refresh()')
      end

      -- dap.listeners.after.event_terminated["dapui_config"] = close_dapui
      dap.listeners.after.event_exited["dapui_config"] = close_dapui
      dap.listeners.after.disconnect["dapui_config"] = close_dapui

      dap.set_log_level('DEBUG')
      dap.defaults.fallback.exception_breakpoints = {'uncaught'}

      dap.listeners.after.event_exited['test_exit'] = function(_, body)
        local exit_code = body.exitCode or 0
        vim.notify(exit_code ~= 0 and "Test failed with exit code: " .. tostring(exit_code) or "Test completed successfully",
                  exit_code ~= 0 and vim.log.levels.WARN or vim.log.levels.INFO)
      end

      vim.fn.sign_define('DapBreakpoint', {text='🛑', texthl='', linehl='', numhl=''})
      vim.fn.sign_define('DapBreakpointCondition', {text='🔍', texthl='', linehl='', numhl=''})
      vim.fn.sign_define('DapStopped', {text='👉', texthl='', linehl='', numhl=''})
    end,
  }
} 
