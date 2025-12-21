-- main.lua - Enhanced with modern UI patterns from Noice.nvim
local M = {}

-- Module state
M.config = nil
M.state = {
	active = false,
	mode = ":",
	text = "",
	cursor_pos = 1,
	original_win = nil,
	original_buf = nil,
	range = nil,
	buf = nil,
	win = nil,
	ns_id = vim.api.nvim_create_namespace("cmdline"),
	completions = {},
	completion_idx = 0,
	history_idx = 0,
}

-- Default configuration with modern UI defaults
local defaults = {
	window = {
		relative = "editor",
		position = "center", -- Modern centered floating window
		width = 0.7, -- Wider for better readability
		height = 1,
		max_height = 15,
		border = "rounded",
		zindex = 50,
		blend = 15, -- Subtle transparency
		title = " Command ",
		title_pos = "center",
	},
	icons = {
		cmdline = "󰘳 ",
		search = "󰍉 ",
		search_up = "󰍞 ",
		lua = "󰢱 ",
		filter = "$ ",
		help = "󰋖 ",
	},
	theme = {
		-- Catppuccin Mocha inspired
		bg = "#1e1e2e",
		fg = "#cdd6f4",
		border_fg = "#89b4fa",
		prompt_fg = "#89b4fa",
		prompt_icon_fg = "#f9e2af",
		cursor_bg = "#f38ba8",
		cursor_fg = "#1e1e2e",
		selection_bg = "#45475a",
		selection_fg = "#cdd6f4",
		hint_fg = "#6c7086",
		separator_fg = "#45475a",
		item_kind_fg = "#89b4fa",
		item_desc_fg = "#6c7086",
	},
	completion = {
		enabled = true,
		auto_trigger = true,
		delay = 50,
		max_items = 20,
	},
	keymaps = {
		close = { "<Esc>", "<C-c>" },
		execute = "<CR>",
		backspace = "<BS>",
		delete_word = "<C-w>",
		delete_line = "<C-u>",
		move_left = "<Left>",
		move_right = "<Right>",
		move_home = "<Home>",
		move_end = "<End>",
		history_prev = "<Up>",
		history_next = "<Down>",
		complete_next = "<Tab>",
		complete_prev = "<S-Tab>",
	},
}

-- Setup highlights with modern styling
local function setup_highlights()
	local t = M.config.theme

	-- Main window highlights
	vim.api.nvim_set_hl(0, "CmdlineNormal", { bg = t.bg, fg = t.fg })
	vim.api.nvim_set_hl(0, "CmdlineBorder", { fg = t.border_fg, bold = true })

	-- Prompt highlights
	vim.api.nvim_set_hl(0, "CmdlinePrompt", { fg = t.prompt_fg })
	vim.api.nvim_set_hl(0, "CmdlinePromptIcon", { fg = t.prompt_icon_fg, bold = true })

	-- Cursor with subtle animation feel
	vim.api.nvim_set_hl(0, "CmdlineCursor", { bg = t.cursor_bg, fg = t.cursor_fg, bold = true })

	-- Selection with better contrast
	vim.api.nvim_set_hl(0, "CmdlineSelection", { bg = t.selection_bg, fg = t.selection_fg, bold = true })

	-- Completion items
	vim.api.nvim_set_hl(0, "CmdlineItemKind", { fg = t.item_kind_fg })
	vim.api.nvim_set_hl(0, "CmdlineItemDesc", { fg = t.item_desc_fg, italic = true })

	-- Separator
	vim.api.nvim_set_hl(0, "CmdlineSeparator", { fg = t.separator_fg })

	-- Hints
	vim.api.nvim_set_hl(0, "CmdlineHint", { fg = t.hint_fg, italic = true })
end

-- Get mode icon
local function get_icon(mode)
	local icons = M.config.icons
	if mode == ":" then
		return icons.cmdline
	elseif mode == "/" then
		return icons.search
	elseif mode == "?" then
		return icons.search_up
	elseif mode == "=" then
		return icons.lua
	else
		return icons.cmdline
	end
end

-- Calculate window layout with modern positioning
local function calculate_layout()
	local ui_width = vim.o.columns
	local ui_height = vim.o.lines
	local cfg = M.config.window

	-- Calculate width (responsive)
	local width = type(cfg.width) == "number" and cfg.width < 1 and math.floor(ui_width * cfg.width) or cfg.width
	width = math.max(40, math.min(width, ui_width - 4))

	local height = cfg.height

	-- Position based on config
	local row, col
	if cfg.position == "top" then
		row = 2 -- Slight padding from top
		col = math.floor((ui_width - width) / 2)
	elseif cfg.position == "bottom" then
		row = ui_height - height - 3 -- Padding from bottom
		col = math.floor((ui_width - width) / 2)
	else -- center
		row = math.floor((ui_height - height) / 2.5) -- Slightly higher than dead center
		col = math.floor((ui_width - width) / 2)
	end

	return {
		relative = cfg.relative,
		row = row,
		col = col,
		width = width,
		height = height,
		style = "minimal",
		border = cfg.border,
		zindex = cfg.zindex,
		title = cfg.title,
		title_pos = cfg.title_pos,
	}
end

-- Get history for mode
local function get_history()
	local hist_type = M.state.mode == ":" and "cmd" or "search"
	local history = {}

	for i = vim.fn.histnr(hist_type), 1, -1 do
		local item = vim.fn.histget(hist_type, i)
		if item and item ~= "" then
			table.insert(history, item)
		end
	end

	return history
end

-- Get completions with better grouping
local function get_completions()
	if not M.config.completion.enabled then
		return {}
	end

	local items = {}
	local text = M.state.text
	local prefix = text:match("%S+$") or ""

	if M.state.mode == ":" then
		-- Command completions
		local ok, cmds = pcall(vim.fn.getcompletion, prefix, "cmdline")
		if ok and cmds then
			for _, cmd in ipairs(cmds) do
				table.insert(items, {
					text = cmd,
					kind = "Command",
					icon = "󰘳 ",
				})
			end
		end

		-- Recent history (separated)
		local history = get_history()
		for i = 1, math.min(5, #history) do
			if history[i] ~= text then
				table.insert(items, {
					text = history[i],
					kind = "History",
					icon = "󰋚 ",
				})
			end
		end
	elseif M.state.mode == "/" or M.state.mode == "?" then
		-- Current word under cursor
		local word = vim.fn.expand("<cword>")
		if word and word ~= "" and word ~= text then
			table.insert(items, {
				text = word,
				kind = "Word",
				icon = "󰊄 ",
			})
		end

		-- Search history
		local history = get_history()
		for i = 1, math.min(8, #history) do
			if history[i] ~= text then
				table.insert(items, {
					text = history[i],
					kind = "History",
					icon = "󰋚 ",
				})
			end
		end
	end

	-- Limit items
	if #items > M.config.completion.max_items then
		items = vim.list_slice(items, 1, M.config.completion.max_items)
	end

	return items
end

-- Render UI with improved styling
local function render()
	if not M.state.buf or not vim.api.nvim_buf_is_valid(M.state.buf) then
		return
	end

	local lines = {}
	local highlights = {}

	-- Build prompt line with proper spacing
	local icon = get_icon(M.state.mode)
	local prompt = icon .. M.state.text

	-- Show hint when empty (inspired by Noice.nvim)
	if M.state.text == "" then
		local hint = M.state.mode == "/" and "Search forward..."
			or M.state.mode == "?" and "Search backward..."
			or M.state.mode == "=" and "Evaluate expression..."
			or "Enter command..."
		prompt = prompt .. hint
		table.insert(highlights, {
			line = 0,
			col = vim.fn.strwidth(icon),
			end_col = vim.fn.strwidth(prompt),
			hl = "CmdlineHint",
		})
	end

	table.insert(lines, prompt)

	-- Icon highlight
	table.insert(highlights, {
		line = 0,
		col = 0,
		end_col = vim.fn.strwidth(icon),
		hl = "CmdlinePromptIcon",
	})

	-- Text highlight
	if M.state.text ~= "" then
		table.insert(highlights, {
			line = 0,
			col = vim.fn.strwidth(icon),
			end_col = vim.fn.strwidth(icon .. M.state.text),
			hl = "CmdlinePrompt",
		})
	end

	-- Cursor highlight (with higher priority)
	local cursor_col = vim.fn.strwidth(icon) + vim.fn.strwidth(M.state.text:sub(1, M.state.cursor_pos - 1))
	local cursor_char = M.state.text:sub(M.state.cursor_pos, M.state.cursor_pos)
	local cursor_width = cursor_char ~= "" and vim.fn.strwidth(cursor_char) or 1

	table.insert(highlights, {
		line = 0,
		col = cursor_col,
		end_col = cursor_col + cursor_width,
		hl = "CmdlineCursor",
		priority = 200,
	})

	-- Completions with modern styling
	if #M.state.completions > 0 then
		-- Separator line
		table.insert(lines, string.rep("─", 80))
		table.insert(highlights, {
			line = 1,
			col = 0,
			end_col = 80,
			hl = "CmdlineSeparator",
		})

		-- Completion items
		for i, item in ipairs(M.state.completions) do
			local selected = i == M.state.completion_idx
			local prefix_char = selected and "󰄵 " or "󰄱 "
			local icon_str = item.icon or ""
			local kind = item.kind and (" " .. item.kind) or ""
			local line = prefix_char .. icon_str .. item.text .. kind
			table.insert(lines, line)

			local line_idx = #lines - 1

			-- Selection highlight
			if selected then
				table.insert(highlights, {
					line = line_idx,
					col = 0,
					end_col = vim.fn.strwidth(line),
					hl = "CmdlineSelection",
				})
			end

			-- Kind highlight
			if kind ~= "" then
				local start = vim.fn.strwidth(prefix_char .. icon_str .. item.text)
				table.insert(highlights, {
					line = line_idx,
					col = start,
					end_col = start + vim.fn.strwidth(kind),
					hl = "CmdlineItemKind",
				})
			end
		end

		-- More items indicator
		if #M.state.completions > M.config.completion.max_items then
			local more = string.format("󰇘 %d more...", #M.state.completions - M.config.completion.max_items)
			table.insert(lines, more)
			table.insert(highlights, {
				line = #lines - 1,
				col = 0,
				end_col = vim.fn.strwidth(more),
				hl = "CmdlineHint",
			})
		end
	end

	-- Set buffer content
	pcall(vim.api.nvim_buf_set_lines, M.state.buf, 0, -1, false, lines)

	-- Clear old highlights
	pcall(vim.api.nvim_buf_clear_namespace, M.state.buf, M.state.ns_id, 0, -1)

	-- Apply highlights with byte-accurate positioning
	for _, hl in ipairs(highlights) do
		local line_text = lines[hl.line + 1]
		if line_text then
			local byte_col = vim.str_byteindex(line_text, hl.col, true) or hl.col
			local byte_end_col = vim.str_byteindex(line_text, hl.end_col, true) or hl.end_col

			pcall(vim.api.nvim_buf_set_extmark, M.state.buf, M.state.ns_id, hl.line, byte_col, {
				end_col = byte_end_col,
				hl_group = hl.hl,
				priority = hl.priority or 100,
			})
		end
	end

	-- Resize window dynamically
	local target_height = math.min(#lines, M.config.window.max_height)
	if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
		pcall(vim.api.nvim_win_set_height, M.state.win, target_height)

		-- Set cursor position
		local col = vim.fn.strwidth(icon) + vim.fn.strwidth(M.state.text:sub(1, M.state.cursor_pos - 1))
		pcall(vim.api.nvim_win_set_cursor, M.state.win, { 1, col })
	end
end

-- Trigger completions (debounced)
local completion_timer = nil
local function trigger_completions()
	if not M.config.completion.auto_trigger then
		return
	end

	if completion_timer then
		completion_timer:stop()
		completion_timer:close()
	end

	completion_timer = vim.uv.new_timer()
	completion_timer:start(
		M.config.completion.delay,
		0,
		vim.schedule_wrap(function()
			if M.state.active then
				M.state.completions = get_completions()
				M.state.completion_idx = 0
				render()
			end
			if completion_timer then
				completion_timer:close()
				completion_timer = nil
			end
		end)
	)
end

-- Input handlers (unchanged for brevity - keeping original logic)
local function insert_char(char)
	local before = M.state.text:sub(1, M.state.cursor_pos - 1)
	local after = M.state.text:sub(M.state.cursor_pos)
	M.state.text = before .. char .. after
	M.state.cursor_pos = M.state.cursor_pos + #char
	render()
	trigger_completions()
end

local function delete_char()
	if M.state.cursor_pos <= 1 then
		return
	end
	local before = M.state.text:sub(1, M.state.cursor_pos - 2)
	local after = M.state.text:sub(M.state.cursor_pos)
	M.state.text = before .. after
	M.state.cursor_pos = M.state.cursor_pos - 1
	render()
	trigger_completions()
end

local function delete_word()
	if M.state.cursor_pos <= 1 then
		return
	end
	local before = M.state.text:sub(1, M.state.cursor_pos - 1)
	local word_start = before:match("()%S+%s*$") or 1
	M.state.text = M.state.text:sub(1, word_start - 1) .. M.state.text:sub(M.state.cursor_pos)
	M.state.cursor_pos = word_start
	render()
	trigger_completions()
end

local function delete_line()
	M.state.text = ""
	M.state.cursor_pos = 1
	M.state.completions = {}
	M.state.completion_idx = 0
	render()
end

local function move_cursor(direction)
	if direction == "left" then
		M.state.cursor_pos = math.max(1, M.state.cursor_pos - 1)
	elseif direction == "right" then
		M.state.cursor_pos = math.min(#M.state.text + 1, M.state.cursor_pos + 1)
	elseif direction == "home" then
		M.state.cursor_pos = 1
	elseif direction == "end" then
		M.state.cursor_pos = #M.state.text + 1
	end
	render()
end

local function navigate_history(direction)
	local history = get_history()
	if #history == 0 then
		return
	end

	if direction == "prev" then
		M.state.history_idx = math.min(M.state.history_idx + 1, #history)
	else
		M.state.history_idx = math.max(M.state.history_idx - 1, 0)
	end

	if M.state.history_idx == 0 then
		M.state.text = ""
	else
		M.state.text = history[M.state.history_idx] or ""
	end

	M.state.cursor_pos = #M.state.text + 1
	M.state.completions = {}
	M.state.completion_idx = 0
	render()
end

local function navigate_completions(direction)
	if #M.state.completions == 0 then
		return
	end

	if direction == "next" then
		M.state.completion_idx = M.state.completion_idx % #M.state.completions + 1
	else
		M.state.completion_idx = M.state.completion_idx - 1
		if M.state.completion_idx < 1 then
			M.state.completion_idx = #M.state.completions
		end
	end
	render()
end

local function select_completion()
	if M.state.completion_idx == 0 or M.state.completion_idx > #M.state.completions then
		return
	end

	local item = M.state.completions[M.state.completion_idx]
	local word_start = M.state.text:match("()%S+$") or M.state.cursor_pos
	local before = M.state.text:sub(1, word_start - 1)
	M.state.text = before .. item.text
	M.state.cursor_pos = #M.state.text + 1
	M.state.completions = {}
	M.state.completion_idx = 0
	render()
end

-- Setup buffer keymaps
local function setup_keymaps()
	local buf = M.state.buf
	local opts = { buffer = buf, noremap = true, silent = true }
	local km = M.config.keymaps

	-- Printable characters
	for i = 32, 126 do
		local char = string.char(i)
		vim.keymap.set("i", char, function()
			insert_char(char)
		end, opts)
	end

	-- Special keys
	vim.keymap.set("i", km.backspace, delete_char, opts)
	vim.keymap.set("i", "<C-h>", delete_char, opts)
	vim.keymap.set("i", km.delete_word, delete_word, opts)
	vim.keymap.set("i", km.delete_line, delete_line, opts)

	-- Movement
	vim.keymap.set("i", km.move_left, function()
		move_cursor("left")
	end, opts)
	vim.keymap.set("i", km.move_right, function()
		move_cursor("right")
	end, opts)
	vim.keymap.set("i", km.move_home, function()
		move_cursor("home")
	end, opts)
	vim.keymap.set("i", km.move_end, function()
		move_cursor("end")
	end, opts)
	vim.keymap.set("i", "<C-b>", function()
		move_cursor("left")
	end, opts)
	vim.keymap.set("i", "<C-f>", function()
		move_cursor("right")
	end, opts)
	vim.keymap.set("i", "<C-a>", function()
		move_cursor("home")
	end, opts)
	vim.keymap.set("i", "<C-e>", function()
		move_cursor("end")
	end, opts)

	-- History
	vim.keymap.set("i", km.history_prev, function()
		navigate_history("prev")
	end, opts)
	vim.keymap.set("i", km.history_next, function()
		navigate_history("next")
	end, opts)
	vim.keymap.set("i", "<C-p>", function()
		navigate_history("prev")
	end, opts)
	vim.keymap.set("i", "<C-n>", function()
		navigate_history("next")
	end, opts)

	-- Completion
	vim.keymap.set("i", km.complete_next, function()
		if #M.state.completions > 0 then
			navigate_completions("next")
		else
			trigger_completions()
		end
	end, opts)
	vim.keymap.set("i", km.complete_prev, function()
		navigate_completions("prev")
	end, opts)

	-- Execute
	vim.keymap.set("i", km.execute, function()
		if M.state.completion_idx > 0 then
			select_completion()
		else
			M.execute()
		end
	end, opts)

	-- Close
	for _, key in ipairs(km.close) do
		vim.keymap.set("i", key, function()
			M.close()
		end, opts)
	end
end

-- Execute command
function M.execute()
	if not M.state.active then
		return
	end

	local text = vim.trim(M.state.text)
	if text == "" then
		M.close()
		return
	end

	local mode = M.state.mode
	local original_win = M.state.original_win
	local range = M.state.range

	-- Add to history
	local hist_type = mode == ":" and "cmd" or "search"
	vim.fn.histadd(hist_type, text)

	-- Close first
	M.close()

	-- Execute after closing
	vim.schedule(function()
		-- Restore original window
		if original_win and vim.api.nvim_win_is_valid(original_win) then
			pcall(vim.api.nvim_set_current_win, original_win)
		end

		-- Execute based on mode
		if mode == ":" then
			local cmd = text
			if range then
				cmd = range .. cmd
			end

			local ok, err = pcall(vim.cmd, cmd)
			if not ok then
				local msg = tostring(err):gsub("^Vim%(.-%):", ""):gsub("^E%d+:%s*", "")
				vim.notify(msg, vim.log.levels.ERROR)
			end
		elseif mode == "/" or mode == "?" then
			vim.fn.setreg("/", text)
			vim.o.hlsearch = true
			local flags = mode == "/" and "" or "b"
			pcall(vim.fn.search, text, flags)
		elseif mode == "=" then
			local ok, result = pcall(function()
				local chunk, load_err = loadstring("return " .. text)
				if not chunk then
					chunk, load_err = loadstring(text)
				end
				if not chunk then
					error(load_err)
				end
				return chunk()
			end)

			if ok then
				if result ~= nil then
					print(vim.inspect(result))
				end
			else
				vim.notify(tostring(result), vim.log.levels.ERROR)
			end
		end
	end)
end

-- Open cmdline
function M.open(mode)
	if M.state.active then
		return
	end

	mode = mode or ":"

	-- Initialize state
	M.state.active = true
	M.state.mode = mode
	M.state.text = ""
	M.state.cursor_pos = 1
	M.state.original_win = vim.api.nvim_get_current_win()
	M.state.original_buf = vim.api.nvim_get_current_buf()
	M.state.completions = {}
	M.state.completion_idx = 0
	M.state.history_idx = 0
	M.state.range = nil

	-- Handle visual range
	if mode == ":" then
		local vim_mode = vim.fn.mode()
		if vim.tbl_contains({ "v", "V", "\22" }, vim_mode) then
			M.state.range = "'<,'>"
			M.state.text = "'<,'>"
			M.state.cursor_pos = #M.state.text + 1
		end
	end

	-- Create buffer
	M.state.buf = vim.api.nvim_create_buf(false, true)
	vim.bo[M.state.buf].buftype = "nofile"
	vim.bo[M.state.buf].bufhidden = "wipe"
	vim.bo[M.state.buf].swapfile = false

	-- Create window
	local opts = calculate_layout()
	M.state.win = vim.api.nvim_open_win(M.state.buf, true, opts)

	-- Window options with modern styling
	vim.wo[M.state.win].winblend = M.config.window.blend
	vim.wo[M.state.win].winhighlight = "Normal:CmdlineNormal,FloatBorder:CmdlineBorder"
	vim.wo[M.state.win].wrap = false
	vim.wo[M.state.win].cursorline = false

	-- Setup keymaps and render
	setup_keymaps()
	render()

	-- Enter insert mode
	vim.cmd("startinsert")

	-- Initial completion for command mode
	if mode == ":" and M.state.range == nil then
		vim.defer_fn(function()
			if M.state.active then
				trigger_completions()
			end
		end, 100)
	end
end

-- Close cmdline
function M.close()
	if not M.state.active then
		return
	end

	-- Stop completion timer
	if completion_timer then
		completion_timer:stop()
		completion_timer:close()
		completion_timer = nil
	end

	-- Close window
	if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
		pcall(vim.api.nvim_win_close, M.state.win, true)
	end

	-- Delete buffer
	if M.state.buf and vim.api.nvim_buf_is_valid(M.state.buf) then
		pcall(vim.api.nvim_buf_delete, M.state.buf, { force = true })
	end

	-- Restore original window
	if M.state.original_win and vim.api.nvim_win_is_valid(M.state.original_win) then
		pcall(vim.api.nvim_set_current_win, M.state.original_win)
	end

	-- Reset state
	M.state.active = false
	M.state.mode = ":"
	M.state.text = ""
	M.state.cursor_pos = 1
	M.state.buf = nil
	M.state.win = nil
	M.state.completions = {}
	M.state.completion_idx = 0

	-- Exit insert mode
	vim.cmd("stopinsert")
end

-- Setup function
function M.setup(opts)
	-- Merge config
	M.config = vim.tbl_deep_extend("force", defaults, opts or {})

	-- Setup highlights
	setup_highlights()

	-- Create user commands
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

	-- Setup default keymaps
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

	-- Cleanup on exit
	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			if M.state.active then
				M.close()
			end
		end,
	})

	return M
end

return M
