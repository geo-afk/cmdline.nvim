local M = {}
local message_buf = nil
local message_win = nil

---Show message in floating window
---@param msg string
---@param level string "info"|"warn"|"error"
function M.show(msg, level)
	level = level or "info"

	-- Try standard notification first
	local ok = pcall(vim.notify, msg, vim.log.levels[level:upper()])
	if ok then
		return
	end

	-- Fallback: floating window
	if message_win and vim.api.nvim_win_is_valid(message_win) then
		vim.api.nvim_win_close(message_win, true)
	end

	-- Create buffer
	if not message_buf or not vim.api.nvim_buf_is_valid(message_buf) then
		message_buf = vim.api.nvim_create_buf(false, true)
	end

	-- Set content
	local lines = vim.split(msg, "\n")
	vim.api.nvim_buf_set_lines(message_buf, 0, -1, false, lines)

	-- Create window
	local width = math.min(60, vim.o.columns - 4)
	local height = math.min(#lines, 10)

	message_win = vim.api.nvim_open_win(message_buf, false, {
		relative = "editor",
		width = width,
		height = height,
		row = vim.o.lines - height - 3,
		col = vim.o.columns - width - 2,
		style = "minimal",
		border = "rounded",
		zindex = 100,
	})

	-- Color based on level
	local hl = level == "error" and "ErrorMsg" or level == "warn" and "WarningMsg" or "Normal"
	vim.wo[message_win].winhighlight = "Normal:" .. hl

	-- Auto-close after 3 seconds
	vim.defer_fn(function()
		if message_win and vim.api.nvim_win_is_valid(message_win) then
			vim.api.nvim_win_close(message_win, true)
		end
	end, 3000)
end

return M
