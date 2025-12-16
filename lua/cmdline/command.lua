-- Handles smart command execution with proper context restoration

local M = {}
local config

---Setup commands module
---@param cfg table
function M.setup(cfg)
	config = cfg
end

---Execute command with smart handling
---@param text string Command text
---@param mode string Command mode
---@param context table Original context (window, buffer, range)
---@return boolean success
---@return string|nil error
function M:execute(text, mode, context)
	text = vim.trim(text)

	if text == "" then
		return true, nil
	end

	-- Handle different modes
	if mode == ":" then
		return self:execute_cmdline(text, context)
	elseif mode == "/" or mode == "?" then
		return self:execute_search(text, mode, context)
	elseif mode == "=" then
		return self:execute_lua(text)
	end

	return false, "Unknown mode: " .. mode
end

---Execute command line command
---@param cmd string
---@param context table
---@return boolean success
---@return string|nil error
function M:execute_cmdline(cmd, context)
	-- Handle smart quit
	if config.features.smart_quit and self:is_quit_command(cmd) then
		local target_win = context and context.original_win or vim.api.nvim_get_current_win()
		if target_win and vim.api.nvim_win_is_valid(target_win) then
			local force = cmd:match("!") ~= nil

			-- Handle write-quit commands
			if cmd:match("^wq") or cmd:match("^x") or cmd:match("^ZZ") then
				local buf = vim.api.nvim_win_get_buf(target_win)
				if vim.bo[buf].modified then
					local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
						vim.cmd("write")
					end)
					if not ok then
						return false, "Cannot write buffer: " .. tostring(err)
					end
				end
			end

			-- Close target window
			pcall(vim.api.nvim_win_close, target_win, force)
			return true, nil
		end
	end

	-- CRITICAL FIX: Execute command with proper context and range support
	local ok, result = pcall(function()
		-- If we have a range context, prepend it to the command
		if context and context.range then
			cmd = context.range .. cmd
		end

		-- Use vim.cmd which properly handles all command types
		-- This supports user commands, plugin commands, and built-in commands
		vim.cmd(cmd)
	end)

	if ok then
		return true, nil
	else
		local err_msg = tostring(result):gsub("^Vim%(.-%):", ""):gsub("^E%d+:%s*", "")

		-- FIX: Use reliable message system
		vim.schedule(function()
			require("cmdline.messages").show(err_msg, "error")
		end)
		return false, err_msg
	end
end

---Execute search command
---@param pattern string
---@param mode string
---@param context table
---@return boolean success
---@return string|nil error
function M:execute_search(pattern, mode, context)
	if pattern == "" then
		return true, nil
	end

	-- Ensure we're in the right window for search
	if context and context.original_win and vim.api.nvim_win_is_valid(context.original_win) then
		pcall(vim.api.nvim_set_current_win, context.original_win)
	end

	-- Escape pattern for vim.fn.search if needed
	local search_flags = mode == "/" and "" or "b"

	local ok, result = pcall(function()
		-- Set the search register
		vim.fn.setreg("/", pattern)
		vim.o.hlsearch = true

		-- Perform the search
		vim.fn.search(pattern, search_flags)
	end)

	if ok then
		return true, nil
	else
		return false, tostring(result)
	end
end

---Execute Lua expression
---@param expr string
---@return boolean success
---@return string|nil error
function M:execute_lua(expr)
	-- Remove leading '=' if present
	expr = expr:gsub("^=", "")

	local ok, result = pcall(function()
		local chunk, err = loadstring("return " .. expr)
		if not chunk then
			chunk, err = loadstring(expr)
		end

		if not chunk then
			error(err)
		end

		return chunk()
	end)

	if ok then
		if result ~= nil then
			print(vim.inspect(result))
		end
		return true, nil
	else
		return false, tostring(result)
	end
end

---Check if command is a quit command
---@param cmd string
---@return boolean
function M:is_quit_command(cmd)
	local quit_patterns = {
		"^q!?$",
		"^quit!?$",
		"^qa!?$",
		"^qall!?$",
		"^wq!?$",
		"^x!?$",
		"^exit!?$",
		"^ZQ$",
		"^ZZ$",
	}

	cmd = vim.trim(cmd)
	for _, pattern in ipairs(quit_patterns) do
		if cmd:match(pattern) then
			return true
		end
	end

	return false
end

return M
