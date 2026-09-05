local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local term_buffer_stack = {}
local previous_term_buffer_stack = {}

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

					table.insert(term_buffer_stack, 1, vim.api.nvim_get_current_buf())
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
		return
	end

	if terminal_name_exists(value) then
		print("terminal with the name " .. value .. " already exists!")
		return
	end

	vim.api.nvim_command("term")
	local buf = vim.api.nvim_get_current_buf()

	table.insert(term_buffer_stack, 1, buf)

	vim.api.nvim_buf_set_name(buf, value)
end

vim.api.nvim_create_autocmd("BufLeave", {
	callback = function(args)
		local current_buf = vim.api.nvim_get_current_buf()
		if vim.api.nvim_get_option_value("buftype", { buf = current_buf }) == "terminal" then
			table.insert(term_buffer_stack, 1, current_buf)
		end
	end,
})

function M.previous_terminal()
	if #term_buffer_stack <= 0 then
		print("no more previous terminal")
		return
	end

	vim.api.nvim_set_current_buf(term_buffer_stack[1])
	table.remove(term_buffer_stack, 1)
	table.insert(previous_term_buffer_stack, 1, term_buffer_stack[1])
end

function M.next_terminal()
	if #previous_term_buffer_stack <= 0 then
		print("no more next terminal")
		return
	end

	vim.api.nvim_set_current_buf(previous_term_buffer_stack[1])
	table.remove(previous_term_buffer_stack, 1)
	table.insert(term_buffer_stack, 1, previous_term_buffer_stack[1])
end

--- creates a new terminal with a name specified by the user
--- @param name string|nil
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
