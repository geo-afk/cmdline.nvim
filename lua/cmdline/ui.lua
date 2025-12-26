local M = {}
local State = require("cmdline.state")
local config

-- Lazy-load Tree-sitter module
local TreeSitter

---Setup UI module
---@param cfg table
function M.setup(cfg)
	config = cfg
	M.setup_highlights()

	-- Try to load Tree-sitter integration
	local ok, ts = pcall(require, "cmdline.treesitter_parser")
	if ok then
		TreeSitter = ts
	end
end

---Setup highlight groups
function M.setup_highlights()
	local t = config.theme

	-- Create all highlight groups
	vim.api.nvim_set_hl(0, "CmdlineNormal", { bg = t.bg, fg = t.fg })
	vim.api.nvim_set_hl(0, "CmdlineBorder", { fg = t.border_fg, bg = t.border_bg })
	vim.api.nvim_set_hl(0, "CmdlinePrompt", { bg = t.prompt_bg, fg = t.prompt_fg, bold = true })
	vim.api.nvim_set_hl(0, "CmdlinePromptIcon", { fg = t.prompt_icon_fg, bold = true })
	vim.api.nvim_set_hl(0, "CmdlineCursor", { bg = t.cursor_bg, fg = t.cursor_fg })
	vim.api.nvim_set_hl(0, "CmdlineSelection", { bg = t.selection_bg, fg = t.selection_fg, bold = true })
	vim.api.nvim_set_hl(0, "CmdlineItem", { fg = t.item_fg })
	vim.api.nvim_set_hl(0, "CmdlineItemKind", { fg = t.item_kind_fg })
	vim.api.nvim_set_hl(0, "CmdlineItemDesc", { fg = t.item_desc_fg, italic = true })
	vim.api.nvim_set_hl(0, "CmdlineHeader", { bg = t.header_bg, fg = t.header_fg, bold = true })
	vim.api.nvim_set_hl(0, "CmdlineSeparator", { fg = t.separator_fg })
	vim.api.nvim_set_hl(0, "CmdlineHint", { fg = t.hint_fg, italic = true })
	vim.api.nvim_set_hl(0, "CmdlineError", { fg = t.error_fg })
	vim.api.nvim_set_hl(0, "CmdlineSuccess", { fg = t.success_fg })

	-- Tree-sitter groups
	vim.api.nvim_set_hl(0, "CmdlineKeyword", { fg = t.border_fg, bold = true })
	vim.api.nvim_set_hl(0, "CmdlineFunction", { fg = t.success_fg })
	vim.api.nvim_set_hl(0, "CmdlineString", { fg = t.success_fg })
	vim.api.nvim_set_hl(0, "CmdlineNumber", { fg = t.prompt_icon_fg })
	vim.api.nvim_set_hl(0, "CmdlineComment", { fg = t.hint_fg, italic = true })
	vim.api.nvim_set_hl(0, "CmdlineOperator", { fg = t.item_kind_fg })
end

---Calculate window layout
function M.calculate_layout()
	local ui_width = vim.o.columns
	local ui_height = vim.o.lines

	local width = type(config.window.width) == "number"
			and config.window.width < 1
			and math.floor(ui_width * config.window.width)
		or config.window.width
	width = math.max(20, math.min(width, ui_width - 4))

	local height = config.window.height

	local row, col
	if config.window.position == "top" then
		row = 1
		col = math.floor((ui_width - width) / 2)
	elseif config.window.position == "bottom" then
		row = ui_height - height - 2
		col = math.floor((ui_width - width) / 2)
	else
		-- center
		row = math.floor((ui_height - height) / 2)
		col = math.floor((ui_width - width) / 2)
	end

	return {
		relative = config.window.relative,
		row = row,
		col = col,
		width = width,
		height = height,
		style = "minimal",
		border = config.window.border,
		zindex = config.window.zindex,
		title = config.window.title,
		title_pos = config.window.title_pos,
	}
end

---Create the floating window and buffer
function M:create()
	-- Create buffer
	State.buf = vim.api.nvim_create_buf(false, true)
	if not State.buf then
		return false
	end

	-- Set buffer options
	vim.bo[State.buf].buftype = "nofile"
	vim.bo[State.buf].bufhidden = "wipe"
	vim.bo[State.buf].swapfile = false
	vim.bo[State.buf].filetype = "cmdline"

	-- Create window
	local opts = M.calculate_layout()
	State.win = vim.api.nvim_open_win(State.buf, true, opts)
	if not State.win then
		return false
	end

	-- Set window options
	vim.wo[State.win].winblend = config.window.blend or 0
	vim.wo[State.win].winhighlight = "Normal:CmdlineNormal,FloatBorder:CmdlineBorder"
	vim.wo[State.win].wrap = false
	vim.wo[State.win].cursorline = false
	vim.wo[State.win].number = false
	vim.wo[State.win].relativenumber = false
	vim.wo[State.win].signcolumn = "no"

	return true
end

---Get mode icon
local function get_icon(mode)
	if mode == ":" then
		return config.icons.cmdline
	elseif mode == "/" then
		return config.icons.search
	elseif mode == "?" then
		return config.icons.search_up
	elseif mode == "=" then
		return config.icons.lua
	else
		return config.icons.cmdline
	end
end

---Render the UI
function M:render()
	if not State.buf or not vim.api.nvim_buf_is_valid(State.buf) then
		return
	end
	if State.rendering then
		return
	end

	State.rendering = true

	local lines = {}
	local highlights = {}

	-- Build prompt line
	local icon = get_icon(State.mode)
	local prompt_line = icon .. State.text

	-- Hint when empty
	if State.text == "" and config.features.inline_hints then
		local hint = State.mode == "/" and "Search forward..."
			or State.mode == "?" and "Search backward..."
			or State.mode == "=" and "Evaluate expression..."
			or "Enter command..."
		prompt_line = prompt_line .. hint
		table.insert(highlights, {
			line = 0,
			col = vim.fn.strwidth(icon),
			end_col = vim.fn.strwidth(prompt_line),
			hl_group = "CmdlineHint",
		})
	end

	table.insert(lines, prompt_line)

	-- Icon highlight
	table.insert(highlights, {
		line = 0,
		col = 0,
		end_col = vim.fn.strwidth(icon),
		hl_group = "CmdlinePromptIcon",
	})

	-- Text highlight
	if State.text ~= "" then
		table.insert(highlights, {
			line = 0,
			col = vim.fn.strwidth(icon),
			end_col = vim.fn.strwidth(icon .. State.text),
			hl_group = "CmdlinePrompt",
		})
	end

	-- Tree-sitter syntax highlighting
	if TreeSitter and config.treesitter.highlight and State.text ~= "" then
		local syntax_hl = TreeSitter.get_highlights(State.text, State.mode)
		for _, hl in ipairs(syntax_hl) do
			table.insert(highlights, {
				line = 0,
				col = vim.fn.strwidth(icon) + hl.col_start,
				end_col = vim.fn.strwidth(icon) + hl.col_end,
				hl_group = "Cmdline" .. hl.group,
			})
		end
	end

	-- Cursor highlight (overlay on top)
	local cursor_col = vim.fn.strwidth(icon) + vim.fn.strwidth(State.text:sub(1, State.cursor_pos - 1))
	local cursor_char = State.text:sub(State.cursor_pos, State.cursor_pos)
	local cursor_width = cursor_char ~= "" and vim.fn.strwidth(cursor_char) or 1

	table.insert(highlights, {
		line = 0,
		col = cursor_col,
		end_col = cursor_col + cursor_width,
		hl_group = "CmdlineCursor",
		priority = 200, -- Higher priority so it shows on top
	})

	-- Completions section
	if #State.completions > 0 then
		-- Separator
		local sep_line = string.rep(config.icons.separator, 80)
		table.insert(lines, sep_line)
		table.insert(highlights, {
			line = 1,
			col = 0,
			end_col = #sep_line,
			hl_group = "CmdlineSeparator",
		})

		-- Completion items
		local max_items = math.min(#State.completions, config.completion.max_items or 20)
		for i = 1, max_items do
			local item = State.completions[i]
			local selected = (i == State.completion_index)
			local prefix = selected and config.icons.selected or config.icons.item

			-- Get icon for item kind
			local kind_icon = config.icons[item.kind] or ""
			local kind_str = config.completion.show_kind and item.kind and (" " .. kind_icon .. item.kind) or ""
			local desc_str = config.completion.show_desc and item.desc and (" - " .. item.desc) or ""

			local line_text = prefix .. item.text .. kind_str .. desc_str
			table.insert(lines, line_text)

			local line_idx = #lines - 1

			-- Selection background
			if selected then
				table.insert(highlights, {
					line = line_idx,
					col = 0,
					end_col = vim.fn.strwidth(line_text),
					hl_group = "CmdlineSelection",
				})
			end

			-- Kind highlight
			if kind_str ~= "" then
				local start = vim.fn.strwidth(prefix .. item.text)
				table.insert(highlights, {
					line = line_idx,
					col = start,
					end_col = start + vim.fn.strwidth(kind_str),
					hl_group = "CmdlineItemKind",
				})
			end

			-- Description highlight
			if desc_str ~= "" then
				local start = vim.fn.strwidth(prefix .. item.text .. kind_str)
				table.insert(highlights, {
					line = line_idx,
					col = start,
					end_col = start + vim.fn.strwidth(desc_str),
					hl_group = "CmdlineItemDesc",
				})
			end
		end

		-- More indicator
		if #State.completions > max_items then
			local more = string.format("%s %d more...", config.icons.more, #State.completions - max_items)
			table.insert(lines, more)
			table.insert(highlights, {
				line = #lines - 1,
				col = 0,
				end_col = vim.fn.strwidth(more),
				hl_group = "CmdlineHint",
			})
		end
	end

	-- Set buffer content
	pcall(vim.api.nvim_buf_set_lines, State.buf, 0, -1, false, lines)

	-- Clear old highlights
	pcall(vim.api.nvim_buf_clear_namespace, State.buf, State.ns_id, 0, -1)

	-- Apply highlights with proper byte indexing
	for _, hl in ipairs(highlights) do
		-- Convert display width to byte index for the line
		local line_text = lines[hl.line + 1]
		if line_text then
			local byte_col = vim.str_byteindex(line_text, hl.col, true) or hl.col
			local byte_end_col = vim.str_byteindex(line_text, hl.end_col, true) or hl.end_col

			pcall(vim.api.nvim_buf_set_extmark, State.buf, State.ns_id, hl.line, byte_col, {
				end_col = byte_end_col,
				hl_group = hl.hl_group,
				priority = hl.priority or 100,
			})
		end
	end

	-- Resize window to fit content
	local target_height = math.min(#lines, config.window.max_height or 15)
	if State.win and vim.api.nvim_win_is_valid(State.win) then
		local current_height = vim.api.nvim_win_get_height(State.win)
		if target_height ~= current_height then
			pcall(vim.api.nvim_win_set_height, State.win, target_height)
		end
	end

	-- Update cursor position in window
	self:update_cursor(vim.fn.strwidth(icon))

	State.rendering = false
end

---Update cursor position
function M:update_cursor(offset)
	if not State.win or not vim.api.nvim_win_is_valid(State.win) then
		return
	end

	-- Calculate cursor position (display columns)
	local text_before_cursor = State.text:sub(1, State.cursor_pos - 1)
	local col = offset + vim.fn.strwidth(text_before_cursor)

	pcall(vim.api.nvim_win_set_cursor, State.win, { 1, col })
end

---Destroy UI
function M:destroy()
	if State.win and vim.api.nvim_win_is_valid(State.win) then
		pcall(vim.api.nvim_win_close, State.win, true)
	end
	State.win = nil

	if State.buf and vim.api.nvim_buf_is_valid(State.buf) then
		pcall(vim.api.nvim_buf_delete, State.buf, { force = true })
	end
	State.buf = nil
end

return M
