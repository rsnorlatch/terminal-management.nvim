local M = {}

local inspect = require("lib.inspect")

if log == nil then
	vim.print("log file not found!")
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local term_buffer = require("terminal-buffer")

local logFilePath = "./logs/terminal-management-logs.txt"

os.remove(logFilePath)

local function log(message)
	local log = io.open(logFilePath, "a")

	if log == nil then
		vim.print("log file not found!")
	end

	log:write(message .. "\n")

	log:close()
end

local function log_current_buffer()
	log("currrent_buffer: " .. vim.api.nvim_get_current_buf())
	log(
		"main buffer: "
			.. inspect.inspect(term_buffer.term_buffer_stack)
			.. "\n"
			.. "previous buffer: "
			.. inspect.inspect(term_buffer.previous_term_buffer_stack)
			.. "\n"
	)
end

--- lists all currently active terminal and allow the user the navigate to each terminal
--- telescope.nvim picker option
--- @param opts table|nil
function M.get_active_terminal(opts)
	local active_terminal = vim.iter(vim.api.nvim_list_bufs())
		:filter(function(bufid)
			return vim.api.nvim_buf_is_loaded(bufid)
		end)
		:filter(function(bufid)
			return vim.api.nvim_get_option_value("buftype", { buf = bufid }) == "terminal"
		end)
		:map(function(bufid)
			return { bufid, vim.api.nvim_buf_get_name(bufid) }
		end)
		:totable()

	opts = opts or require("telescope.themes").get_dropdown({})

	pickers
		.new(opts, {
			prompt_title = "active terminal",

			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()

					if selection == nil then
						print("no terminal selected")
						return
					end

					local selected_buffer_id = selection.value[1]

					vim.api.nvim_set_current_buf(selected_buffer_id)
				end)

				return true
			end,

			finder = finders.new_table({
				results = active_terminal,
				entry_maker = function(entry)
					return {
						value = entry,
						path = entry[2],
						display = entry[1] .. " " .. entry[2],
						ordinal = entry[2],
					}
				end,
			}),

			sorter = conf.generic_sorter(opts),
		})
		:find()
end

local disable_autocommand = false

vim.api.nvim_create_autocmd("BufLeave", {
	callback = function(args)
		if disable_autocommand then
			return
		end

		local current_buf = vim.api.nvim_get_current_buf()

		if vim.api.nvim_get_option_value("buftype", { buf = current_buf }) == "terminal" then
			term_buffer.term_buffer_push(current_buf)
		end

		-- log("executing autocommand on leaving buffer")
		-- log_current_buffer()
	end,
})

local function terminal_name_exists(name)
	return #(
			vim.iter(vim.api.nvim_list_bufs())
				:filter(function(buf)
					return vim.api.nvim_buf_get_name(buf) == (vim.fn.getcwd() .. "/" .. name)
				end)
				:totable()
		) > 0
end

local function create_terminal_handler(value)
	if value == "" or value == nil then
		print("terminal name cannot be empty!")
		log("failed to create terminal, name empty")
		return
	end

	if terminal_name_exists(value) then
		print("terminal with the name " .. value .. " already exists!")
		log("failed to create terminal, name exists")
		return
	end

	vim.api.nvim_command("term")
	local buf = vim.api.nvim_get_current_buf()

	vim.api.nvim_buf_set_name(buf, value)

	log("creating terminal...")
	log_current_buffer()
end

function M.previous_terminal()
	disable_autocommand = true
	if #term_buffer.term_buffer_stack <= 0 then
		print("no more previous terminal")
		log("no more previous terminal")
		return
	end

	term_buffer.previous_term_buffer_push(vim.api.nvim_get_current_buf())

	local popped_buffer = term_buffer.term_buffer_pop()
	vim.api.nvim_set_current_buf(popped_buffer)

	log("go to previous terminal...")
	log_current_buffer()

	disable_autocommand = false
end

function M.next_terminal()
	disable_autocommand = true
	if #term_buffer.previous_term_buffer_stack <= 0 then
		print("no more next terminal")
		log("no more next terminal")
		return
	end

	local popped_buffer = term_buffer.previous_term_buffer_pop()
	local next_buffer = popped_buffer

	if popped_buffer == vim.api.nvim_get_current_buf() then
		next_buffer = term_buffer.previous_term_buffer_pop()
	end

	term_buffer.term_buffer_push(vim.api.nvim_get_current_buf())

	vim.api.nvim_set_current_buf(next_buffer)

	log("go to next terminal...")
	log_current_buffer()

	disable_autocommand = false
end

--- creates a new terminal with a name specified by the user
function M.create_terminal()
	local Input = require("nui.input")

	local event = require("nui.utils.autocmd").event
	local input = Input({
		position = "50%",
		size = {
			width = 50,
		},
		border = {
			style = "rounded",
			text = {
				top = " terminal name ",
				top_align = "center",
			},
		},
	}, {
		prompt = "> ",
		on_submit = function(value)
			create_terminal_handler(value)
		end,
	})

	input:mount()

	input:on(event.BufLeave, function()
		input:unmount()
	end)

	input:map("i", "<Esc>", function()
		input:unmount()
	end)
end

return M
