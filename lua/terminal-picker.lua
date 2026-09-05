local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

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

return M
