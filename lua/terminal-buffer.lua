local M = {
	term_buffer_stack = {},
	previous_term_buffer_stack = {},
}

local function buffer_exists(stack, buf)
	return vim.iter(stack):any(function(current_buf)
		return current_buf == buf
	end)
end

function M.term_buffer_push(value)
	if buffer_exists(M.term_buffer_stack, value) then
		return
	end

	table.insert(M.term_buffer_stack, 1, value)
end

function M.previous_term_buffer_push(value)
	if buffer_exists(M.previous_term_buffer_stack, value) then
		return
	end

	table.insert(M.previous_term_buffer_stack, 1, value)
end

function M.term_buffer_pop()
	local removedBuffer = M.term_buffer_stack[1]
	table.remove(M.term_buffer_stack, 1)

	return removedBuffer
end

function M.previous_term_buffer_pop()
	local removedBuffer = M.term_buffer_stack[1]
	table.remove(M.previous_term_buffer_stack, 1)

	return removedBuffer
end

return M
