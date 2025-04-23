--- Python language actions for Telescope + Overseer
-- Supports interpreted, compiled, bytecode, and persistent REPL code block execution

local M = {}

--- Frontend - options displayed in Telescope
M.options = {
  { text = "Run this file (interpreted)", value = "option1" },
  { text = "Run program (interpreted)", value = "option2" },
  { text = "Run solution (interpreted)", value = "option3" },
  { text = "", value = "separator" },
  { text = "Build and run program (machine code)", value = "option4" },
  { text = "Build program (machine code)", value = "option5" },
  { text = "Run program (machine code)", value = "option6" },
  { text = "Build solution (machine code)", value = "option7" },
  { text = "", value = "separator" },
  { text = "Build and run program (bytecode)", value = "option8" },
  { text = "Build program (bytecode)", value = "option9" },
  { text = "Run program (bytecode)", value = "option10" },
  { text = "Build solution (bytecode)", value = "option11" },
  { text = "", value = "separator" },
  { text = "Run REPL", value = "option12" },
  { text = "", value = "separator" },
  { text = "Run code block (interpreted)", value = "option13" },
}

--- Module-level state to keep the persistent REPL job ID
M.python_repl = nil

--- Backend - actions performed for each selected option
function M.action(selected_option)
  local utils = require("compiler.utils")
  local overseer = require("overseer")
  local ToggleTerm = require("overseer.strategy.toggleterm")

  -- Common paths
  local current_file = utils.os_path(vim.fn.expand("%:p"), true)
  local entry_point = utils.os_path(vim.fn.getcwd() .. "/main.py")
  local files = utils.find_files_to_compile(entry_point, "*.py")
  local output_dir = utils.os_path(vim.fn.getcwd() .. "/bin/")
  local output = utils.os_path(vim.fn.getcwd() .. "/bin/program")
  local final_message = "--task finished--"

  -- Helper: dump the current “# %%” code block to a temp .py and return its path
  local function dump_block_to_temp()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)[1]
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    -- find block start (line after previous "# %%")
    local start = 1
    for i = cursor, 1, -1 do
      if lines[i]:match("^# %%") then
        start = i + 1
        break
      end
    end

    -- find block end (line before next "# %%")
    local finish = #lines
    for i = cursor, #lines do
      if lines[i]:match("^# %%") then
        finish = i - 1
        break
      end
    end

    -- write slice to temp file
    local temp_py = vim.fn.tempname() .. ".py"
    vim.fn.writefile(
      vim.api.nvim_buf_get_lines(bufnr, start - 1, finish, false),
      temp_py
    )
    return temp_py
  end

  -- Setup a shared ToggleTerm strategy for Python REPL
  local term_strategy = ToggleTerm.new({
    direction = "horizontal", -- change to "vertical" or "float" if desired
    close_on_exit = false,
    quit_on_exit = "never",
  })

  --=============================== INTERPRETED ==================================
  if selected_option == "option1" then
    -- ... (keep your existing option1-3 code unchanged) ...

    --=============================== REPL ====================================
  elseif selected_option == "option12" then
    -- Open or focus a persistent Python REPL
    local task = overseer.new_task({
      name = "Python ▶ Persistent REPL",
      strategy = term_strategy,
      cmd = { "python", "-i" },
      components = { "default_extended" },
    })
    -- Capture the job ID of the terminal once it's created
    term_strategy.opts.on_create = function(term) M.python_repl = term.job_id end
    task:start()

  --========================= CODE BLOCK ====================================
  elseif selected_option == "option13" then
    -- Ensure a REPL is already running
    if not M.python_repl then
      vim.notify(
        'No Python REPL running. Please run "Run REPL" (option12) first.',
        vim.log.levels.WARN
      )
      return
    end

    -- Dump the current #%% block and send its contents into the REPL
    local block_file = dump_block_to_temp()
    local block_lines = vim.fn.readfile(block_file)
    local code = table.concat(block_lines, "\n")
    -- Send the code and a newline to execute
    vim.api.nvim_chan_send(M.python_repl, code .. "\n")
  else
    -- ... (rest of your options: option2-11, copied unchanged) ...
  end
end

return M
