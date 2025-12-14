-- Telescope integration for enhanced fuzzy finding and previews
-- Falls back gracefully when Telescope is not available

local M = {}
local Context = require("cmdline.context")

-- Check if Telescope is available
local has_telescope, _ = pcall(require, "telescope")
local has_builtin, builtin = pcall(require, "telescope.builtin")
local _, actions = pcall(require, "telescope.actions")
local _, action_state = pcall(require, "telescope.actions.state")
local has_pickers, pickers = pcall(require, "telescope.pickers")
local has_finders, finders = pcall(require, "telescope.finders")
local has_conf, conf = pcall(require, "telescope.config")

M.available = has_telescope and has_builtin

---Setup Telescope integration
function M.setup()
	if not M.available then
		vim.notify("Telescope not available. Using fallback completion.", vim.log.levels.INFO)
	end
end

---Create custom Telescope picker for cmdline completions
---@param items table[]
---@param opts table
---@param on_select function
function M.show_picker(items, opts, on_select)
	if not M.available or not has_pickers or not has_finders or not has_conf then
		-- Fallback to simple selection
		M.fallback_picker(items, on_select)
		return
	end

	opts = opts or {}

	pickers
		.new(opts, {
			prompt_title = opts.prompt_title or "Completions",
			finder = finders.new_table({
				results = items,
				entry_maker = function(entry)
					return {
						value = entry,
						display = M.format_entry(entry),
						ordinal = entry.text or entry.name or "",
					}
				end,
			}),
			sorter = conf.values.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					if selection and on_select then
						on_select(selection.value)
					end
				end)
				return true
			end,
		})
		:find()
end

---Format entry for display in Telescope
---@param entry table
---@return string
function M.format_entry(entry)
	local parts = {}

	-- Add icon/kind indicator
	if entry.kind then
		table.insert(parts, string.format("[%s]", entry.kind))
	end

	-- Add main text/name
	table.insert(parts, entry.text or entry.name or entry.path or "")

	-- Add description
	if entry.desc then
		table.insert(parts, string.format("- %s", entry.desc))
	elseif entry.container then
		table.insert(parts, string.format("(%s)", entry.container))
	end

	return table.concat(parts, " ")
end

---Show file picker with preview
---@param callback function
function M.show_file_picker(callback)
	if not M.available then
		Context.get_project_files(function(files)
			M.fallback_picker(
				vim.tbl_map(function(f)
					return { text = f, path = f }
				end, files),
				callback
			)
		end)
		return
	end

	builtin.find_files({
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				actions.close(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				if selection and callback then
					callback({ text = selection[1], path = selection.path })
				end
			end)
			return true
		end,
	})
end

---Show buffer picker
---@param callback function
function M.show_buffer_picker(callback)
	if not M.available then
		local buffers = Context.get_buffers()
		M.fallback_picker(
			vim.tbl_map(function(b)
				return { text = b.name, bufnr = b.bufnr, path = b.path }
			end, buffers),
			callback
		)
		return
	end

	builtin.buffers({
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				actions.close(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				if selection and callback then
					callback({
						text = selection.filename,
						bufnr = selection.bufnr,
					})
				end
			end)
			return true
		end,
	})
end

---Show LSP symbols picker
---@param callback function
function M.show_lsp_symbols(callback)
	if not M.available then
		Context.get_lsp_symbols(function(symbols)
			M.fallback_picker(symbols, callback)
		end)
		return
	end

	builtin.lsp_document_symbols({
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				actions.close(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				if selection and callback then
					callback({
						text = selection.value,
						name = selection.value,
						kind = selection.symbol_type,
					})
				end
			end)
			return true
		end,
	})
end

---Show workspace symbols picker
---@param query string
---@param callback function
function M.show_workspace_symbols(query, callback)
	if not M.available then
		Context.get_workspace_symbols(query, function(symbols)
			M.fallback_picker(symbols, callback)
		end)
		return
	end

	builtin.lsp_workspace_symbols({
		query = query or "",
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				actions.close(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				if selection and callback then
					callback({
						text = selection.value,
						name = selection.value,
					})
				end
			end)
			return true
		end,
	})
end

---Show live grep picker
---@param callback function
function M.show_live_grep(callback)
	if not M.available then
		vim.notify("Live grep requires Telescope", vim.log.levels.WARN)
		return
	end

	builtin.live_grep({
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				actions.close(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				if selection and callback then
					callback({
						text = selection.value,
						path = selection.filename,
						lnum = selection.lnum,
					})
				end
			end)
			return true
		end,
	})
end

---Show git files picker
---@param callback function
function M.show_git_files(callback)
	if not M.available then
		-- Fallback to regular file picker
		M.show_file_picker(callback)
		return
	end

	builtin.git_files({
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				actions.close(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				if selection and callback then
					callback({
						text = selection[1],
						path = selection.path,
					})
				end
			end)
			return true
		end,
	})
end

---Show help tags picker
---@param callback function
function M.show_help_tags(callback)
	if not M.available then
		vim.notify("Help tags requires Telescope", vim.log.levels.WARN)
		return
	end

	builtin.help_tags({
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				actions.close(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				if selection and callback then
					callback({
						text = selection.value,
					})
				end
			end)
			return true
		end,
	})
end

---Fallback picker when Telescope is not available
---@param items table[]
---@param on_select function
function M.fallback_picker(items, on_select)
	if #items == 0 then
		vim.notify("No items to select", vim.log.levels.INFO)
		return
	end

	-- Use vim.ui.select as fallback
	local display_items = vim.tbl_map(function(item)
		return M.format_entry(item)
	end, items)

	vim.ui.select(display_items, {
		prompt = "Select:",
		format_item = function(item)
			return item
		end,
	}, function(choice, idx)
		if choice and idx and on_select then
			on_select(items[idx])
		end
	end)
end

---Enhanced search with Telescope fuzzy finding
---@param items table[]
---@param query string
---@return table[] filtered_items
function M.fuzzy_filter(items, query)
	if not M.available or not has_conf then
		-- Simple substring fallback
		return vim.tbl_filter(function(item)
			local text = (item.text or item.name or ""):lower()
			return text:find(query:lower(), 1, true) ~= nil
		end, items)
	end

	-- Use Telescope's sorter for fuzzy matching
	local sorter = conf.values.generic_sorter({})
	local results = {}

	for _, item in ipairs(items) do
		local score = sorter:score(query, item.text or item.name or "")
		if score > 0 then
			table.insert(results, {
				item = item,
				score = score,
			})
		end
	end

	-- Sort by score
	table.sort(results, function(a, b)
		return a.score > b.score
	end)

	return vim.tbl_map(function(r)
		return r.item
	end, results)
end

---Get enhanced preview for item using Telescope
---@param item table
---@return string|nil preview
function M.get_preview(item)
	if not item.path or not vim.fn.filereadable(item.path) then
		return nil
	end

	-- Read first few lines of file
	local lines = vim.fn.readfile(item.path, "", 20)
	return table.concat(lines, "\n")
end

return M
