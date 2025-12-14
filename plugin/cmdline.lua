if vim.g.loaded_cmdline then
	return
end
vim.g.loaded_cmdline = true

local function open_cmdline(mode)
	-- Lazy-load the plugin on first use
	local ok, cmdline = pcall(require, "cmdline")
	if not ok then
		vim.notify("cmdline.nvim failed to load", vim.log.levels.ERROR)
		return
	end

	-- Call the open function (mode is ':', '/', '?', or '=')
	cmdline.open(mode)
end

-- Override command-line mode (:)
vim.keymap.set("n", ":", function()
	open_cmdline(":")
end, { desc = "Open modern cmdline (command mode)" })

-- Override search forward (/)
vim.keymap.set("n", "/", function()
	open_cmdline("/")
end, { desc = "Open modern cmdline (search forward)" })

-- Override search backward (?)
vim.keymap.set("n", "?", function()
	open_cmdline("?")
end, { desc = "Open modern cmdline (search backward)" })

-- Override Lua expression (=) - optional, many users don't override this
vim.keymap.set("n", "=", function()
	open_cmdline("=")
end, { desc = "Open modern cmdline (lua expression)" })

-- Visual mode range support (e.g., :'<,'>delete)
vim.keymap.set("v", ":", function()
	open_cmdline(":")
end, { desc = "Open modern cmdline with visual range" })

-- Optional: Create a user command to manually open the cmdline
vim.api.nvim_create_user_command("Cmdline", function(opts)
	local mode = opts.args ~= "" and opts.args or ":"
	open_cmdline(mode)
end, {
	nargs = "?",
	complete = function()
		return { ":", "/", "?", "=" }
	end,
	desc = "Manually open the modern cmdline",
})
