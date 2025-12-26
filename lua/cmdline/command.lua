local M = {}
local config = {}
-- Utility: trim whitespace (fallback, no dependency)
local function trim(s)
	if not s then
		return ""
	end
	return s:match("^%s*(.-)%s*$") or ""
end
--- Setup module config
---@param cfg table
function M.setup(cfg)
	config = cfg or {}
end
--- Main entry: smart execute based on mode
---@param text string
---@param mode string
---@param context table
---@return boolean success
---@return string|nil error
function M.execute(text, mode, context)
	text = trim(text)
	if text == "" then
		return true, nil
	end
	if mode == ":" then
		return M.execute_cmdline(text, context)
	elseif mode == "/" or mode == "?" then
		return M.execute_search(text, mode, context)
	elseif mode == "=" then
		return M.execute_lua(text)
	end
	return false, "Unknown mode: " .. tostring(mode)
end
--- Execute an Ex command safely
---@param cmd string
---@param context table
---@return boolean
---@return string|nil
function M.execute_cmdline(cmd, context)
	-- Smart quit handling
	if config.features and config.features.smart_quit and M.is_quit_command(cmd) then
		local win = context and context.original_win or vim.api.nvim_get_current_win()
		if win and vim.api.nvim_win_is_valid(win) then
			local force = cmd:find("!") ~= nil
			if cmd:match("^wq") or cmd:match("^x") or cmd:match("^ZZ") then
				local buf = vim.api.nvim_win_get_buf(win)
				if vim.bo[buf].modified then
					local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
						vim.api.nvim_cmd({ cmd = "write" }, {})
					end)
					if not ok then
						return false, "Cannot write buffer: " .. tostring(err)
					end
				end
			end
			pcall(vim.api.nvim_win_close, win, force)
			return true, nil
		end
	end
	local ok, err = pcall(function()
		-- Prepend range if present
		if context and context.range then
			vim.api.nvim_cmd({
				cmd = "execute",
				args = { context.range .. " " .. cmd },
			}, {})
		else
			vim.api.nvim_cmd({ cmd = "execute", args = { cmd } }, {})
		end
	end)
	if not ok then
		local msg = tostring(err):gsub("^E%d+:%s*", "")
		vim.schedule(function()
			require("cmdline.messages").show(msg, "error")
		end)
		return false, msg
	end
	return true, nil
end
--- Search pattern in buffer
---@param pattern string
---@param mode string "/" or "?"
---@param context table
---@return boolean
---@return string|nil
function M.execute_search(pattern, mode, context)
	if trim(pattern) == "" then
		return true, nil
	end
	if context and context.original_win and vim.api.nvim_win_is_valid(context.original_win) then
		pcall(vim.api.nvim_set_current_win, context.original_win)
	end
	local ok, err = pcall(function()
		vim.fn.setreg("/", pattern)
		vim.o.hlsearch = true
		local flags = (mode == "/") and "" or "b"
		vim.fn.search(pattern, flags)
	end)
	if not ok then
		return false, tostring(err)
	end
	return true, nil
end
--- Execute Lua expression or chunk
---@param expr string
---@return boolean
---@return string|nil
function M.execute_lua(expr)
	expr = expr:gsub("^=", "")
	local ok, result = pcall(function()
		local chunk, load_err = load("return " .. expr, "@lua")
		if not chunk then
			chunk, load_err = load(expr, "@lua")
		end
		if not chunk then
			error(load_err)
		end
		return chunk()
	end)
	if not ok then
		return false, tostring(result)
	end
	if result ~= nil then
		vim.schedule(function()
			require("cmdline.messages").show(vim.inspect(result), "info")
		end)
	end
	return true, nil
end
--- Check if the cmd is quit or quit-like
---@param cmd string
---@return boolean
function M.is_quit_command(cmd)
	cmd = trim(cmd)
	-- Strip range if present
	cmd = cmd:gsub("^%d+,%d+%s*", ""):gsub("^%s*", "")
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
	for _, pat in ipairs(quit_patterns) do
		if cmd:match(pat) then
			return true
		end
	end
	return false
end
return M
