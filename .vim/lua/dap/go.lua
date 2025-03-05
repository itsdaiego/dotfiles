local M = {}

function M.setup(dap)
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
end

return M 
