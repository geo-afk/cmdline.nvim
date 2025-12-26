local M = {}
local config

function M.setup(cfg)
	config = cfg
end

function M:execute(text, mode, context)
	text = vim.trim(text or "")

	if text == "" then
		return true, nil
	end

	-- Guard: mode should be string
	if type(mode) ~= "string" then
		vim.schedule(function()
			vim.notify("Invalid mode type: " .. vim.inspect(mode), vim.log.levels.ERROR)
		end)
		return false, "Invalid mode"
	end

	if mode == ":" then
		return self:execute_cmdline(text, context)
	elseif mode == "/" or mode == "?" then
		return self:execute_search(text, mode, context)
	elseif mode == "=" then
		return self:execute_lua(text)
	end

	-- Safe error message
	local err_msg = "Unknown mode: " .. vim.inspect(mode)
	vim.schedule(function()
		require("cmdline.messages").show(err_msg, "error")
	end)
	return false, err_msg
end

-- Rest of the functions unchanged from your original
function M:execute_cmdline(cmd, context)
	if config.features.smart_quit and self:is_quit_command(cmd) then
		local target_win = context and context.original_win or vim.api.nvim_get_current_win()
		if target_win and vim.api.nvim_win_is_valid(target_win) then
			local force = cmd:match("!") ~= nil

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

			pcall(vim.api.nvim_win_close, target_win, force)
			return true, nil
		end
	end

	local ok, result = pcall(function()
		if context and context.range then
			cmd = context.range .. cmd
		end
		vim.cmd(cmd)
	end)

	if ok then
		return true, nil
	else
		local err_msg = tostring(result):gsub("^Vim%(.-%):", ""):gsub("^E%d+:%s*", "")
		vim.schedule(function()
			require("cmdline.messages").show(err_msg, "error")
		end)
		return false, err_msg
	end
end

function M:execute_search(pattern, mode, context)
	if pattern == "" then
		return true, nil
	end

	if context and context.original_win and vim.api.nvim_win_is_valid(context.original_win) then
		pcall(vim.api.nvim_set_current_win, context.original_win)
	end

	local search_flags = mode == "/" and "" or "b"

	local ok, result = pcall(function()
		vim.fn.setreg("/", pattern)
		vim.o.hlsearch = true
		vim.fn.search(pattern, search_flags)
	end)

	if ok then
		return true, nil
	else
		return false, tostring(result)
	end
end

function M:execute_lua(expr)
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
