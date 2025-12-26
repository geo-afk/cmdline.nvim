local M = {}
local State = require("cmdline.state")
local Config = require("cmdline.config")
local config

local TreeSitter

-- Cache for performance
local icon_cache = {}
local last_render_hash = nil

function M.setup(cfg)
	config = cfg
	M.setup_highlights()

	local ok, ts = pcall(require, "cmdline.treesitter_parser")
	if ok then
		TreeSitter = ts
	end

	-- Pre-cache icons
	M.cache_icons()
end

function M.cache_icons()
	icon_cache = {}
	for name, _ in pairs(config.icons) do
		icon_cache[name] = Config.get_icon(name, config.ui.use_nerd_fonts)
	end
end

function M.setup_highlights()
	local t = config.theme

	-- Base highlights
	vim.api.nvim_set_hl(0, "CmdlineNormal", { bg = t.bg, fg = t.fg })
	vim.api.nvim_set_hl(0, "CmdlineBorder", { fg = t.border_fg, bg = t.border_bg })
	vim.api.nvim_set_hl(0, "CmdlinePrompt", { bg = t.prompt_bg, fg = t.prompt_fg })
	vim.api.nvim_set_hl(0, "CmdlinePromptIcon", { fg = t.prompt_icon_fg, bold = true })
	vim.api.nvim_set_hl(0, "CmdlineCursor", { bg = t.cursor_bg, fg = t.cursor_fg })
	vim.api.nvim_set_hl(0, "CmdlineSelection", { bg = t.selection_bg, fg = t.selection_fg, bold = true })

	-- Completion highlights
	vim.api.nvim_set_hl(0, "CmdlineItem", { fg = t.item_fg })
	vim.api.nvim_set_hl(0, "CmdlineItemKind", { fg = t.item_kind_fg, bold = true })
	vim.api.nvim_set_hl(0, "CmdlineItemDesc", { fg = t.item_desc_fg, italic = true })
	vim.api.nvim_set_hl(0, "CmdlineItemIcon", { fg = t.item_kind_fg })

	-- UI elements
	vim.api.nvim_set_hl(0, "CmdlineSeparator", { fg = t.separator_fg })
	vim.api.nvim_set_hl(0, "CmdlineHeader", { fg = t.header_fg, bg = t.header_bg, bold = true })
	vim.api.nvim_set_hl(0, "CmdlineHint", { fg = t.hint_fg, italic = true })
	vim.api.nvim_set_hl(0, "CmdlineMatch", { fg = t.match_fg, bold = true })
	vim.api.nvim_set_hl(0, "CmdlineScrollbar", { fg = t.scrollbar_fg })

	-- Status highlights
	vim.api.nvim_set_hl(0, "CmdlineError", { fg = t.error_fg })
	vim.api.nvim_set_hl(0, "CmdlineSuccess", { fg = t.success_fg })
	vim.api.nvim_set_hl(0, "CmdlineInfo", { fg = t.info_fg })
	vim.api.nvim_set_hl(0, "CmdlineWarn", { fg = t.warn_fg })
end

function M.calculate_layout()
	local ui_width = vim.o.columns
	local ui_height = vim.o.lines

	local width = config.window.width
	if type(width) == "number" and width < 1 then
		width = math.floor(ui_width * width)
	end
	width = math.max(50, math.min(width, ui_width - 4))

	local height = config.window.height
	local max_height = config.window.max_height

	local row, col
	if config.window.position == "top" then
		row = 1
	elseif config.window.position == "bottom" then
		row = ui_height - height - 2
	else
		row = math.floor((ui_height - height) / 2)
	end
	col = math.floor((ui_width - width) / 2)

	-- Dynamic title based on mode
	local title = ""
	if config.features.show_mode_hint then
		if State.mode == ":" then
			title = " Command Mode "
		elseif State.mode == "/" then
			title = " Search Forward "
		elseif State.mode == "?" then
			title = " Search Backward "
		elseif State.mode == "=" then
			title = " Lua Expression "
		end
	end

	return {
		relative = "editor",
		row = row,
		col = col,
		width = width,
		height = height,
		style = "minimal",
		border = config.window.border,
		zindex = config.window.zindex,
		title = title,
		title_pos = config.window.title_pos or "center",
	}
end

function M:create()
	local layout = M.calculate_layout()

	State.buf = vim.api.nvim_create_buf(false, true)
	if not State.buf or not vim.api.nvim_buf_is_valid(State.buf) then
		return false
	end

	State.win = vim.api.nvim_open_win(State.buf, true, layout)
	if not State.win or not vim.api.nvim_win_is_valid(State.win) then
		if State.buf and vim.api.nvim_buf_is_valid(State.buf) then
			pcall(vim.api.nvim_buf_delete, State.buf, { force = true })
		end
		return false
	end

	-- Window options
	local win_opts = {
		winhighlight = "Normal:CmdlineNormal,FloatBorder:CmdlineBorder",
		winblend = config.window.blend or 0,
		wrap = false,
		number = false,
		relativenumber = false,
		cursorline = false,
		signcolumn = "no",
		foldcolumn = "0",
		spell = false,
		list = false,
	}

	for opt, val in pairs(win_opts) do
		pcall(vim.api.nvim_set_option_value, opt, val, { win = State.win })
	end

	-- Buffer options
	local buf_opts = {
		buftype = "prompt",
		bufhidden = "wipe",
		swapfile = false,
		modifiable = true,
	}

	for opt, val in pairs(buf_opts) do
		pcall(vim.api.nvim_set_option_value, opt, val, { buf = State.buf })
	end

	-- Set empty prompt
	pcall(vim.fn.prompt_setprompt, State.buf, "")

	return true
end

function M:render()
	if not State.active or not State.buf or not vim.api.nvim_buf_is_valid(State.buf) or State.rendering then
		return
	end

	-- Simple debouncing via hash
	local current_hash =
		string.format("%s:%s:%d:%d", State.text or "", State.mode or "", State.cursor_pos or 0, #State.completions)
	if current_hash == last_render_hash then
		return
	end
	last_render_hash = current_hash

	State.rendering = true

	local ok, err = pcall(function()
		local lines = {}
		local highlights = {}

		-- Get mode icon with proper spacing
		local icon = M.get_mode_icon(State.mode)
		local icon_spacing = string.rep(" ", config.ui.icon_spacing or 2)
		local prompt_prefix = icon .. icon_spacing
		local prompt_width = #prompt_prefix -- Explicitly define for safety

		-- Build prompt line
		local prompt_line = prompt_prefix .. (State.text or "")
		table.insert(lines, prompt_line)

		-- Highlight icon
		table.insert(highlights, {
			line = 0,
			col = 0,
			end_col = #prompt_prefix,
			hl_group = "CmdlinePromptIcon",
			priority = 150,
		})

		-- Tree-sitter syntax highlighting
		if TreeSitter and config.treesitter.highlight then
			local ts_highlights = TreeSitter.get_highlights(State.text or "", State.mode)
			for _, h in ipairs(ts_highlights) do
				table.insert(highlights, {
					line = 0,
					col = h.col_start + prompt_width,
					end_col = h.col_end + prompt_width,
					hl_group = h.group,
					priority = 100,
				})
			end
		end

		-- Cursor highlight
		local cursor_col = prompt_width + (State.cursor_pos or 1) - 1
		table.insert(highlights, {
			line = 0,
			col = cursor_col,
			end_col = cursor_col + 1,
			hl_group = "CmdlineCursor",
			priority = 200,
		})

		-- Render completions if any
		if #State.completions > 0 then
			M.render_completions(lines, highlights, prompt_width)
		end

		-- Apply lines and highlights
		pcall(vim.api.nvim_buf_set_lines, State.buf, 0, -1, false, lines)
		pcall(vim.api.nvim_buf_clear_namespace, State.buf, State.ns_id, 0, -1)
		M.apply_highlights(highlights, lines)

		-- Update window height and cursor
		M.update_window_size(#lines)
		M.update_cursor(prompt_width)
	end)

	State.rendering = false

	if not ok then
		vim.notify("Cmdline render error: " .. tostring(err), vim.log.levels.ERROR)
	end
end

function M.render_completions(lines, highlights, prompt_width)
	local win_width = vim.api.nvim_win_get_width(State.win or 0)

	-- Separator
	local sep_char = config.ui.separator_style == "thick" and "━"
		or config.ui.separator_style == "dotted" and "┈"
		or "─"
	table.insert(lines, string.rep(sep_char, win_width))
	table.insert(highlights, {
		line = #lines - 1,
		col = 0,
		end_col = -1,
		hl_group = "CmdlineSeparator",
		priority = 100,
	})

	-- Optional stats
	if config.features.show_stats then
		local stats = string.format(" %d items ", #State.completions)
		table.insert(lines, stats)
		table.insert(highlights, {
			line = #lines - 1,
			col = 0,
			end_col = #stats,
			hl_group = "CmdlineHint",
			priority = 100,
		})
	end

	-- Render items
	local max_items = config.completion.max_items or 10
	local start_idx = 1
	local end_idx = math.min(#State.completions, max_items)

	if State.completion_index > 0 and State.completion_index > max_items then
		start_idx = State.completion_index - max_items + 1
		end_idx = State.completion_index
	end

	for i = start_idx, end_idx do
		local item = State.completions[i]
		if not item then
			break
		end
		M.render_completion_item(lines, highlights, item, i == State.completion_index, win_width)
	end

	-- "More" indicator
	if #State.completions > max_items then
		local more_text = string.format("  %s %d more...", icon_cache.more or "...", #State.completions - max_items)
		table.insert(lines, more_text)
		table.insert(highlights, {
			line = #lines - 1,
			col = 0,
			end_col = #more_text,
			hl_group = "CmdlineHint",
			priority = 100,
		})
	end
end

function M.render_completion_item(lines, highlights, item, is_selected, win_width)
	local parts = {}
	local col_tracker = 0

	-- Selection indicator
	local selector = is_selected and (icon_cache.selected or "> ") or (icon_cache.unselected or "  ")
	table.insert(parts, selector)
	col_tracker = #selector

	-- Icon
	if config.completion.show_icons and item.kind then
		local icon = icon_cache[item.kind] or icon_cache.Text or "  "
		table.insert(parts, icon)
		local icon_start = col_tracker
		col_tracker = col_tracker + #icon
		table.insert(highlights, {
			line = #lines,
			col = icon_start,
			end_col = col_tracker,
			hl_group = "CmdlineItemIcon",
			priority = 110,
		})
	end

	-- Main text
	local text_start = col_tracker
	table.insert(parts, item.text or "")
	col_tracker = col_tracker + #(item.text or "")

	-- Kind badge
	if config.completion.show_kind and item.kind and config.completion.kind_format ~= "icon_only" then
		local kind_text = config.completion.kind_format == "compact" and string.format(" [%s]", item.kind:sub(1, 1))
			or string.format(" [%s]", item.kind)
		table.insert(parts, kind_text)
		local kind_start = col_tracker
		col_tracker = col_tracker + #kind_text
		table.insert(highlights, {
			line = #lines,
			col = kind_start,
			end_col = col_tracker,
			hl_group = "CmdlineItemKind",
			priority = 105,
		})
	end

	-- Description
	if config.completion.show_desc and item.desc then
		local desc_text = " " .. item.desc
		local available = win_width - col_tracker - 2
		if #desc_text > available then
			desc_text = desc_text:sub(1, available - 3) .. "..."
		end
		table.insert(parts, desc_text)
		local desc_start = col_tracker
		table.insert(highlights, {
			line = #lines,
			col = desc_start,
			end_col = desc_start + #desc_text,
			hl_group = "CmdlineItemDesc",
			priority = 105,
		})
	end

	-- Final line
	local line_text = table.concat(parts, "")
	table.insert(lines, line_text)

	-- Selection background
	if is_selected then
		table.insert(highlights, {
			line = #lines - 1,
			col = 0,
			end_col = #line_text,
			hl_group = "CmdlineSelection",
			priority = 90,
		})
	end

	-- Main text highlight
	table.insert(highlights, {
		line = #lines - 1,
		col = text_start,
		end_col = text_start + #(item.text or ""),
		hl_group = is_selected and "CmdlineSelection" or "CmdlineItem",
		priority = 100,
	})
end

function M.apply_highlights(highlights, lines)
	for _, hl in ipairs(highlights) do
		if hl.line < #lines then
			local line_text = lines[hl.line + 1] or ""
			local col = math.max(0, math.min(hl.col or 0, #line_text))
			local end_col = hl.end_col == -1 and #line_text or math.min(hl.end_col or #line_text, #line_text)

			if col < end_col then
				pcall(vim.api.nvim_buf_set_extmark, State.buf, State.ns_id, hl.line, col, {
					end_col = end_col,
					hl_group = hl.hl_group,
					priority = hl.priority or 100,
					strict = false,
				})
			end
		end
	end
end

function M.update_window_size(line_count)
	if not State.win or not vim.api.nvim_win_is_valid(State.win) then
		return
	end

	local max_height = config.window.max_height or 15
	local target_height = math.min(line_count, max_height)
	target_height = math.max(1, target_height)

	local current_height = vim.api.nvim_win_get_height(State.win)
	if target_height ~= current_height then
		pcall(vim.api.nvim_win_set_height, State.win, target_height)

		if config.window.position == "bottom" then
			local ui_height = vim.o.lines
			-- Respect cmdheight to avoid overlapping Neovim's built-in cmdline
			local new_row = ui_height - target_height - vim.o.cmdheight
			local win_config = vim.api.nvim_win_get_config(State.win)
			win_config.row = new_row
			pcall(vim.api.nvim_win_set_config, State.win, win_config)
		end
	end
end

-- Fixed function with proper nil safety
function M.update_cursor(prompt_width)
	if not prompt_width or prompt_width < 0 then
		return
	end
	if not State.win or not vim.api.nvim_win_is_valid(State.win) then
		return
	end

	local cursor_col = prompt_width + (State.cursor_pos or 1) - 1
	cursor_col = math.max(0, cursor_col)

	local ok, err = pcall(vim.api.nvim_win_set_cursor, State.win, { 1, cursor_col })
	if not ok then
		vim.schedule(function()
			vim.notify("Cursor update failed: " .. tostring(err), vim.log.levels.DEBUG)
		end)
	end
end

function M.get_mode_icon(mode)
	if mode == ":" then
		return icon_cache.cmdline or ": "
	elseif mode == "/" then
		return icon_cache.search or "/ "
	elseif mode == "?" then
		return icon_cache.search_up or "? "
	elseif mode == "=" then
		return icon_cache.lua or "= "
	end
	return "> "
end

function M:destroy()
	last_render_hash = nil

	if State.win and vim.api.nvim_win_is_valid(State.win) then
		pcall(vim.api.nvim_win_close, State.win, true)
	end
	State.win = nil

	if State.buf and vim.api.nvim_buf_is_valid(State.buf) then
		pcall(vim.api.nvim_buf_delete, State.buf, { force = true })
	end
	State.buf = nil
end

function M.refresh_highlights()
	M.setup_highlights()
	M.cache_icons()
	if State.active then
		last_render_hash = nil
		M:render()
	end
end

return M
