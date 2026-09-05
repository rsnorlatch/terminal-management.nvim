---@enum BufferType

---@class BufferWrapper
---@field buf_id number
---@field type string
Wrapper = {}

---@param buf number
---@return BufferWrapper
function Wrapper:CreateBufferWrapper(buf, type)
	local wrapper = {}
	setmetatable(Wrapper.mt, wrapper)
	return {
		buf = buf,
		type = type,
	}
end

function Wrapper:IsTerminalBuffer()
	return
end
