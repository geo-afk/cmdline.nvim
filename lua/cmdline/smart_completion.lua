local M = {}
local State = require("cmdline.state")
local Context = require("cmdline.context")
local Telescope = require("cmdline.telescope_integration")
local TreeSitter = require("cmdline.treesitter_parser")

function M.setup()
	Context.setup()
	Telescope.setup()
	TreeSitter.setup()
end

---Get smart completions based on context
---@param callback function
function M.get_smart_completions(callback)
	local text = State.text
	local mode = State.mode

	-- Infer intent from input
	local intent = Context.infer_intent(text)

	-- Get completions based on intent
	if intent.type == "file_edit" then
		M.get_file_completions(text, callback)
	elseif intent.type == "buffer_switch" or intent.type == "buffer_delete" then
		M.get_buffer_completions(callback)
	elseif intent.type == "lsp_query" then
		M.get_lsp_completions(callback)
	elseif intent.type == "git_command" then
		M.get_git_completions(callback)
	elseif intent.type == "help" then
		M.get_help_completions(text, callback)
	elseif mode == "/" or mode == "?" then
		M.get_search_completions(callback)
	else
		M.get_general_completions(callback)
	end
end

---Get file completions with Telescope integration
---@param text string
---@param callback function
function M.get_file_completions(text, callback)
	-- Extract partial path from command
	local partial = text:match("%s+(.+)$") or ""

	Context.get_project_files(function(files)
		local items = {}

		for _, file in ipairs(files) do
			if vim.startswith(file, partial) or partial == "" then
				table.insert(items, {
					text = file,
					kind = "File",
					path = file,
					priority = 100,
				})
			end
		end

		-- Limit to reasonable number
		if #items > 50 then
			items = vim.list_slice(items, 1, 50)
		end

		callback(items)
	end)
end

---Get buffer completions
---@param callback function
function M.get_buffer_completions(callback)
	local buffers = Context.get_buffers()
	local items = {}

	for _, buf in ipairs(buffers) do
		table.insert(items, {
			text = buf.name,
			kind = "Buffer",
			desc = buf.path,
			bufnr = buf.bufnr,
			priority = buf.current and 150 or (buf.modified and 120 or 100),
		})
	end

	callback(items)
end

---Get LSP completions
---@param callback function
function M.get_lsp_completions(callback)
	-- Check if LSP is available
	local clients = Context.get_lsp_clients()
	if #clients == 0 then
		callback({})
		return
	end

	-- Get document symbols
	Context.get_lsp_symbols(function(symbols)
		local items = {}

		for _, symbol in ipairs(symbols) do
			table.insert(items, {
				text = symbol.name,
				kind = symbol.kind,
				desc = symbol.prefix ~= "" and symbol.prefix or nil,
				priority = 110,
			})
		end

		callback(items)
	end)
end

---Get git completions
---@param callback function
function M.get_git_completions(callback)
	Context.get_git_status(function(status)
		local items = {}

		-- Add modified files
		for _, file in ipairs(status.modified or {}) do
			table.insert(items, {
				text = file,
				kind = "Modified",
				desc = "Modified file",
				priority = 120,
			})
		end

		-- Add staged files
		for _, file in ipairs(status.staged or {}) do
			table.insert(items, {
				text = file,
				kind = "Staged",
				desc = "Staged file",
				priority = 130,
			})
		end

		-- Add untracked
		for _, file in ipairs(status.untracked or {}) do
			table.insert(items, {
				text = file,
				kind = "Untracked",
				desc = "Untracked file",
				priority = 100,
			})
		end

		callback(items)
	end)
end

---Get help completions
---@param text string
---@param callback function
function M.get_help_completions(text, callback)
	local partial = text:match("%s+(.+)$") or ""

	local ok, helps = pcall(vim.fn.getcompletion, partial, "help")
	if ok and helps then
		local items = {}
		for _, h in ipairs(helps) do
			table.insert(items, {
				text = h,
				kind = "Help",
				priority = 100,
			})
		end
		callback(items)
	else
		callback({})
	end
end

---Get search completions
---@param callback function
function M.get_search_completions(callback)
	local text = State.text:lower()
	local items = {}

	-- Current word under cursor
	local word = vim.fn.expand("<cword>")
	if word and word ~= "" and word ~= State.text then
		table.insert(items, {
			text = word,
			kind = "Word",
			priority = 100,
		})
	end

	-- Search history
	local history = State:get_history()
	local max_history = math.min(#history, 8)
	for i = #history, math.max(1, #history - max_history + 1), -1 do
		local hist = history[i]
		if hist and hist ~= "" and hist ~= State.text then
			local hist_lower = hist:lower()
			if text == "" or hist_lower:find(text, 1, true) then
				table.insert(items, {
					text = hist,
					kind = "History",
					priority = 80,
				})
			end
		end
	end

	callback(items)
end

---Get general command completions
---@param callback function
function M.get_general_completions(callback)
	local items = {}
	local text = State.text

	-- FIX: Use prefix (last word) instead of full text for accurate completion
	local prefix = text:match("%S+$") or ""

	-- Use Tree-sitter to analyze structure
	local structure = TreeSitter.analyze_structure(text, State.mode)

	-- Get Vim command completions
	local ok, commands = pcall(vim.fn.getcompletion, prefix, "cmdline")
	if ok and commands then
		for _, cmd in ipairs(commands) do
			table.insert(items, {
				text = cmd,
				kind = "Command",
				priority = 100,
			})
		end
	end

	-- Add context-aware suggestions based on command
	if structure.command then
		local cmd_items = M.get_command_specific_completions(structure.command)
		for _, item in ipairs(cmd_items) do
			table.insert(items, item)
		end
	end

	callback(items)
end

---Get command-specific completions
---@param command string
---@return table[] items
function M.get_command_specific_completions(command)
	local items = {}

	-- Command-specific logic
	if command == "colorscheme" then
		local schemes = vim.fn.getcompletion("", "color")
		for _, scheme in ipairs(schemes) do
			table.insert(items, {
				text = scheme,
				kind = "Colorscheme",
				priority = 110,
			})
		end
	elseif command == "set" or command == "setlocal" then
		local options = vim.fn.getcompletion("", "option")
		for _, opt in ipairs(options) do
			table.insert(items, {
				text = opt,
				kind = "Option",
				priority = 110,
			})
		end
	elseif command == "highlight" or command == "hi" then
		local groups = vim.fn.getcompletion("", "highlight")
		for _, group in ipairs(groups) do
			table.insert(items, {
				text = group,
				kind = "Highlight",
				priority = 110,
			})
		end
	end

	return items
end

---Show enhanced picker with Telescope
function M.show_enhanced_picker()
	local text = State.text
	local intent = Context.infer_intent(text)

	if intent.type == "file_edit" then
		Telescope.show_file_picker(function(item)
			M.apply_completion(item.text)
		end)
	elseif intent.type == "buffer_switch" then
		Telescope.show_buffer_picker(function(item)
			M.apply_completion(item.text)
		end)
	elseif intent.type == "lsp_query" then
		Telescope.show_lsp_symbols(function(item)
			M.apply_completion(item.text)
		end)
	elseif intent.type == "help" then
		Telescope.show_help_tags(function(item)
			M.apply_completion(item.text)
		end)
	else
		-- Show general completions in Telescope
		M.get_smart_completions(function(items)
			if #items > 0 then
				Telescope.show_picker(items, { prompt_title = "Completions" }, function(item)
					M.apply_completion(item.text)
				end)
			end
		end)
	end
end

---Apply completion to command line
---@param text string
function M.apply_completion(text)
	if not State.active then
		return
	end

	-- Replace the last word or append
	local before_cursor = State.text:sub(1, State.cursor_pos - 1)
	local word_start = before_cursor:match("()%S+$") or State.cursor_pos

	State.text = State.text:sub(1, word_start - 1) .. text
	State.cursor_pos = #State.text + 1

	-- Update UI
	local UI = require("cmdline.ui")
	UI:render()
end

---Get completion with preview
---@param item table
---@return string|nil preview
function M.get_completion_preview(item)
	if Telescope.available then
		return Telescope.get_preview(item)
	end

	return nil
end

return M
