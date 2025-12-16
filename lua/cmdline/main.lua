-- Main module for modern cmdline plugin
-- Handles setup, lifecycle, and coordination

local M = {}
local uv = vim.uv or vim.loop

-- Lazy-loaded modules
local Config, State, UI, Input, Completion, Commands

---@class CmdlineOpts
---@field window? table Window configuration
---@field theme? table Theme configuration
---@field completion? table Completion configuration
---@field features? table Feature flags
---@field keymaps? table Custom keymaps

---Setup the cmdline plugin
---@param opts? CmdlineOpts
function M.setup(opts)
	-- Load configuration first
	Config = require("cmdline.config")
	M.config = vim.tbl_deep_extend("force", Config.defaults, opts or {})

	-- Load other modules
	State = require("cmdline.state")
	UI = require("cmdline.ui")
	Input = require("cmdline.input")
	Completion = require("cmdline.completion")
	Commands = require("cmdline.command")

	-- Initialize modules
	UI.setup(M.config)
	Input.setup(M.config)
	Completion.setup(M.config)
	Commands.setup(M.config)

	-- Setup user commands
	M.create_commands()

	-- Setup default keymaps
	if M.config.features.default_mappings then
		M.setup_keymaps()
	end

	-- Setup autocommands
	M.setup_autocmds()

	return M
end

---Create user commands
function M.create_commands()
	vim.api.nvim_create_user_command("Cmdline", function(args)
		local mode = args.args ~= "" and args.args or ":"
		M.open(mode)
	end, {
		nargs = "?",
		complete = function()
			return { ":", "/", "?", "=" }
		end,
		desc = "Open modern command line",
	})
end

---Setup default keymaps
function M.setup_keymaps()
	local modes = { ":", "/", "?" }

	for _, mode in ipairs(modes) do
		vim.keymap.set("n", mode, function()
			M.open(mode)
		end, { desc = "Modern cmdline: " .. mode })
	end

	-- FIX: Add direct quit commands
	vim.keymap.set("n", "q", function()
		if vim.bo.buftype == "" and not vim.bo.modified then
			vim.cmd("quit")
		else
			return "q" -- Let normal q work (macros, etc)
		end
	end, { expr = true, desc = "Smart quit" })

	-- Visual mode range support
	vim.keymap.set("v", ":", function()
		M.open(":")
	end, { desc = "Modern cmdline with range" })
end

---Setup autocommands
function M.setup_autocmds()
	local group = vim.api.nvim_create_augroup("ModernCmdline", { clear = true })

	-- Cleanup on exit
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			if State.active then
				M.close()
			end
		end,
	})

	-- Handle window close
	vim.api.nvim_create_autocmd("WinClosed", {
		group = group,
		callback = function(args)
			local closed_win = tonumber(args.match)
			if State.win == closed_win then
				M.close()
			end
		end,
	})
end

---Open the cmdline interface
---@param mode string The mode (":", "/", "?", "=")
---@return boolean success
function M.open(mode)
	if State.active then
		return false
	end

	mode = mode or ":"

	-- Initialize state
	State:init(mode)

	-- Store original window
	State.original_win = vim.api.nvim_get_current_win()

	-- Handle visual range
	if mode == ":" then
		local current_mode = vim.fn.mode()
		if vim.tbl_contains({ "v", "V", "\22" }, current_mode) then
			State.text = "'<,'>"
			State.cursor_pos = #State.text + 1
		end
	end

	-- Create UI
	if not UI:create() then
		State:reset()
		return false
	end

	-- Setup input handling
	Input:setup_buffer()

	-- Show initial display
	UI:render()

	-- Trigger initial completion after a delay
	if M.config.completion.enabled and mode ~= "/" and mode ~= "?" then
		vim.defer_fn(function()
			if State.active then
				Completion:trigger()
			end
		end, 50)
	end

	-- Enter insert mode
	vim.cmd("startinsert")

	return true
end

---Close the cmdline interface
function M.close()
	if not State.active then
		return
	end

	-- Cleanup UI
	UI:destroy()

	-- Return to original window
	if State.original_win and vim.api.nvim_win_is_valid(State.original_win) then
		pcall(vim.api.nvim_set_current_win, State.original_win)
	end

	-- Reset state
	State:reset()

	-- Exit insert mode
	vim.cmd("stopinsert")
end

---Execute the current command
function M.execute()
	if not State.active then
		return
	end

	local text = vim.trim(State.text)

	if text == "" then
		M.close()
		return
	end

	-- Save the command text and mode before closing
	local cmd_text = text
	local cmd_mode = State.mode
	local original_win = State.original_win

	-- Add to history
	State:add_to_history(text)

	-- Close UI first to restore context
	M.close()

	-- CRITICAL: Execute command in the original window context
	vim.schedule(function()
		-- Ensure we're in the correct window
		if original_win and vim.api.nvim_win_is_valid(original_win) then
			pcall(vim.api.nvim_set_current_win, original_win)
		end

		-- Force redraw to update screen after closing float
		pcall(vim.api.nvim_cmd, { cmd = "redraw", bang = true }, { output = false })

		-- Execute the command
		local success, err = Commands:execute(cmd_text, cmd_mode)
		if not success and err then
			vim.notify(tostring(err), vim.log.levels.ERROR)
		end
	end)
end

return M
