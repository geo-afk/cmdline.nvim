local M = {}
local State = require("cmdline.state")
local UI = require("cmdline.ui")
local Completion
local config

---Setup input module
---@param cfg table
function M.setup(cfg)
	config = cfg
	Completion = require("cmdline.completion")
end

---Setup buffer keymaps
function M:setup_buffer()
	if not State.buf or not vim.api.nvim_buf_is_valid(State.buf) then
		return
	end

	local opts = { buffer = State.buf, noremap = true, silent = true }
	local km = config.keymaps

	-- Character input (printable ASCII)
	for i = 32, 126 do
		local char = string.char(i)
		vim.keymap.set("i", char, function()
			self:handle_char(char)
		end, opts)
	end

	-- Backspace
	if km.backspace then
		vim.keymap.set("i", km.backspace, function()
			self:handle_backspace()
		end, opts)
		vim.keymap.set("i", "<C-h>", function()
			self:handle_backspace()
		end, opts)
	end

	-- Delete word
	if km.delete_word then
		vim.keymap.set("i", km.delete_word, function()
			self:handle_delete_word()
		end, opts)
	end

	-- Delete line
	if km.delete_line then
		vim.keymap.set("i", km.delete_line, function()
			self:handle_delete_line()
		end, opts)
	end

	-- Movement
	if km.move_left then
		vim.keymap.set("i", km.move_left, function()
			State:move_cursor("left")
			UI:render()
		end, opts)
	end

	if km.move_right then
		vim.keymap.set("i", km.move_right, function()
			State:move_cursor("right")
			UI:render()
		end, opts)
	end

	if km.move_home then
		vim.keymap.set("i", km.move_home, function()
			State:move_cursor("home")
			UI:render()
		end, opts)
		vim.keymap.set("i", "<Home>", function()
			State:move_cursor("home")
			UI:render()
		end, opts)
	end

	if km.move_end then
		vim.keymap.set("i", km.move_end, function()
			State:move_cursor("end")
			UI:render()
		end, opts)
		vim.keymap.set("i", "<End>", function()
			State:move_cursor("end")
			UI:render()
		end, opts)
	end

	-- Additional movement keys
	vim.keymap.set("i", "<Left>", function()
		State:move_cursor("left")
		UI:render()
	end, opts)

	vim.keymap.set("i", "<Right>", function()
		State:move_cursor("right")
		UI:render()
	end, opts)

	-- History navigation
	if config.features.history_nav then
		if km.history_prev then
			vim.keymap.set("i", km.history_prev, function()
				self:handle_history("up")
			end, opts)
			vim.keymap.set("i", "<Up>", function()
				self:handle_history("up")
			end, opts)
		end

		if km.history_next then
			vim.keymap.set("i", km.history_next, function()
				self:handle_history("down")
			end, opts)
			vim.keymap.set("i", "<Down>", function()
				self:handle_history("down")
			end, opts)
		end
	else
		-- Use Up/Down for completion if history nav disabled
		vim.keymap.set("i", "<Up>", function()
			self:handle_completion_nav("prev")
		end, opts)
		vim.keymap.set("i", "<Down>", function()
			self:handle_completion_nav("next")
		end, opts)
	end

	-- Completion navigation
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

	-- Telescope picker
	if config.features.telescope_picker and km.telescope_picker then
		vim.keymap.set("i", km.telescope_picker, function()
			self:handle_telescope_picker()
		end, opts)
	end

	-- Undo/Redo
	if config.features.undo_redo then
		if km.undo then
			vim.keymap.set("i", km.undo, function()
				self:handle_undo()
			end, opts)
		end

		if km.redo then
			vim.keymap.set("i", km.redo, function()
				self:handle_redo()
			end, opts)
		end
	end

	-- Paste - FIXED: Handle paste properly
	if km.paste then
		vim.keymap.set("i", km.paste, function()
			self:handle_paste()
		end, opts)
	end

	-- Execution and close
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

---Handle character input
---@param char string
function M:handle_char(char)
	State:push_undo()

	-- Auto-pair handling
	if config.features.auto_pairs then
		local pairs = {
			["("] = ")",
			["["] = "]",
			["{"] = "}",
			["'"] = "'",
			['"'] = '"',
		}

		if pairs[char] then
			local after = State.text:sub(State.cursor_pos)
			-- Only auto-pair if not followed by word character
			if not after:match("^%w") then
				State:insert_text(char .. pairs[char])
				State.cursor_pos = State.cursor_pos - 1
				UI:render()
				Completion:trigger()
				return
			end
		end
	end

	State:insert_text(char)
	UI:render()
	Completion:trigger()
end

---Handle backspace
function M:handle_backspace()
	local before = State.text
	if State:delete_char() then
		-- Only push undo if text actually changed
		if before ~= State.text then
			State:push_undo()
		end
		UI:render()
		Completion:trigger()
	end
end

---Handle delete word
function M:handle_delete_word()
	State:push_undo()
	State:delete_word()
	UI:render()
	Completion:trigger()
end

---Handle delete line
function M:handle_delete_line()
	State:push_undo()
	State.text = ""
	State.cursor_pos = 1
	UI:render()
	Completion:clear()
end

---Handle history navigation
---@param direction "up"|"down"
function M:handle_history(direction)
	State:navigate_history(direction)
	UI:render()
end

---Handle tab completion
function M:handle_tab()
	if #State.completions > 0 then
		-- Navigate to next completion
		self:handle_completion_nav("next")
	else
		-- Trigger completion
		Completion:trigger_immediate()
	end
end

---Handle completion navigation
---@param direction "next"|"prev"
function M:handle_completion_nav(direction)
	if #State.completions == 0 then
		return
	end

	State:navigate_completions(direction)
	UI:render()
end

---Handle completion selection
function M:handle_completion_select()
	local item = State:get_selected_completion()
	if not item then
		return
	end

	State:push_undo()

	-- Replace current word with completion
	local word_start = State.text:match("()%S+$") or State.cursor_pos
	local before = State.text:sub(1, word_start - 1)
	State.text = before .. item.text
	State.cursor_pos = #State.text + 1

	-- Clear completions
	State:set_completions({})

	UI:render()
end

---Handle Telescope picker
function M:handle_telescope_picker()
	if Completion and Completion.show_telescope_picker then
		Completion:show_telescope_picker()
	else
		vim.notify("Telescope picker not available", vim.log.levels.WARN)
	end
end

---Handle undo
function M:handle_undo()
	if State:undo() then
		UI:render()
	end
end

---Handle redo
function M:handle_redo()
	if State:redo() then
		UI:render()
	end
end

---Handle paste from register - FIXED
function M:handle_paste()
	-- Get next character for register
	local ok, reg_char = pcall(vim.fn.getcharstr)
	if not ok or not reg_char then
		return
	end

	-- Get content from register
	local content = vim.fn.getreg(reg_char)
	if content == "" then
		return
	end

	-- Remove newlines if present (flatten to single line)
	content = content:gsub("\n", " ")

	State:push_undo()

	-- Insert the text at cursor position
	State:insert_text(content)

	-- Ensure cursor is at the end of inserted text and within bounds
	State.cursor_pos = math.min(State.cursor_pos, #State.text + 1)

	UI:render()
	Completion:trigger()
end

---Handle command execution
function M:handle_execute()
	-- Select completion if one is selected
	if #State.completions > 0 and State.completion_index > 0 then
		self:handle_completion_select()
		return
	end

	-- Execute command
	require("cmdline").execute()
end

return M
