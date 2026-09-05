local M = {}

local inspect = require("lib.inspect")

local term_buffer = require("terminal-buffer")
local picker = require("terminal-picker")

local logFilePath = "./logs/terminal-management-logs.log"

os.remove(logFilePath)

local function contains(a_value, in_table)
	for i = 1, #in_table, 1 do
		if in_table[i] == a_value then
			return true
		end
	end

	return false
end

local function log(message)
	local logger = io.open(logFilePath, "a")

	if logger == nil then
		vim.print("log file not found!")
	end

	logger:write(message .. "\n")

	logger:close()
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

local disable_autocommand = false

vim.api.nvim_create_autocmd({ "BufLeave", "BufWinLeave" }, {
	callback = function(args)
		if disable_autocommand then
			return
		end

		local current_buf = vim.api.nvim_get_current_buf()

		if vim.api.nvim_get_option_value("buftype", { buf = current_buf }) == "terminal" then
			term_buffer.term_buffer_push(current_buf)
			return
		end

		if vim.api.nvim_get_option_value("filetype", { buf = current_buf }) == "" then
			return
		end

		if vim.api.nvim_buf_is_loaded(current_buf) == false then
			return
		end

		if (vim.api.nvim_get_option_value("buftype", { buf = current_buf })) == "prompt" then
			return
		end

		log("navigating to non terminal buffer...")
		log_current_buffer()
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

	term_buffer.term_buffer_push(vim.api.nvim_get_current_buf())

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
			highlight = "@markup",
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

M.get_active_terminal = picker.get_active_terminal

return M
