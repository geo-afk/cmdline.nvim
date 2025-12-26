local M = {}

local config
local State
local UI
local Input
local Completion
local Command
local Animation

---Setup the cmdline plugin
---@param opts table|nil User configuration
function M.setup(opts)
	-- Load and merge config
	local Config = require("cmdline.config")
	config = vim.tbl_deep_extend("force", Config.defaults, opts or {})

	-- Require modules AFTER config is ready
	State = require("cmdline.state")
	UI = require("cmdline.ui")
	Input = require("cmdline.input")
	Completion = require("cmdline.completion")
	Command = require("cmdline.command")
	local anim_mod = require("cmdline.animation")
	Animation = anim_mod.Animation
	anim_mod.setup(config) -- setup animation with config

	-- Setup modules
	UI.setup(config)
	Input.setup(config)
	Completion.setup(config)
	Command.setup(config)

	-- Expose for external use
	M.config = config
	M.State = State
	M.UI = UI
	M.Input = Input
	M.Completion = Completion
	M.Command = Command
	M.Animation = Animation

	-- User commands and keymaps
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

	if config.features.default_mappings then
		vim.keymap.set("n", ":", function()
			M.open(":")
		end, { desc = "Command line" })
		vim.keymap.set("n", "/", function()
			M.open("/")
		end, { desc = "Search forward" })
		vim.keymap.set("n", "?", function()
			M.open("?")
		end, { desc = "Search backward" })
		vim.keymap.set("v", ":", function()
			M.open(":")
		end, { desc = "Command line with range" })
		vim.keymap.set("n", "q:", function()
			M.open(":")
		end, { desc = "Command line" })
	end

	-- Cleanup on exit
	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			if State.active then
				M.close()
			end
		end,
	})

	-- Re-render on resize
	vim.api.nvim_create_autocmd("VimResized", {
		callback = function()
			if State.active then
				UI:render()
			end
		end,
	})

	return M
end

function M.open(mode)
	if State.active then
		return
	end

	mode = mode or ":"
	State:init(mode)
	State.original_win = vim.api.nvim_get_current_win()
	State.original_buf = vim.api.nvim_get_current_buf()

	if mode == ":" then
		local vim_mode = vim.fn.mode()
		if vim.tbl_contains({ "v", "V", "\22" }, vim_mode) then
			State.text = "'<,'>"
			State.cursor_pos = #State.text + 1
			State.has_range = true
		end
	end

	if not UI:create() then
		vim.notify("Failed to create cmdline window", vim.log.levels.ERROR)
		return
	end

	Input:setup_buffer()
	UI:render()

	if config.animation.enabled and Animation then
		Animation:fade_in(State.win)
		if config.window.position == "bottom" then
			Animation:slide_in(State.win, "bottom")
		else
			Animation:scale_in(State.win)
		end
	end

	vim.schedule(function()
		if State.win and vim.api.nvim_win_is_valid(State.win) then
			vim.api.nvim_set_current_win(State.win)
			vim.cmd("startinsert")
		end
	end)
end

function M.close()
	if not State.active then
		return
	end

	if Animation then
		Animation:cleanup()
	end
	if Completion then
		Completion:cleanup()
	end
	UI:destroy()

	if State.original_win and vim.api.nvim_win_is_valid(State.original_win) then
		pcall(vim.api.nvim_set_current_win, State.original_win)
	end

	State:reset()
	vim.cmd("stopinsert")
end

function M.execute()
	if not State.active then
		return
	end

	local text = vim.trim(State.text)
	if text == "" then
		M.close()
		return
	end

	State:add_to_history(text)

	local context = {
		mode = State.mode,
		text = text,
		original_win = State.original_win,
		original_buf = State.original_buf,
		range = State.has_range and "'<,'>" or nil,
	}

	M.close()

	vim.schedule(function()
		local success, err = Command.execute(context.text, context.mode, context)
		if not success and err then
			vim.notify(err, vim.log.levels.ERROR)
		end
	end)
end

return M
