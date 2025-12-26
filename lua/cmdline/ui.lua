-- lua/cmdline/ui.lua (FULL FIXED VERSION - Better icon visibility)
local M = {}
local State = require("cmdline.state")
local config

local TreeSitter

function M.setup(cfg)
	config = cfg
	M.setup_highlights()

	local ok, ts = pcall(require, "cmdline.treesitter_parser")
	if ok then
		TreeSitter = ts
	end
end

function M.setup_highlights()
	local t = config.theme

	vim.api.nvim_set_hl(0, "CmdlineNormal", { bg = t.bg, fg = t.fg })
	vim.api.nvim_set_hl(0, "CmdlineBorder", { fg = t.border_fg, bg = t.border_bg })
	vim.api.nvim_set_hl(0, "CmdlinePromptIcon", { fg = t.prompt_icon_fg, bold = true })
	vim.api.nvim_set_hl(0, "CmdlineCursor", { bg = t.cursor_bg, fg = t.cursor_fg })
	vim.api.nvim_set_hl(0, "CmdlineSelection", { bg = t.selection_bg, fg = t.selection_fg, bold = true })
	vim.api.nvim_set_hl(0, "CmdlineItem", { fg = t.item_fg })
	vim.api.nvim_set_hl(0, "CmdlineItemKind", { fg = t.item_kind_fg })
	vim.api.nvim_set_hl(0, "CmdlineItemDesc", { fg = t.item_desc_fg, italic = true })
	vim.api.nvim_set_hl(0, "CmdlineSeparator", { fg = t.separator_fg })
	vim.api.nvim_set_hl(0, "CmdlineHint", { fg = t.hint_fg, italic = true })
end

function M.calculate_layout()
	local ui_width = vim.o.columns
	local ui_height = vim.o.lines

	local width = config.window.width
	if type(width) == "number" and width < 1 then
		width = math.floor(ui_width * width)
	end
	width = math.max(40, math.min(width, ui_width - 4))

	local height = config.window.height

	local row, col
	if config.window.position == "top" then
		row = 1
	elseif config.window.position == "bottom" then
		row = ui_height - height - 2
	else
		row = math.floor((ui_height - height) / 2)
	end
	col = math.floor((ui_width - width) / 2)

	return {
		relative = "editor",
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

function M:create()
	local layout = M.calculate_layout()

	State.buf = vim.api.nvim_create_buf(false, true)
	if not State.buf then
		return false
	end

	State.win = vim.api.nvim_open_win(State.buf, true, layout)
	if not State.win then
		return false
	end

	vim.wo[State.win].winhighlight = "Normal:CmdlineNormal,FloatBorder:CmdlineBorder"
	vim.wo[State.win].winblend = config.window.blend or 0
	vim.wo[State.win].wrap = false
	vim.wo[State.win].number = false
	vim.wo[State.win].relativenumber = false
	vim.wo[State.win].cursorline = false
	vim.wo[State.win].signcolumn = "no"
	vim.wo[State.win].foldcolumn = "0"

	vim.bo[State.buf].buftype = "prompt"
	vim.bo[State.buf].bufhidden = "wipe"
	vim.fn.prompt_setprompt(State.buf, "")

	return true
end

function M:render()
	if not State.active or not State.buf or not vim.api.nvim_buf_is_valid(State.buf) or State.rendering then
		return
	end

	State.rendering = true

	local lines = {}
	local highlights = {}

	-- Mode icon with extra space for visibility
	local icon = config.icons.cmdline
	if State.mode == "/" then
		icon = config.icons.search
	end
	if State.mode == "?" then
		icon = config.icons.search_up
	end
	if State.mode == "=" then
		icon = config.icons.lua
	end

	-- Add padding: icon + space + text
	local padded_icon = icon .. " "
	local prompt = padded_icon .. State.text
	table.insert(lines, prompt)

	-- Highlight icon (now fully visible)
	table.insert(highlights, {
		line = 0,
		col = 0,
		end_col = #padded_icon,
		hl_group = "CmdlinePromptIcon",
		priority = 150,
	})

	-- Tree-sitter highlighting (offset by icon + space)
	if TreeSitter and config.treesitter.highlight then
		local hl = TreeSitter.get_highlights(State.text, State.mode)
		for _, h in ipairs(hl) do
			h.line = 0
			h.col_start = h.col_start + #padded_icon
			h.col_end = h.col_end + #padded_icon
			table.insert(highlights, h)
		end
	end

	-- Cursor position (after icon + space)
	table.insert(highlights, {
		line = 0,
		col = #padded_icon + State.cursor_pos - 1,
		end_col = #padded_icon + State.cursor_pos,
		hl_group = "CmdlineCursor",
		priority = 200,
	})

	-- Completions (same as before)
	if #State.completions > 0 then
		table.insert(lines, string.rep("─", vim.api.nvim_win_get_width(State.win or 0)))
		table.insert(highlights, { line = 1, col = 0, end_col = -1, hl_group = "CmdlineSeparator" })

		local max_items = config.completion.max_items or 10
		for i, item in ipairs(State.completions) do
			if i > max_items then
				break
			end
			local selected = i == State.completion_index
			local prefix = selected and "› " or "  "
			local kind_str = config.completion.show_kind and item.kind and (" [" .. item.kind .. "]") or ""
			local desc_str = config.completion.show_desc and item.desc and (" - " .. item.desc) or ""

			local line_text = prefix .. item.text .. kind_str .. desc_str
			table.insert(lines, line_text)

			local line_idx = #lines - 1
			if selected then
				table.insert(
					highlights,
					{ line = line_idx, col = 0, end_col = #line_text, hl_group = "CmdlineSelection" }
				)
			end
			if kind_str ~= "" then
				local start = #prefix + #item.text
				table.insert(
					highlights,
					{ line = line_idx, col = start, end_col = start + #kind_str, hl_group = "CmdlineItemKind" }
				)
			end
			if desc_str ~= "" then
				local start = #prefix + #item.text + #kind_str
				table.insert(
					highlights,
					{ line = line_idx, col = start, end_col = start + #desc_str, hl_group = "CmdlineItemDesc" }
				)
			end
		end

		if #State.completions > max_items then
			local more = string.format("%s %d more...", config.icons.more or "…", #State.completions - max_items)
			table.insert(lines, more)
			table.insert(highlights, { line = #lines - 1, col = 0, end_col = #more, hl_group = "CmdlineHint" })
		end
	end

	-- Apply lines and highlights
	pcall(vim.api.nvim_buf_set_lines, State.buf, 0, -1, false, lines)
	pcall(vim.api.nvim_buf_clear_namespace, State.buf, State.ns_id, 0, -1)

	for _, hl in ipairs(highlights) do
		if hl.line < #lines then
			local line_text = lines[hl.line + 1] or ""
			local col = math.max(0, math.min(hl.col or 0, #line_text))
			local end_col = math.max(col, math.min(hl.end_col or #line_text, #line_text))
			if col < end_col then
				pcall(vim.api.nvim_buf_set_extmark, State.buf, State.ns_id, hl.line, col, {
					end_col = end_col,
					hl_group = hl.hl_group,
					priority = hl.priority or 100,
				})
			end
		end
	end

	-- Resize + bottom pin
	local max_h = tonumber(config.window.max_height) or 15
	local target_height = math.min(#lines, max_h)
	target_height = math.max(1, target_height)

	if State.win and vim.api.nvim_win_is_valid(State.win) then
		local current_height = vim.api.nvim_win_get_height(State.win)
		if target_height ~= current_height then
			pcall(vim.api.nvim_win_set_height, State.win, target_height)
			if config.window.position == "bottom" then
				local ui_height = vim.o.lines
				local new_row = ui_height - target_height - 2
				local win_config = vim.api.nvim_win_get_config(State.win)
				win_config.row = new_row
				pcall(vim.api.nvim_win_set_config, State.win, win_config)
			end
		end
	end

	-- Cursor update using padded offset
	self:update_cursor(#padded_icon)

	State.rendering = false
end

function M:update_cursor(offset)
	if not State.win or not vim.api.nvim_win_is_valid(State.win) then
		return
	end
	local text_before = State.text:sub(1, State.cursor_pos - 1)
	local col = offset + #text_before
	pcall(vim.api.nvim_win_set_cursor, State.win, { 1, col })
end

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
