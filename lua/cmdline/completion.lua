local M = {}
local State = require("cmdline.state")
local UI = require("cmdline.ui")
local config
local timer = nil
local debounce_timer = nil

-- Lazy-load smart completion modules
local SmartCompletion

-- Cache for performance
local completion_cache = {}
local last_completion_text = ""

---Setup completion module
---@param cfg table
function M.setup(cfg)
	config = cfg

	-- Try to load smart completion
	if config.completion.smart_enabled then
		local ok, smart = pcall(require, "cmdline.smart_completion")
		if ok then
			SmartCompletion = smart
			SmartCompletion.setup()
		else
			vim.schedule(function()
				vim.notify("Smart completion not available. Using basic completion.", vim.log.levels.INFO)
			end)
			config.completion.smart_enabled = false
		end
	end
end

---Debounced completion trigger
function M:trigger()
	if not config.completion.enabled or not config.completion.auto_trigger then
		return
	end

	-- Cancel existing timer
	M:cancel_timer()

	-- Create new debounced timer
	debounce_timer = vim.uv.new_timer()
	if not debounce_timer then
		return
	end

	debounce_timer:start(
		config.completion.trigger_delay or 80,
		0,
		vim.schedule_wrap(function()
			M:cancel_timer()
			if State.active then
				M:get_completions()
			end
		end)
	)
end

---Cancel pending timers
function M:cancel_timer()
	if debounce_timer then
		if not debounce_timer:is_closing() then
			debounce_timer:stop()
			debounce_timer:close()
		end
		debounce_timer = nil
	end

	if timer then
		if not timer:is_closing() then
			timer:stop()
			timer:close()
		end
		timer = nil
	end
end

---Trigger completion immediately
function M:trigger_immediate()
	if not config.completion.enabled then
		return
	end

	M:cancel_timer()
	M:get_completions()
end

---Clear completions and cache
function M:clear()
	State:set_completions({})
	completion_cache = {}
	last_completion_text = ""

	if not State.render_scheduled then
		State.render_scheduled = true
		vim.schedule(function()
			State.render_scheduled = false

			if not State.render_scheduled then
				State.render_scheduled = true
				vim.schedule(function()
					State.render_scheduled = false
					UI:render()
				end)
			end
		end)
	end
end

---Get completions based on current state
function M:get_completions()
	-- Check if text changed significantly
	local current_text = State.text
	if current_text == last_completion_text then
		return -- No need to recompute
	end

	-- Check cache first (for performance)
	local cache_key = string.format("%s:%s", State.mode, current_text)
	if completion_cache[cache_key] then
		local cached_items = completion_cache[cache_key]
		M:finalize_completions(cached_items)
		last_completion_text = current_text
		return
	end

	-- PRIORITY: Try smart completion first
	if config.completion.smart_enabled and SmartCompletion then
		SmartCompletion.get_smart_completions(function(items)
			if items and #items > 0 then
				-- Cache smart results
				completion_cache[cache_key] = items
				M:finalize_completions(items)
			else
				-- Fallback to basic completion
				local basic_items = M:get_basic_completions()
				completion_cache[cache_key] = basic_items
				M:finalize_completions(basic_items)
			end
			last_completion_text = current_text
		end)
	else
		-- Use basic completion
		local items = M:get_basic_completions()
		completion_cache[cache_key] = items
		M:finalize_completions(items)
		last_completion_text = current_text
	end
end

---Get basic completions (fallback)
---@return table[] items
function M:get_basic_completions()
	local items = {}

	if State.mode == ":" then
		items = M:get_cmdline_completions()
	elseif State.mode == "/" or State.mode == "?" then
		items = M:get_search_completions()
	elseif State.mode == "=" then
		items = M:get_lua_completions()
	end

	return items
end

---Get command line completions
---@return table[] items
function M:get_cmdline_completions()
	local items = {}
	local text = State.text

	-- Get the word we're completing (last word or full text)
	local prefix = text:match("%S+$") or text

	-- Don't complete empty strings (too many results)
	if prefix == "" then
		return M:get_history_completions()
	end

	-- Built-in command completion
	local ok, commands = pcall(vim.fn.getcompletion, prefix, "cmdline")
	if ok and commands then
		for _, cmd in ipairs(commands) do
			table.insert(items, {
				text = cmd,
				kind = "Command",
				priority = 100,
				source = "cmdline",
			})
		end
	end

	-- Add history if we don't have too many command matches
	if #items < 20 then
		local history_items = M:get_history_completions()
		for _, item in ipairs(history_items) do
			table.insert(items, item)
		end
	end

	return items
end

---Get search completions
---@return table[] items
function M:get_search_completions()
	local items = {}
	local text = State.text

	-- Current word under cursor (if different from search text)
	local ok, word = pcall(vim.fn.expand, "<cword>")
	if ok and word and word ~= "" and word ~= text then
		table.insert(items, {
			text = word,
			kind = "Word",
			desc = "Word under cursor",
			priority = 150,
			source = "buffer",
		})
	end

	-- Get words from current buffer (unique)
	local seen = { [word] = true, [text] = true }
	local buf_lines = vim.api.nvim_buf_get_lines(State.original_buf or 0, 0, -1, false)
	local buf_text = table.concat(buf_lines, " ")

	-- Extract words (limit to avoid performance issues)
	local count = 0
	for buf_word in buf_text:gmatch("%w+") do
		if count >= 50 then
			break
		end
		if #buf_word > 2 and not seen[buf_word] then
			if text == "" or buf_word:lower():find(text:lower(), 1, true) then
				table.insert(items, {
					text = buf_word,
					kind = "Word",
					desc = "From buffer",
					priority = 100,
					source = "buffer",
				})
				seen[buf_word] = true
				count = count + 1
			end
		end
	end

	-- Add search history
	local history_items = M:get_history_completions()
	for _, item in ipairs(history_items) do
		if not seen[item.text] then
			table.insert(items, item)
		end
	end

	return items
end

---Get Lua expression completions
---@return table[] items
function M:get_lua_completions()
	local items = {}
	local text = State.text:gsub("^=", "")

	-- Get prefix for completion
	local prefix = text:match("[%w_%.]+$") or ""

	if prefix ~= "" then
		-- Try to get Lua completions
		local ok, completions = pcall(vim.fn.getcompletion, prefix, "lua")
		if ok and completions then
			for _, comp in ipairs(completions) do
				table.insert(items, {
					text = comp,
					kind = "Function",
					priority = 100,
					source = "lua",
				})
			end
		end
	end

	return items
end

---Get history completions
---@return table[] items
function M:get_history_completions()
	local items = {}
	local text = State.text:lower()
	local history = State:get_history()

	-- Limit history to most recent and relevant
	local max_history = 10
	local seen = {}

	for i = 1, math.min(#history, max_history * 2) do
		local hist = history[i]
		if hist and hist ~= "" and hist ~= State.text and not seen[hist] then
			-- Check if it matches our search
			if text == "" or hist:lower():find(text, 1, true) then
				table.insert(items, {
					text = hist,
					kind = "History",
					desc = "From history",
					priority = 80,
					source = "history",
				})
				seen[hist] = true

				if #items >= max_history then
					break
				end
			end
		end
	end

	return items
end

---Finalize and display completions
---@param items table[]
function M:finalize_completions(items)
	if not items or #items == 0 then
		State:set_completions({})

		if not State.render_scheduled then
			State.render_scheduled = true
			vim.schedule(function()
				State.render_scheduled = false
				UI:render()
			end)
		end
		return
	end

	-- Score and sort items
	M:score_items(items)
	table.sort(items, function(a, b)
		local score_a = a.score or 0
		local score_b = b.score or 0

		-- Sort by score first
		if score_a ~= score_b then
			return score_a > score_b
		end

		-- Then by priority
		local prio_a = a.priority or 0
		local prio_b = b.priority or 0
		if prio_a ~= prio_b then
			return prio_a > prio_b
		end

		-- Finally alphabetically
		return (a.text or "") < (b.text or "")
	end)

	-- Remove duplicates
	local seen = {}
	local unique_items = {}
	for _, item in ipairs(items) do
		local key = item.text .. (item.kind or "")
		if not seen[key] then
			table.insert(unique_items, item)
			seen[key] = true
		end
	end

	-- Limit results
	local max_items = config.completion.max_items or 50
	if #unique_items > max_items then
		unique_items = vim.list_slice(unique_items, 1, max_items)
	end

	-- Update state and render
	State:set_completions(unique_items)

	-- Defer render to avoid blocking
	vim.schedule(function()
		if State.active then
			if not State.render_scheduled then
				State.render_scheduled = true
				vim.schedule(function()
					State.render_scheduled = false
					UI:render()
				end)
			end
		end
	end)
end

---Score completion items based on query
---@param items table[]
function M:score_items(items)
	local query = State.text:lower()
	local query_len = #query

	for _, item in ipairs(items) do
		local score = item.priority or 0
		local text = (item.text or ""):lower()
		local text_len = #text

		if query == "" then
			-- Keep base priority for empty query
			item.score = score
		elseif text == query then
			-- Exact match - highest score
			item.score = score + 500
		elseif vim.startswith(text, query) then
			-- Prefix match - prefer shorter completions
			local length_penalty = text_len - query_len
			item.score = score + 300 - length_penalty
		elseif text:find(query, 1, true) then
			-- Substring match - consider position
			local pos = text:find(query, 1, true)
			item.score = score + 200 - pos
		elseif config.completion.fuzzy then
			-- Fuzzy match
			local fuzzy_score = M:fuzzy_score(query, text)
			if fuzzy_score > 0 then
				item.score = score + 100 + fuzzy_score
			else
				item.score = score
			end
		else
			item.score = score
		end
	end
end

---Calculate fuzzy match score
---@param query string
---@param text string
---@return number score
function M:fuzzy_score(query, text)
	if query == "" then
		return 0
	end

	local score = 0
	local last_idx = 0
	local consecutive = 0

	for i = 1, #query do
		local char = query:sub(i, i)
		local idx = text:find(char, last_idx + 1, true)

		if not idx then
			return 0
		end

		-- Reward consecutive matches
		if idx == last_idx + 1 then
			consecutive = consecutive + 1
			score = score + consecutive * 10
		else
			consecutive = 0
		end

		-- Reward matches early in the string
		score = score + (100 - idx)
		last_idx = idx
	end

	-- Normalize by length
	return score / math.max(#query, 1)
end

---Show Telescope picker for enhanced selection
function M:show_telescope_picker()
	if not SmartCompletion then
		vim.notify("Smart completion not enabled", vim.log.levels.WARN)
		return
	end

	-- Use smart completion's enhanced picker
	local ok, err = pcall(SmartCompletion.show_enhanced_picker)
	if not ok then
		vim.notify("Telescope picker error: " .. tostring(err), vim.log.levels.ERROR)
	end
end

---Cleanup completion resources
function M:cleanup()
	M:cancel_timer()
	completion_cache = {}
	last_completion_text = ""
end

---Clear cache (useful after mode change or major text change)
function M:clear_cache()
	completion_cache = {}
	last_completion_text = ""
end

return M
