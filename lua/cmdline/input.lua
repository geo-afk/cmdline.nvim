local M = {}

local State = require("cmdline.state")
local UI = require("cmdline.ui")
local Completion
local config

------------------------------------------------------------
-- Setup
------------------------------------------------------------

function M.setup(cfg)
	config = cfg
	Completion = require("cmdline.completion")
end

------------------------------------------------------------
-- Utilities
------------------------------------------------------------

local function clamp_cursor()
	State.cursor_pos = math.max(1, math.min(State.cursor_pos, #State.text + 1))
end

------------------------------------------------------------
-- Buffer keymaps
------------------------------------------------------------

function M:setup_buffer()
	if not State.buf or not vim.api.nvim_buf_is_valid(State.buf) then
		return
	end

	local opts = { buffer = State.buf, noremap = true, silent = true }
	local km = config.keymaps

	----------------------------------------------------------
	-- Character input (IME + paste safe)
	----------------------------------------------------------
	vim.keymap.set("i", "<Char-0>", function()
		local char = vim.fn.nr2char(vim.v.char)
		self:handle_char(char)
	end, opts)

	----------------------------------------------------------
	-- Backspace
	----------------------------------------------------------
	if km.backspace then
		vim.keymap.set("i", km.backspace, function()
			self:handle_backspace()
		end, opts)
		vim.keymap.set("i", "<C-h>", function()
			self:handle_backspace()
		end, opts)
	end

	----------------------------------------------------------
	-- Delete word / line
	----------------------------------------------------------
	if km.delete_word then
		vim.keymap.set("i", km.delete_word, function()
			self:handle_delete_word()
		end, opts)
	end

	if km.delete_line then
		vim.keymap.set("i", km.delete_line, function()
			self:handle_delete_line()
		end, opts)
	end

	----------------------------------------------------------
	-- Cursor movement
	----------------------------------------------------------
	local function move(dir)
		State:move_cursor(dir)
		clamp_cursor()
		UI:render()
	end

	vim.keymap.set("i", km.move_left or "<Left>", function()
		move("left")
	end, opts)
	vim.keymap.set("i", km.move_right or "<Right>", function()
		move("right")
	end, opts)

	if km.move_home then
		vim.keymap.set("i", km.move_home, function()
			move("home")
		end, opts)
	end
	vim.keymap.set("i", "<Home>", function()
		move("home")
	end, opts)

	if km.move_end then
		vim.keymap.set("i", km.move_end, function()
			move("end")
		end, opts)
	end
	vim.keymap.set("i", "<End>", function()
		move("end")
	end, opts)

	----------------------------------------------------------
	-- History navigation
	----------------------------------------------------------
	if config.features.history_nav then
		vim.keymap.set("i", km.history_prev or "<Up>", function()
			self:handle_history("up")
		end, opts)

		vim.keymap.set("i", km.history_next or "<Down>", function()
			self:handle_history("down")
		end, opts)
	end

	----------------------------------------------------------
	-- Completion navigation
	----------------------------------------------------------
	if km.complete_next then
		vim.keymap.set("i", km.complete_next, function()
			self:handle_tab()
		end, opts)
	end

	if km.complete_prev then
		vim.keymap.set("i", km.complete_prev, function()
			self:handle_completion_nav("prev")
		end, opts)
	end

	----------------------------------------------------------
	-- Paste
	----------------------------------------------------------
	if km.paste then
		vim.keymap.set("i", km.paste, function()
			self:handle_paste()
		end, opts)
	end

	----------------------------------------------------------
	-- Execute / close
	----------------------------------------------------------
	if km.execute then
		vim.keymap.set("i", km.execute, function()
			self:handle_execute()
		end, opts)
	end

	if km.close then
		for _, key in ipairs(km.close) do
			vim.keymap.set("i", key, function()
				require("cmdline").close()
			end, opts)
		end
	end
end

------------------------------------------------------------
-- Handlers
------------------------------------------------------------

function M:handle_char(char)
	State:push_undo()
	State:insert_text(char)
	clamp_cursor()
	UI:render()
	Completion:trigger()
end

function M:handle_backspace()
	if State.cursor_pos <= 1 then
		return
	end
	State:push_undo()
	State:delete_char()
	clamp_cursor()
	UI:render()
	Completion:trigger()
end

function M:handle_delete_word()
	State:push_undo()
	State:delete_word()
	clamp_cursor()
	UI:render()
	Completion:trigger()
end

function M:handle_delete_line()
	State:push_undo()
	State.text = ""
	State.cursor_pos = 1
	UI:render()
	Completion:clear()
end

function M:handle_history(direction)
	State:navigate_history(direction)
	State.cursor_pos = #State.text + 1
	UI:render()
end

function M:handle_tab()
	if #State.completions > 0 then
		self:handle_completion_nav("next")
	else
		Completion:trigger_immediate()
	end
end

function M:handle_completion_nav(direction)
	if #State.completions == 0 then
		return
	end
	State:navigate_completions(direction)
	UI:render()
end

function M:handle_completion_select()
	local item = State:get_selected_completion()
	if not item then
		return
	end

	State:push_undo()

	local word_start = State.text:match("()%S+$") or State.cursor_pos
	State.text = State.text:sub(1, word_start - 1) .. item.text
	State.cursor_pos = #State.text + 1

	State:set_completions({})
	UI:render()
end

function M:handle_paste()
	local text = vim.fn.getreg("+")
	if text == "" then
		text = vim.fn.getreg('"')
	end
	if text == "" then
		return
	end

	text = text:gsub("\n", " ")

	State:push_undo()
	State:insert_text(text)
	clamp_cursor()

	UI:render()
	Completion:trigger()
end

function M:handle_execute()
	if #State.completions > 0 and State.completion_index > 0 then
		self:handle_completion_select()
		return
	end
	require("cmdline").execute()
end

return M
