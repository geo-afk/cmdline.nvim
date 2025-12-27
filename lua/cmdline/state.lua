local M = {
	active = false,
	mode = ":",
	win = nil,
	buf = nil,
	ns_id = vim.api.nvim_create_namespace("cmdline"),
	original_win = nil,
	original_buf = nil,
	has_range = false,
	rendering = false,

	-- Input state
	text = "",
	cursor_pos = 1,

	-- Completion state
	completions = {},
	completion_index = 0,
	completion_cache = {},

	-- History state
	history_index = 0,
	history_cache = {},

	-- Undo/Redo
	undo_stack = {},
	redo_stack = {},
	max_undo = 50,
}

---Initialize state for new session
---@param mode string
function M:init(mode)
	self.active = true
	self.last_undo_time = 0
	self.mode = mode or ":"
	self.text = ""
	self.cursor_pos = 1
	self.completions = {}
	self.completion_index = 0
	self.history_index = 0
	self.undo_stack = {}
	self.redo_stack = {}
	self.has_range = false
	self.original_buf = nil
	self.rendering = false
end

---Reset all state
function M:reset()
	self.active = false
	self.mode = ":"
	self.win = nil
	self.buf = nil
	self.original_win = nil
	self.original_buf = nil
	self.has_range = false
	self.text = ""
	self.cursor_pos = 1
	self.completions = {}
	self.completion_index = 0
	self.history_index = 0
	self.undo_stack = {}
	self.redo_stack = {}
	self.history_cache = {}
	self.completion_cache = {}
	self.rendering = false
end

---Push current state to undo stack
function M:push_undo()
	table.insert(self.undo_stack, {
		text = self.text,
		cursor_pos = self.cursor_pos,
	})

	-- Limit undo stack size
	if #self.undo_stack > self.max_undo then
		table.remove(self.undo_stack, 1)
	end

	-- Clear redo stack on new change
	self.redo_stack = {}
end

local function push_undo_grouped()
	local now = vim.loop.hrtime()
	if now - (State.last_undo_time or 0) > 300000000 then
		State:push_undo()
	end
	State.last_undo_time = now
end

---Undo last change
---@return boolean success
function M:undo()
	if #self.undo_stack == 0 then
		return false
	end

	-- Save current state to redo
	table.insert(self.redo_stack, {
		text = self.text,
		cursor_pos = self.cursor_pos,
	})

	-- Restore previous state
	local state = table.remove(self.undo_stack)
	self.text = state.text
	self.cursor_pos = math.min(state.cursor_pos, #self.text + 1)

	return true
end

---Redo last undone change
---@return boolean success
function M:redo()
	if #self.redo_stack == 0 then
		return false
	end

	-- Save current state to undo
	table.insert(self.undo_stack, {
		text = self.text,
		cursor_pos = self.cursor_pos,
	})

	-- Restore redone state
	local state = table.remove(self.redo_stack)
	self.text = state.text
	self.cursor_pos = math.min(state.cursor_pos, #self.text + 1)

	return true
end

---Get history for current mode
---@return string[] history
function M:get_history()
	local hist_type = self.mode == ":" and "cmd" or "search"

	-- Cache history to avoid repeated vim.fn calls
	local cache_key = hist_type
	if self.history_cache[cache_key] then
		return self.history_cache[cache_key]
	end

	local history = {}
	local max = vim.fn.histnr(hist_type)

	-- Get history from Vim (newest first)
	for i = max, 1, -1 do
		local item = vim.fn.histget(hist_type, i)
		if item and item ~= "" then
			table.insert(history, item)
		end
	end

	self.history_cache[cache_key] = history
	return history
end

---Add text to history
---@param text string
function M:add_to_history(text)
	if text == "" then
		return
	end

	local hist_type = self.mode == ":" and "cmd" or "search"
	vim.fn.histadd(hist_type, text)

	-- Clear cache
	self.history_cache = {}
end

---Navigate history
---@param direction "up"|"down"
---@return boolean changed
function M:navigate_history(direction)
	local history = self:get_history()

	if #history == 0 then
		return false
	end

	if direction == "up" then
		self.history_index = math.min(self.history_index + 1, #history)
	else
		self.history_index = math.max(self.history_index - 1, 0)
	end

	if self.history_index == 0 then
		self.text = ""
	else
		self.text = history[self.history_index] or ""
	end

	self.cursor_pos = #self.text + 1
	return true
end

---Set completions
---@param completions table[]
function M:set_completions(completions)
	self.completions = completions or {}
	self.completion_index = 0 -- Don't auto-select
end

---Navigate completions
---@param direction "next"|"prev"
function M:navigate_completions(direction)
	if #self.completions == 0 then
		return
	end

	if direction == "next" then
		if self.completion_index == 0 then
			self.completion_index = 1
		else
			self.completion_index = self.completion_index % #self.completions + 1
		end
	else
		if self.completion_index == 0 then
			self.completion_index = #self.completions
		else
			self.completion_index = self.completion_index - 1
			if self.completion_index < 1 then
				self.completion_index = #self.completions
			end
		end
	end
end

---Get currently selected completion
---@return table|nil
function M:get_selected_completion()
	if self.completion_index > 0 and self.completion_index <= #self.completions then
		return self.completions[self.completion_index]
	end
	return nil
end

---Insert text at cursor position
---@param str string
function M:insert_text(str)
	-- Ensure cursor_pos is valid
	self.cursor_pos = math.max(1, math.min(self.cursor_pos, #self.text + 1))

	local before = self.text:sub(1, self.cursor_pos - 1)
	local after = self.text:sub(self.cursor_pos)
	self.text = before .. str .. after
	self.cursor_pos = self.cursor_pos + #str
end

---Delete character before cursor
---@return boolean deleted
function M:delete_char()
	if self.cursor_pos <= 1 then
		return false
	end

	local before = self.text:sub(1, self.cursor_pos - 2)
	local after = self.text:sub(self.cursor_pos)
	self.text = before .. after
	self.cursor_pos = self.cursor_pos - 1

	return true
end

---Delete word before cursor
function M:delete_word()
	if self.cursor_pos <= 1 then
		return
	end

	local before = self.text:sub(1, self.cursor_pos - 1)
	local word_start = before:match("()%S+%s*$") or 1

	self.text = self.text:sub(1, word_start - 1) .. self.text:sub(self.cursor_pos)
	self.cursor_pos = word_start
end

---Move cursor
---@param direction "left"|"right"|"home"|"end"
function M:move_cursor(direction)
	if direction == "left" then
		self.cursor_pos = math.max(1, self.cursor_pos - 1)
	elseif direction == "right" then
		self.cursor_pos = math.min(#self.text + 1, self.cursor_pos + 1)
	elseif direction == "home" then
		self.cursor_pos = 1
	elseif direction == "end" then
		self.cursor_pos = #self.text + 1
	end
end

return M
