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
      {
        "microsoft/vscode-js-debug",
        version = "v1.74.1",
        build = "npm install --legacy-peer-deps --no-optional && npx gulp vsDebugServerBundle && mkdir -p out && cp -r dist/* out/"
      },
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
        require('dap.test_detection').run_nearest_test(dap)
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

      -- Load language specific configurations
      require('dap.javascript').setup(dap)
      require('dap.python').setup(dap)
      require('dap.go').setup(dap)

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
