local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local previewers = require("telescope.previewers")

local function get_active_terminal(opts)
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

	opts = opts or {}

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

					vim.api.nvim_command("buffer " .. selected_buffer_id)
				end)

				return true
			end,

			finder = finders.new_table({
				results = active_terminal,
				entry_maker = function(entry)
					return {
						value = entry,
						path = entry[2],
						display = entry[2],
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

local function create_terminal_popup()
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
			if value == "" then
				print("terminal name cannot be empty!")
				return
			end

			if terminal_name_exists(value) then
				print("terminal with the name " .. value .. " already exists!")
				return
			end

			vim.api.nvim_command("term")
			local buf = vim.api.nvim_get_current_buf()

			vim.api.nvim_buf_set_name(buf, value)
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

function M.setup(opts)
	local opts = opts or {}

	vim.api.nvim_create_user_command("TMTestCall", function(args)
		print("test call")
	end, {})

	vim.api.nvim_create_user_command("TMNewTerminal", function(args)
		create_terminal_popup()
	end, {})

	vim.api.nvim_create_user_command("TMListTerminal", function(args)
		get_active_terminal(opts.picker_style)
	end, {})
end

return M
