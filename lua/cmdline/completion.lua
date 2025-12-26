local M = {}
local State = require("cmdline.state")
local UI = require("cmdline.ui")
local config
local timer = nil

-- Lazy-load smart completion modules
local SmartCompletion

---Setup completion module
---@param cfg table
function M.setup(cfg)
	config = cfg

	-- Always try to load smart completion first
	if config.completion.smart_enabled then
		local ok, smart = pcall(require, "cmdline.smart_completion")
		if ok then
			SmartCompletion = smart
			SmartCompletion.setup()
		else
			vim.notify("Smart completion modules not found. Using basic completion.", vim.log.levels.WARN)
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
	if timer then
		timer:stop()
		timer:close()
		timer = nil
	end

	-- Create new timer
	timer = vim.uv.new_timer()
	if not timer then
		return
	end

	timer:start(
		config.completion.trigger_delay,
		0,
		vim.schedule_wrap(function()
			if timer then
				timer:stop()
				timer:close()
				timer = nil
			end

			if State.active then
				self:get_completions()
			end
		end)
	)
end

---Trigger completion immediately
function M:trigger_immediate()
	if not config.completion.enabled then
		return
	end

	self:get_completions()
end

---Clear completions
function M:clear()
	State:set_completions({})
	UI:render()
end

---Get completions based on current state - PRIORITIZE SMART COMPLETION
function M:get_completions()
	-- PRIORITY: Try smart completion first if enabled
	if config.completion.smart_enabled and SmartCompletion then
		SmartCompletion.get_smart_completions(function(items)
			-- If smart completion returns results, use them
			if items and #items > 0 then
				self:finalize_completions(items)
			else
				-- Fall back to basic completion only if smart returns nothing
				local basic_items = self:get_basic_completions()
				self:finalize_completions(basic_items)
			end
		end)
	else
		-- Fall back to basic completion if smart is disabled
		local items = self:get_basic_completions()
		self:finalize_completions(items)
	end
end

---Get basic completions (fallback implementation)
---@return table[] items
function M:get_basic_completions()
	local items = {}

	if State.mode == ":" then
		items = self:get_cmdline_completions()
	elseif State.mode == "/" or State.mode == "?" then
		items = self:get_search_completions()
	end

	return items
end

---Finalize and display completions
---@param items table[]
function M:finalize_completions(items)
	if not items then
		items = {}
	end

	-- Score and sort items
	self:score_items(items)
	table.sort(items, function(a, b)
		return (a.score or 0) > (b.score or 0)
	end)

	-- Limit results
	if #items > config.completion.max_items then
		items = vim.list_slice(items, 1, config.completion.max_items)
	end

	State:set_completions(items)
	UI:render()
end

---Get command line completions
---@return table[] items
function M:get_cmdline_completions()
	local items = {}
	local text = State.text
	local prefix = text:match("%S+$") or ""

	-- Built-in command completion
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

	-- History (limit to 5)
	local history = State:get_history()
	local max_history = math.min(#history, 5)
	for i = 1, max_history do
		local hist = history[i]
		if hist and hist ~= "" and hist ~= text then
			-- Check if not duplicate
			local is_dup = false
			for _, item in ipairs(items) do
				if item.text == hist then
					is_dup = true
					break
				end
			end

			if not is_dup then
				table.insert(items, {
					text = hist,
					kind = "History",
					priority = 80,
				})
			end
		end
	end

	return items
end

---Get search completions
---@return table[] items
function M:get_search_completions()
	local items = {}
	local text = State.text:lower()

	-- Current word under cursor (if different)
	local word = vim.fn.expand("<cword>")
	if word and word ~= "" and word ~= State.text then
		table.insert(items, {
			text = word,
			kind = "Word",
			desc = "Word under cursor",
			priority = 100,
		})
	end

	-- Search history (only if text is empty or matches)
	local history = State:get_history()
	local max_history = math.min(#history, 8)
	for i = 1, max_history do
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

	return items
end

---Score completion items based on query
---@param items table[]
function M:score_items(items)
	local query = State.text:lower()

	-- Pre-limit to avoid scoring too many items
	if #items > 500 then
		items = vim.list_slice(items, 1, 500)
	end

	for _, item in ipairs(items) do
		local score = item.priority or 0
		local text = item.text:lower()

		if query == "" then
			-- Keep priority score
		elseif text == query then
			-- Exact match
			score = score + 300
		elseif vim.startswith(text, query) then
			-- Prefix match (prefer shorter matches)
			score = score + 200 - (#text - #query)
		elseif text:find(query, 1, true) then
			-- Contains match
			score = score + 100
		elseif config.completion.fuzzy then
			-- Fuzzy match
			local fuzzy_score = self:fuzzy_score(query, text)
			if fuzzy_score > 0 then
				score = score + 50 + fuzzy_score
			end
		end

		item.score = score
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

	for i = 1, #query do
		local char = query:sub(i, i)
		local idx = text:find(char, last_idx + 1, true)

		if not idx then
			return 0
		end

		-- Reward matches early in the string
		score = score + (100 - idx)
		last_idx = idx
	end

	-- Normalize by query length
	return score / #query
end

---Show Telescope picker for completions
function M:show_telescope_picker()
	if not SmartCompletion then
		vim.notify("Smart completion not enabled", vim.log.levels.WARN)
		return
	end

	SmartCompletion.show_enhanced_picker()
end

---Cleanup completion resources
function M:cleanup()
	if timer then
		timer:stop()
		timer:close()
		timer = nil
	end
end

return M
