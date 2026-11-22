-- Match the tmux-style bindings in ~/.config/herdr/config.toml.

-- Ctrl+B enters a one-key tmux-style prefix mode. A mode is used instead of
-- Rex key sequences so number keys work reliably for indexed session switching.
rex.mode("tmux_prefix", { exclusive = true })
rex.bind("ctrl+b", "client.mode.enter", { name = "tmux_prefix", once = true })

-- Sessions and agents. These open as large floating panes because Rex's native
-- switchers have a fixed size that is too small on the vertical display.
local function picker_snapshot()
  local listed, list_err = rex.call("session.list")
  if listed == nil then error(list_err, 0) end

  local snapshot = {}
  local terminal = "com.superlogical.terminal"
  for _, session in ipairs(listed.sessions) do
    local view, view_err = rex.call("session.view", { session_id = session.session_id })
    if view == nil then error(view_err, 0) end

    for _, window in ipairs(view.windows or {}) do
      for _, layer in ipairs(window.layers or {}) do
        for _, block in ipairs(layer.blocks or {}) do
          local process = {}
          if block.creator_name == terminal then
            process = rex.block.call(terminal, "process", {
              session_id = session.session_id,
              block_id = block.block_id,
            }) or {}
          end
          table.insert(snapshot, {
            session_id = session.session_id,
            session_label = session.label,
            window_id = window.window_id,
            window_label = window.label or "Tab",
            window_zoomed = window.zoomed_block_id ~= nil,
            block_id = block.block_id,
            block_label = block.label or "Pane",
            process = process,
          })
        end
      end
    end
  end
  return snapshot
end

local function client_target(client_id)
  local inspected = rex.call("client.inspect", { client_id = client_id })
  local client = inspected and inspected.client
  local label = client and client.info and client.info.label
  return label or (client and client.client_id)
end

local function picker_client_target(ctx)
  local target = client_target(ctx.client_id)
  if target ~= nil then return target end

  -- A remote app can report its client ID from its home server rather than
  -- its connection ID on this server. The focused terminal's owner is the
  -- corresponding client on this server, so use that as the fallback.
  local view = rex.session.view{ session_id = ctx.session_id }
  for _, window in ipairs((view and view.windows) or {}) do
    for _, layer in ipairs(window.layers or {}) do
      for _, block in ipairs(layer.blocks or {}) do
        if block.block_id == ctx.block_id and block.owner ~= nil then
          return client_target(block.owner) or block.owner
        end
      end
    end
  end

  return ctx.client_id
end

local function open_large_picker(ctx, mode)
  local command = {
    "/usr/bin/env",
    "python3",
    os.getenv("HOME") .. "/.config/rex/large-picker.py",
    mode,
    picker_client_target(ctx),
  }
  if mode ~= "sessions" then
    table.insert(command, "--snapshot-json")
    table.insert(command, rex.json.encode(picker_snapshot()))
  end

  local result, err = rex.session.new_layer{
    bounds = { 0.08, 0.08, 0.84, 0.78 },
    focus = true,
    layout = rex.layout.block{
      flavor = "com.superlogical.terminal.shell",
      options = {
        shell = "none",
        command = command,
      },
    },
  }
  if err ~= nil then error(err, 0) end
  return result
end

rex.action{
  name = "large_session_picker",
  title = "Large Session Picker",
  description = "Open a large session picker in a floating terminal pane.",
  category = "Session",
  run = function(ctx, args)
    return open_large_picker(ctx, "sessions")
  end,
}

rex.action{
  name = "large_program_picker",
  title = "Large Program Picker",
  description = "Open a large picker showing the program running in every pane.",
  category = "Pane",
  run = function(ctx, args)
    return open_large_picker(ctx, "blocks")
  end,
}

rex.action{
  name = "large_agent_picker",
  title = "Large Agent Picker",
  description = "Open a large picker showing each agent and its Rex session.",
  category = "Agent",
  run = function(ctx, args)
    return open_large_picker(ctx, "agents")
  end,
}

rex.bind("tmux_prefix/w", "large_program_picker")
rex.bind("tmux_prefix/a", "large_agent_picker")
rex.bind("tmux_prefix/n", "client.tab.next")
rex.bind("tmux_prefix/p", "client.tab.previous")
rex.bind("tmux_prefix/x", "pane.close")
rex.bind("tmux_prefix/z", "pane.zoom")

-- Herdr numbers workspaces from zero, while Rex's Lua arrays start at one.
rex.action{
  name = "switch_session_index",
  title = "Go to Session by Index",
  description = "Switch to a Rex session using Herdr's zero-based session order.",
  category = "Session",
  args = { index = "integer" },
  run = function(ctx, args)
    local result, err = rex.call("session.list")
    if result == nil then error(err, 0) end

    local session = result.sessions[args.index + 1]
    if session == nil then return end

    -- Queuing session.select from a server-side action does not switch across
    -- sessions in the current Rex preview, so call the client through the CLI.
    local binary = os.getenv("HOME") ..
      "/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex"
    local selected, select_err = rex.exec.start({
      binary,
      "-C",
      picker_client_target(ctx),
      "do",
      "session.select",
      "session_id=" .. session.session_id,
    }, { detach = true, stdout = false, stderr = false })
    if selected == nil then error(select_err, 0) end
    return { session_id = session.session_id }
  end,
}

for index = 0, 9 do
  local args = { index = index }
  rex.bind("tmux_prefix/" .. index, "switch_session_index", args)
  rex.bind("tmux_prefix/[Digit" .. index .. "]", "switch_session_index", args)
end

-- Sidebar, splits, and configuration.
rex.bind("tmux_prefix/b", "client.sidebar.toggle")
rex.bind("tmux_prefix/s", "pane.split", { direction = "down" })
rex.bind("tmux_prefix/v", "pane.split", { direction = "right" })
rex.bind("tmux_prefix/r", "client.config.reload")

-- Pane focus with and without the prefix. Moving focus with the native
-- pane.focus action always ends any zoom in the window, so this wraps it to
-- re-zoom the pane focus lands on when the one we left was zoomed.
rex.action{
  name = "zoom_aware_focus",
  title = "Focus Pane (Keep Zoom)",
  description = "Focus the pane in a direction, re-zooming it if the pane we left was zoomed.",
  category = "Pane",
  args = { direction = "string" },
  run = function(ctx, args)
    local view, view_err = rex.session.view{ session_id = ctx.session_id }
    if view == nil then error(view_err, 0) end

    local window
    for _, w in ipairs(view.windows or {}) do
      if w.window_id == view.active_window_id then window = w end
    end
    local was_zoomed = window ~= nil and window.zoomed_block_id ~= nil

    local _, focus_err = rex.session.focus_direction{
      session_id = ctx.session_id,
      direction = args.direction,
    }
    if focus_err ~= nil then error(focus_err, 0) end

    if was_zoomed then
      local _, zoom_err = rex.session.zoom_block{
        session_id = ctx.session_id,
        window_id = window.window_id,
        zoom = true,
      }
      if zoom_err ~= nil then error(zoom_err, 0) end
    end
  end,
}

rex.bind("tmux_prefix/h", "zoom_aware_focus", { direction = "left" })
rex.bind("tmux_prefix/j", "zoom_aware_focus", { direction = "down" })
rex.bind("tmux_prefix/k", "zoom_aware_focus", { direction = "up" })
rex.bind("tmux_prefix/l", "zoom_aware_focus", { direction = "right" })
rex.bind("alt+h", "zoom_aware_focus", { direction = "left" })
rex.bind("alt+j", "zoom_aware_focus", { direction = "down" })
rex.bind("alt+k", "zoom_aware_focus", { direction = "up" })
rex.bind("alt+l", "zoom_aware_focus", { direction = "right" })

-- Coarse direct resizing and fine prefixed resizing.
rex.bind("alt+left", "pane.resize", { direction = "left", amount = 10 })
rex.bind("alt+right", "pane.resize", { direction = "right", amount = 10 })
rex.bind("alt+up", "pane.resize", { direction = "up", amount = 10 })
rex.bind("alt+down", "pane.resize", { direction = "down", amount = 10 })
rex.bind("tmux_prefix/alt+h", "pane.resize", { direction = "left", amount = 1 })
rex.bind("tmux_prefix/alt+j", "pane.resize", { direction = "down", amount = 1 })
rex.bind("tmux_prefix/alt+k", "pane.resize", { direction = "up", amount = 1 })
rex.bind("tmux_prefix/alt+l", "pane.resize", { direction = "right", amount = 1 })

-- Herdr's resize mode accepts arrows or h/j/k/l until Enter, Escape, or the
-- resize-mode shortcut is pressed again.
rex.mode("resize", { exclusive = true })
rex.bind("tmux_prefix/shift+r", "client.mode.enter", { name = "resize" })
rex.bind("resize/h", "pane.resize", { direction = "left", amount = 1 })
rex.bind("resize/j", "pane.resize", { direction = "down", amount = 1 })
rex.bind("resize/k", "pane.resize", { direction = "up", amount = 1 })
rex.bind("resize/l", "pane.resize", { direction = "right", amount = 1 })
rex.bind("resize/left", "pane.resize", { direction = "left", amount = 1 })
rex.bind("resize/down", "pane.resize", { direction = "down", amount = 1 })
rex.bind("resize/up", "pane.resize", { direction = "up", amount = 1 })
rex.bind("resize/right", "pane.resize", { direction = "right", amount = 1 })
rex.bind("resize/enter", "client.mode.exit")
rex.bind("resize/ctrl+b>shift+r", "client.mode.exit")

-- Press Ctrl+B twice when a terminal program needs Ctrl+B itself.
rex.bind("tmux_prefix/ctrl+b", "pane.send_key", { key = "ctrl+b" })
