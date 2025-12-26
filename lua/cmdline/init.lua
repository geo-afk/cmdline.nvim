local M = {}

local config
local State
local UI
local Input
local Completion
local Command
local Animation

function M.setup(opts)
	local Config = require("cmdline.config")
	config = vim.tbl_deep_extend("force", Config.defaults, opts or {})

	State = require("cmdline.state")
	UI = require("cmdline.ui")
	Input = require("cmdline.input")
	Completion = require("cmdline.completion")
	Command = require("cmdline.command")
	local anim_mod = require("cmdline.animation")
	Animation = anim_mod.Animation
	anim_mod.setup(config)

	UI.setup(config)
	Input.setup(config)
	Completion.setup(config)
	Command.setup(config)

	M.config = config
	M.State = State
	M.UI = UI
	M.Input = Input
	M.Completion = Completion
	M.Command = Command
	M.Animation = Animation

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

	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			if M.State.active then
				M.close()
			end
		end,
	})

	vim.api.nvim_create_autocmd("VimResized", {
		callback = function()
			if M.State.active then
				M.UI:render()
			end
		end,
	})

	return M
end

function M.open(mode)
	if M.State.active then
		return
	end

	mode = mode or ":"
	M.State:init(mode)
	M.State.original_win = vim.api.nvim_get_current_win()
	M.State.original_buf = vim.api.nvim_get_current_buf()

	if mode == ":" then
		local vim_mode = vim.fn.mode()
		if vim.tbl_contains({ "v", "V", "\22" }, vim_mode) then
			M.State.text = "'<,'>"
			M.State.cursor_pos = #M.State.text + 1
			M.State.has_range = true
		end
	end

	if not M.UI:create() then
		vim.notify("Failed to create cmdline window", vim.log.levels.ERROR)
		return
	end

	M.Input:setup_buffer()
	M.UI:render()

	if config.animation.enabled and Animation then
		Animation:fade_in(M.State.win)
		if config.window.position == "bottom" then
			Animation:slide_in(M.State.win, "bottom")
		else
			Animation:scale_in(M.State.win)
		end
	end

	vim.schedule(function()
		if M.State.win and vim.api.nvim_win_is_valid(M.State.win) then
			vim.api.nvim_set_current_win(M.State.win)
			vim.cmd("startinsert")
		end
	end)
end

function M.close()
	if not M.State.active then
		return
	end

	if Animation then
		Animation:cleanup()
	end
	if Completion then
		Completion:cleanup()
	end
	M.UI:destroy()

	if M.State.original_win and vim.api.nvim_win_is_valid(M.State.original_win) then
		pcall(vim.api.nvim_set_current_win, M.State.original_win)
	end

	M.State:reset()
	vim.cmd("stopinsert")
end

function M.execute()
	if not M.State.active then
		return
	end

	local text = vim.trim(M.State.text)
	if text == "" then
		M.close()
		return
	end

	M.State:add_to_history(text)

	local context = {
		mode = M.State.mode,
		text = text,
		original_win = M.State.original_win,
		original_buf = M.State.original_buf,
		range = M.State.has_range and "'<,'>" or nil,
	}

	M.close()

	vim.schedule(function()
		local success, err = Command:execute(text, context.mode, context)
		if not success and err then
			vim.notify(err, vim.log.levels.ERROR)
		end
	end)
end

return M
