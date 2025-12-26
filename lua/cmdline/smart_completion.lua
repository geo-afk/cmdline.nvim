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

	-- Early return for empty text
	if text == "" then
		M.get_general_completions(callback)
		return
	end

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

---Get file completions with async support
---@param text string
---@param callback function
function M.get_file_completions(text, callback)
	-- Extract partial path from command
	local partial = text:match("%s+(.+)$") or ""

	Context.get_project_files(function(files)
		if not files or #files == 0 then
			callback({})
			return
		end

		local items = {}
		local count = 0
		local max_items = 100 -- Limit for performance

		for _, file in ipairs(files) do
			if count >= max_items then
				break
			end

			-- Filter based on partial match
			if partial == "" or vim.startswith(file, partial) or file:find(partial, 1, true) then
				-- Calculate relevance score
				local score = 100
				if vim.startswith(file, partial) then
					score = score + 50
				end

				-- Prefer files in current directory
				if not file:find("/") then
					score = score + 30
				end

				table.insert(items, {
					text = file,
					kind = "File",
					path = file,
					priority = score,
					desc = vim.fn.fnamemodify(file, ":h"),
				})
				count = count + 1
			end
		end

		callback(items)
	end)
end

---Get buffer completions with enhanced info
---@param callback function
function M.get_buffer_completions(callback)
	local buffers = Context.get_buffers()
	if not buffers or #buffers == 0 then
		callback({})
		return
	end

	local items = {}

	for _, buf in ipairs(buffers) do
		-- Calculate priority
		local priority = 100
		if buf.current then
			priority = priority + 50
		end
		if buf.modified then
			priority = priority + 30
		end

		-- Build description
		local desc = buf.path
		if buf.modified then
			desc = desc .. " [+]"
		end
		if buf.current then
			desc = desc .. " [current]"
		end

		table.insert(items, {
			text = buf.name,
			kind = "Buffer",
			desc = desc,
			bufnr = buf.bufnr,
			priority = priority,
			path = buf.full,
		})
	end

	callback(items)
end

---Get LSP completions with better error handling
---@param callback function
function M.get_lsp_completions(callback)
	-- Check if LSP is available
	local clients = Context.get_lsp_clients()
	if not clients or #clients == 0 then
		callback({})
		return
	end

	-- Get document symbols with timeout
	local timeout_timer = vim.uv.new_timer()
	local completed = false

	-- Set timeout (2 seconds)
	timeout_timer:start(2000, 0, function()
		if not completed then
			completed = true
			timeout_timer:close()
			vim.schedule(function()
				callback({})
			end)
		end
	end)

	Context.get_lsp_symbols(function(symbols)
		if completed then
			return
		end
		completed = true
		timeout_timer:close()

		if not symbols or #symbols == 0 then
			callback({})
			return
		end

		local items = {}

		for _, symbol in ipairs(symbols) do
			-- Build display text
			local display_text = symbol.name
			if symbol.prefix and symbol.prefix ~= "" then
				display_text = symbol.prefix .. display_text
			end

			table.insert(items, {
				text = symbol.name,
				kind = symbol.kind,
				desc = symbol.prefix ~= "" and symbol.prefix or nil,
				location = symbol.location,
				priority = 110,
			})
		end

		callback(items)
	end)
end

---Get git completions with status info
---@param callback function
function M.get_git_completions(callback)
	Context.get_git_status(function(status)
		if not status then
			callback({})
			return
		end

		local items = {}

		-- Priority order: modified > added > deleted > untracked
		local categories = {
			{ list = status.modified or {}, kind = "Modified", icon = "M", priority = 140 },
			{ list = status.added or {}, kind = "Added", icon = "A", priority = 130 },
			{ list = status.deleted or {}, kind = "Deleted", icon = "D", priority = 120 },
			{ list = status.untracked or {}, kind = "Untracked", icon = "?", priority = 110 },
		}

		for _, cat in ipairs(categories) do
			for _, file in ipairs(cat.list) do
				table.insert(items, {
					text = file,
					kind = cat.kind,
					desc = string.format("[%s] %s", cat.icon, cat.kind),
					priority = cat.priority,
					path = file,
				})
			end
		end

		callback(items)
	end)
end

---Get help completions with better filtering
---@param text string
---@param callback function
function M.get_help_completions(text, callback)
	local partial = text:match("%s+(.+)$") or ""

	-- Don't query if partial is too short (performance)
	if #partial < 2 then
		callback({})
		return
	end

	local ok, helps = pcall(vim.fn.getcompletion, partial, "help")
	if not ok or not helps then
		callback({})
		return
	end

	local items = {}
	local max_items = 50

	for i, h in ipairs(helps) do
		if i > max_items then
			break
		end

		-- Try to categorize help topics
		local category = "Help"
		if h:match("^'.*'$") then
			category = "Option"
		elseif h:match("^:") then
			category = "Command"
		elseif h:match("^v:") then
			category = "Variable"
		end

		table.insert(items, {
			text = h,
			kind = category,
			priority = 100,
		})
	end

	callback(items)
end

---Get search completions with buffer context
---@param callback function
function M.get_search_completions(callback)
	local items = {}
	local text = State.text:lower()

	-- Current word under cursor
	local ok, word = pcall(vim.fn.expand, "<cword>")
	if ok and word and word ~= "" and word ~= State.text then
		table.insert(items, {
			text = word,
			kind = "Word",
			desc = "Word under cursor",
			priority = 150,
		})
	end

	-- Get unique words from buffer
	if State.original_buf and vim.api.nvim_buf_is_valid(State.original_buf) then
		local buf_ok, buf_lines = pcall(vim.api.nvim_buf_get_lines, State.original_buf, 0, -1, false)
		if buf_ok then
			local words_seen = { [word] = true, [State.text] = true }
			local buf_text = table.concat(buf_lines, " ")

			-- Extract words
			local count = 0
			for buf_word in buf_text:gmatch("%w+") do
				if count >= 30 then
					break
				end

				if #buf_word > 2 and not words_seen[buf_word] then
					if text == "" or buf_word:lower():find(text, 1, true) then
						table.insert(items, {
							text = buf_word,
							kind = "Word",
							desc = "From buffer",
							priority = 100,
						})
						words_seen[buf_word] = true
						count = count + 1
					end
				end
			end
		end
	end

	-- Search history
	local history = State:get_history()
	local max_history = 10
	local history_seen = {}

	for i = 1, math.min(#history, max_history * 2) do
		local hist = history[i]
		if hist and hist ~= "" and hist ~= State.text and not history_seen[hist] then
			if text == "" or hist:lower():find(text, 1, true) then
				table.insert(items, {
					text = hist,
					kind = "History",
					desc = "Search history",
					priority = 90,
				})
				history_seen[hist] = true

				if #items >= max_history + 30 then
					break
				end
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

	-- Get prefix (last word)
	local prefix = text:match("%S+$") or text

	-- Use Tree-sitter to analyze structure
	local structure = TreeSitter.analyze_structure(text, State.mode)

	-- Get Vim command completions
	if prefix ~= "" then
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

	-- Command-specific completion logic
	local completers = {
		colorscheme = { type = "color", priority = 120 },
		set = { type = "option", priority = 120 },
		setlocal = { type = "option", priority = 120 },
		highlight = { type = "highlight", priority = 120 },
		hi = { type = "highlight", priority = 120 },
		help = { type = "help", priority = 120 },
	}

	local completer = completers[command]
	if not completer then
		return items
	end

	local ok, results = pcall(vim.fn.getcompletion, "", completer.type)
	if ok and results then
		-- Limit results for performance
		local max_results = 100
		for i, result in ipairs(results) do
			if i > max_results then
				break
			end

			table.insert(items, {
				text = result,
				kind = completer.type:sub(1, 1):upper() .. completer.type:sub(2),
				priority = completer.priority,
			})
		end
	end

	return items
end

---Show enhanced picker with Telescope
function M.show_enhanced_picker()
	local text = State.text
	local intent = Context.infer_intent(text)

	-- Choose appropriate picker based on intent
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
			else
				vim.notify("No completions available", vim.log.levels.INFO)
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

	-- Trigger new completions
	local Completion = require("cmdline.completion")
	Completion:trigger()
end

return M
