--- Python language actions
-- Unlike most languages, python can be:
--   * interpreted
--   * compiled to machine code
--   * compiled to bytecode

local M = {}

--- Frontend - options displayed on telescope
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

--- Backend - overseer tasks performed on option selected
function M.action(selected_option)
  local utils = require("compiler.utils")
  local overseer = require("overseer")
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

  --=========================== INTERPRETED =================================--
  if selected_option == "option1" then
    local task = overseer.new_task({
      name = "- Python interpreter",
      strategy = {
        "orchestrator",
        tasks = {
          {
            name = "- Run this file → " .. current_file,
            cmd = "python "
              .. current_file
              .. " && echo "
              .. current_file
              .. ' && echo "'
              .. final_message
              .. '"',
            components = { "default_extended" },
          },
        },
      },
    })
    task:start()
  elseif selected_option == "option2" then
    local task = overseer.new_task({
      name = "- Python interpreter",
      strategy = {
        "orchestrator",
        tasks = {
          {
            name = '- Run program → "' .. entry_point .. '"',
            cmd = 'python "'
              .. entry_point
              .. '"'
              .. ' && echo "'
              .. entry_point
              .. '"'
              .. ' && echo "'
              .. final_message
              .. '"',
            components = { "default_extended" },
          },
        },
      },
    })
    task:start()
  elseif selected_option == "option3" then
    local solution_file = utils.get_solution_file()
    if solution_file then
      local config = utils.parse_solution_file(solution_file)
      local tasks, executables = {}, {}

      for entry, variables in pairs(config) do
        if entry ~= "executables" then
          local ep = utils.os_path(variables.entry_point, true)
          local args = variables.arguments or ""
          table.insert(tasks, {
            name = "- Run program → " .. ep,
            cmd = "python "
              .. args
              .. " "
              .. ep
              .. " && echo "
              .. ep
              .. ' && echo "'
              .. final_message
              .. '"',
            components = { "default_extended" },
          })
        end
      end

      if config["executables"] then
        for _, exe in pairs(config["executables"]) do
          local e = utils.os_path(exe, true)
          table.insert(executables, {
            name = "- Run program → " .. e,
            cmd = e
              .. " && echo "
              .. e
              .. ' && echo "'
              .. final_message
              .. '"',
            components = { "default_extended" },
          })
        end
      end

      local task = overseer.new_task({
        name = "- Python interpreter",
        strategy = { "orchestrator", tasks = { tasks, executables } },
      })
      task:start()
    else
      local entry_points = utils.find_files(vim.fn.getcwd(), "main.py")
      local tasks = {}
      for _, ep in ipairs(entry_points) do
        local path = utils.os_path(ep, true)
        table.insert(tasks, {
          name = "- Run program → " .. path,
          cmd = "python "
            .. path
            .. " && echo "
            .. path
            .. ' && echo "'
            .. final_message
            .. '"',
          components = { "default_extended" },
        })
      end
      local task = overseer.new_task({
        name = "- Python interpreter",
        strategy = { "orchestrator", tasks = tasks },
      })
      task:start()
    end

  --========================== MACHINE CODE =================================--
  elseif selected_option == "option4" then
    local args = "--warn-implicit-exceptions --warn-unusual-code"
    local task = overseer.new_task({
      name = "- Python machine code compiler",
      strategy = {
        "orchestrator",
        tasks = {
          {
            name = '- Build & run program → "' .. entry_point .. '"',
            cmd = 'rm -f "'
              .. output
              .. '" || true'
              .. ' && mkdir -p "'
              .. output_dir
              .. '"'
              .. " && nuitka --no-pyi-file --remove-output --follow-imports"
              .. ' --output-filename="'
              .. output
              .. '"'
              .. " "
              .. args
              .. ' "'
              .. entry_point
              .. '"'
              .. ' && "'
              .. output
              .. '"'
              .. ' && echo "'
              .. entry_point
              .. '"'
              .. ' && echo "'
              .. final_message
              .. '"',
            components = { "default_extended" },
          },
        },
      },
    })
    task:start()
  elseif selected_option == "option5" then
    local args = "--warn-implicit-exceptions --warn-unusual-code"
    local task = overseer.new_task({
      name = "- Python machine code compiler",
      strategy = {
        "orchestrator",
        tasks = {
          {
            name = '- Build program → "' .. entry_point .. '"',
            cmd = 'rm -f "'
              .. output
              .. '" || true'
              .. ' && mkdir -p "'
              .. output_dir
              .. '"'
              .. " && nuitka --no-pyi-file --remove-output --follow-imports"
              .. ' --output-filename="'
              .. output
              .. '"'
              .. " "
              .. args
              .. ' "'
              .. entry_point
              .. '"'
              .. ' && echo "'
              .. entry_point
              .. '"'
              .. ' && echo "'
              .. final_message
              .. '"',
            components = { "default_extended" },
          },
        },
      },
    })
    task:start()
  elseif selected_option == "option6" then
    local task = overseer.new_task({
      name = "- Python machine code compiler",
      strategy = {
        "orchestrator",
        tasks = {
          {
            name = '- Run program → "' .. output .. '"',
            cmd = '"'
              .. output
              .. '"'
              .. ' && echo "'
              .. output
              .. '"'
              .. ' && echo "'
              .. final_message
              .. '"',
            components = { "default_extended" },
          },
        },
      },
    })
    task:start()
  elseif selected_option == "option7" then
    local solution_file = utils.get_solution_file()
    local tasks, executables = {}, {}

    if solution_file then
      local config = utils.parse_solution_file(solution_file)
      for entry, vars in pairs(config) do
        if entry ~= "executables" then
          local ep = utils.os_path(vars.entry_point)
          local out = utils.os_path(vars.output)
          local out_dir = utils.os_path(out:match("^(.-[/\\])[^/\\]*$"))
          local args = vars.arguments
            or "--warn-implicit-exceptions --warn-unusual-code"
          table.insert(tasks, {
            name = '- Build program → "' .. ep .. '"',
            cmd = 'rm -f "'
              .. out
              .. '" || true'
              .. ' && mkdir -p "'
              .. out_dir
              .. '"'
              .. " && nuitka --no-pyi-file --remove-output --follow-imports"
              .. ' --output-filename="'
              .. out
              .. '"'
              .. " "
              .. args
              .. ' "'
              .. ep
              .. '"'
              .. ' && echo "'
              .. ep
              .. '"'
              .. ' && echo "'
              .. final_message
              .. '"',
            components = { "default_extended" },
          })
        end
      end
      if config["executables"] then
        for _, exe in pairs(config["executables"]) do
          local e = utils.os_path(exe, true)
          table.insert(executables, {
            name = "- Run program → " .. e,
            cmd = e
              .. " && echo "
              .. e
              .. ' && echo "'
              .. final_message
              .. '"',
            components = { "default_extended" },
          })
        end
      end
      local task = overseer.new_task({
        name = "- Python machine code compiler",
        strategy = { "orchestrator", tasks = { tasks, executables } },
      })
      task:start()
    else
      local entry_points = utils.find_files(vim.fn.getcwd(), "main.py")
      local build_tasks = {}
      for _, ep in ipairs(entry_points) do
        local path = utils.os_path(ep)
        local out_dir =
          utils.os_path(path:match("^(.-[/\\])[^/\\]*$") .. "bin")
        local out = utils.os_path(out_dir .. "/program")
        local args = "--warn-implicit-exceptions --warn-unusual-code"
        table.insert(build_tasks, {
          name = '- Build program → "' .. path .. '"',
          cmd = 'rm -f "'
            .. out
            .. '" || true'
            .. ' && mkdir -p "'
            .. out_dir
            .. '"'
            .. " && nuitka --no-pyi-file --remove-output --follow-imports"
            .. ' --output-filename="'
            .. out
            .. '"'
            .. " "
            .. args
            .. ' "'
            .. path
            .. '"'
            .. ' && echo "'
            .. path
            .. '"'
            .. ' && echo "'
            .. final_message
            .. '"',
          components = { "default_extended" },
        })
      end
      local task = overseer.new_task({
        name = "- Python machine code compiler",
        strategy = { "orchestrator", tasks = build_tasks },
      })
      task:start()
    end

  --============================ BYTECODE ====================================
  elseif selected_option == "option8" then
    local cache_dir =
      utils.os_path(vim.fn.stdpath("cache") .. "/compiler/pyinstall/")
    local output_filename = vim.fn.fnamemodify(output, ":t")
    local args = "--log-level WARN --python-option W"
    local task = overseer.new_task({
      name = "- Python bytecode compiler",
      strategy = {
        "orchestrator",
        tasks = {
          {
            name = '- Build & run program → "' .. entry_point .. '"',
            cmd = 'rm -f "'
              .. output
              .. '" || true'
              .. ' && mkdir -p "'
              .. output_dir
              .. '"'
              .. ' && mkdir -p "'
              .. cache_dir
              .. '"'
              .. " && pyinstaller "
              .. files
              .. " --name "
              .. output_filename
              .. ' --workpath "'
              .. cache_dir
              .. '"'
              .. ' --specpath "'
              .. cache_dir
              .. '"'
              .. ' --onefile --distpath "'
              .. output_dir
              .. '" '
              .. args
              .. ' && "'
              .. output
              .. '"'
              .. ' && echo "'
              .. entry_point
              .. '"'
              .. ' && echo "'
              .. final_message
              .. '"',
            components = { "default_extended" },
          },
        },
      },
    })
    task:start()
  elseif selected_option == "option9" then
    local cache_dir =
      utils.os_path(vim.fn.stdpath("cache") .. "/compiler/pyinstall/")
    local output_filename = vim.fn.fnamemodify(output, ":t")
    local args = "--log-level WARN --python-option W"
    local task = overseer.new_task({
      name = "- Python bytecode compiler",
      strategy = {
        "orchestrator",
        tasks = {
          {
            name = '- Build program → "' .. entry_point .. '"',
            cmd = 'rm -f "'
              .. output
              .. '" || true'
              .. ' && mkdir -p "'
              .. output_dir
              .. '"'
              .. ' && mkdir -p "'
              .. cache_dir
              .. '"'
              .. " && pyinstaller "
              .. files
              .. " --name "
              .. output_filename
              .. ' --workpath "'
              .. cache_dir
              .. '"'
              .. ' --specpath "'
              .. cache_dir
              .. '"'
              .. ' --onefile --distpath "'
              .. output_dir
              .. '" '
              .. args
              .. ' && echo "'
              .. entry_point
              .. '"'
              .. ' && echo "'
              .. final_message
              .. '"',
            components = { "default_extended" },
          },
        },
      },
    })
    task:start()
  elseif selected_option == "option10" then
    local task = overseer.new_task({
      name = "- Python bytecode compiler",
      strategy = {
        "orchestrator",
        tasks = {
          {
            name = '- Run program → "' .. output .. '"',
            cmd = '"'
              .. output
              .. '"'
              .. ' && echo "'
              .. output
              .. '"'
              .. ' && echo "'
              .. final_message
              .. '"',
            components = { "default_extended" },
          },
        },
      },
    })
    task:start()
  elseif selected_option == "option11" then
    local solution_file = utils.get_solution_file()
    local tasks, executables = {}, {}

    if solution_file then
      local config = utils.parse_solution_file(solution_file)
      for entry, vars in pairs(config) do
        if entry ~= "executables" then
          local cache_dir =
            utils.os_path(vim.fn.stdpath("cache") .. "/compiler/pyinstall/")
          local ep = utils.os_path(vars.entry_point)
          local files = utils.find_files_to_compile(ep, "*.py")
          local out = utils.os_path(vars.output)
          local out_name = vim.fn.fnamemodify(out, ":t")
          local out_dir = utils.os_path(out:match("^(.-[/\\])[^/\\]*$"))
          local args = vars.arguments or "--log-level WARN --python-option W"
          table.insert(tasks, {
            name = '- Build program → "' .. ep .. '"',
            cmd = 'rm -f "'
              .. out
              .. '" || true'
              .. ' && mkdir -p "'
              .. out_dir
              .. '"'
              .. ' && mkdir -p "'
              .. cache_dir
              .. '"'
              .. " && pyinstaller "
              .. files
              .. " --name "
              .. out_name
              .. ' --workpath "'
              .. cache_dir
              .. '"'
              .. ' --specpath "'
              .. cache_dir
              .. '"'
              .. ' --onefile --distpath "'
              .. out_dir
              .. '" '
              .. args
              .. ' && echo "'
              .. ep
              .. '"'
              .. ' && echo "'
              .. final_message
              .. '"',
            components = { "default_extended" },
          })
        end
      end
      if config["executables"] then
        for _, exe in pairs(config["executables"]) do
          local e = utils.os_path(exe, true)
          table.insert(executables, {
            name = "- Run program → " .. e,
            cmd = e
              .. " && echo "
              .. e
              .. ' && echo "'
              .. final_message
              .. '"',
            components = { "default_extended" },
          })
        end
      end
      local task = overseer.new_task({
        name = "- Python bytecode compiler",
        strategy = { "orchestrator", tasks = { tasks, executables } },
      })
      task:start()
    else
      local entry_points = utils.find_files(vim.fn.getcwd(), "main.py")
      local build_tasks = {}
      for _, ep in ipairs(entry_points) do
        local path = utils.os_path(ep)
        local files = utils.find_files_to_compile(path, "*.py")
        local cache_dir =
          utils.os_path(vim.fn.stdpath("cache") .. "/compiler/pyinstall/")
        local out_dir =
          utils.os_path(path:match("^(.-[/\\])[^/\\]*$") .. "bin")
        local out = utils.os_path(out_dir .. "/program")
        local out_name = vim.fn.fnamemodify(out, ":t")
        local args = "--log-level WARN --python-option W"
        table.insert(build_tasks, {
          name = '- Build program → "' .. path .. '"',
          cmd = 'rm -f "'
            .. out
            .. '" || true'
            .. ' && mkdir -p "'
            .. cache_dir
            .. '"'
            .. " && pyinstaller "
            .. files
            .. " --name "
            .. out_name
            .. ' --workpath "'
            .. cache_dir
            .. '"'
            .. ' --specpath "'
            .. cache_dir
            .. '"'
            .. ' --onefile --distpath "'
            .. out_dir
            .. '" '
            .. args
            .. ' && echo "'
            .. path
            .. '"'
            .. ' && echo "'
            .. final_message
            .. '"',
          components = { "default_extended" },
        })
      end
      local task = overseer.new_task({
        name = "- Python bytecode compiler",
        strategy = { "orchestrator", tasks = build_tasks },
      })
      task:start()
    end

  --=============================== REPL ====================================
  elseif selected_option == "option12" then
    local task = overseer.new_task({
      name = "- Python REPL",
      strategy = {
        "orchestrator",
        tasks = {
          {
            name = "- Start REPL",
            cmd = "echo 'To exit the REPL enter exit()'"
              .. " && python"
              .. ' && echo "'
              .. final_message
              .. '"',
            components = { "default_extended" },
          },
        },
      },
    })
    task:start()

  --========================= CODE BLOCK ====================================
  elseif selected_option == "option13" then
    local block_file = dump_block_to_temp()
    local task = overseer.new_task({
      name = "- Python ▶ code block",
      strategy = {
        "orchestrator",
        tasks = {
          {
            name = "- Run block → " .. block_file,
            cmd = 'python "'
              .. block_file
              .. '"'
              .. ' && echo "'
              .. block_file
              .. '"'
              .. ' && echo "--block finished--"'
              .. ' && echo "'
              .. final_message
              .. '"',
            components = { "default_extended" },
          },
        },
      },
    })
    task:start()
  end
end

return M
