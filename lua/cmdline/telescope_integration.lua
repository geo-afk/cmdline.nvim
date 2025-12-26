local M = {}
local Context = require("cmdline.context")
local Config = require("cmdline.config")

local has_telescope, telescope = pcall(require, "telescope")
local has_builtin, builtin = pcall(require, "telescope.builtin")
local has_actions, actions = pcall(require, "telescope.actions")
local has_action_state, action_state = pcall(require, "telescope.actions.state")
local has_pickers, pickers = pcall(require, "telescope.pickers")
local has_finders, finders = pcall(require, "telescope.finders")
local has_conf, conf = pcall(require, "telescope.config")
local has_previewers, previewers = pcall(require, "telescope.previewers")
local has_themes, themes = pcall(require, "telescope.themes")

M.available = has_telescope and has_builtin
M.config = nil

---Setup Telescope integration
function M.setup()
	if not M.available then
		vim.notify("Telescope not available. Using fallback completion.", vim.log.levels.INFO)
		return
	end

	-- Get cmdline config if available
	local ok, cmdline_config = pcall(require, "cmdline.config")
	if ok then
		M.config = cmdline_config.defaults
	end
end

---Get default telescope options with theme
---@param opts table?
---@return table
function M.get_default_opts(opts)
	opts = opts or {}

	local defaults = {
		prompt_title = opts.prompt_title or "Completions",
		results_title = opts.results_title or "Results",
		preview_title = opts.preview_title or "Preview",
		layout_strategy = "vertical",
		layout_config = {
			height = 0.95,
			width = 0.9,
			preview_height = 0.6,
			preview_cutoff = 40,
			prompt_position = "top",
		},
		sorting_strategy = "ascending",
		border = true,
		borderchars = {
			prompt = { "─", "│", " ", "│", "╭", "╮", "│", "│" },
			results = { "─", "│", "─", "│", "├", "┤", "╯", "╰" },
			preview = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
		},
	}

	return vim.tbl_deep_extend("force", defaults, opts)
end

---Format entry for display in Telescope with icons
---@param entry table
---@return string
function M.format_entry(entry)
	local icon = ""

	-- Get icon if we have kind
	if entry.kind then
		icon = Config.get_icon(entry.kind, M.config and M.config.ui.use_nerd_fonts)
	end

	local parts = {}

	-- Icon
	if icon ~= "" then
		table.insert(parts, icon)
	end

	-- Main text/name
	local main_text = entry.text or entry.name or entry.path or ""
	table.insert(parts, main_text)

	-- Kind badge (if not showing icon or in addition to icon)
	if entry.kind and (not M.config or M.config.completion.kind_format ~= "icon_only") then
		table.insert(parts, string.format("│ %s", entry.kind))
	end

	-- Description
	if entry.desc then
		table.insert(parts, string.format("│ %s", entry.desc))
	elseif entry.container then
		table.insert(parts, string.format("│ %s", entry.container))
	end

	-- Path (if different from main text)
	if entry.path and entry.path ~= main_text then
		table.insert(parts, string.format("│ %s", entry.path))
	end

	return table.concat(parts, " ")
end

---Create custom Telescope picker with preview
---@param items table[]
---@param opts table
---@param on_select function
function M.show_picker(items, opts, on_select)
	if not M.available or not has_pickers or not has_finders or not has_conf then
		M.fallback_picker(items, on_select)
		return
	end

	opts = M.get_default_opts(opts)

	-- Create previewer if items have previewable content
	local previewer = nil
	if has_previewers and M.config and M.config.completion.preview_enabled then
		previewer = previewers.new_buffer_previewer({
			title = opts.preview_title or "Preview",
			define_preview = function(self, entry)
				if not entry or not entry.value then
					return
				end

				local item = entry.value
				local preview_lines = M.get_preview_content(item)

				if preview_lines and #preview_lines > 0 then
					vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, preview_lines)

					-- Set filetype for syntax highlighting if possible
					if item.path then
						local ft = vim.filetype.match({ filename = item.path })
						if ft then
							vim.bo[self.state.bufnr].filetype = ft
						end
					end
				end
			end,
		})
	end

	pickers
		.new(opts, {
			prompt_title = opts.prompt_title,
			results_title = opts.results_title,
			finder = finders.new_table({
				results = items,
				entry_maker = function(entry)
					return {
						value = entry,
						display = M.format_entry(entry),
						ordinal = entry.text or entry.name or entry.path or "",
						path = entry.path, -- For preview
					}
				end,
			}),
			sorter = conf.values.generic_sorter(opts),
			previewer = previewer,
			attach_mappings = function(prompt_bufnr, map)
				-- Custom mappings
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if selection and on_select then
						vim.schedule(function()
							on_select(selection.value)
						end)
					end
				end)

				-- Additional convenient mappings
				if M.config and M.config.telescope.mappings then
					for mode, mode_mappings in pairs(M.config.telescope.mappings) do
						for key, action_name in pairs(mode_mappings) do
							if actions[action_name] then
								map(mode, key, actions[action_name])
							end
						end
					end
				end

				return true
			end,
		})
		:find()
end

---Get preview content for an item
---@param item table
---@return string[]?
function M.get_preview_content(item)
	-- File preview
	if item.path and vim.fn.filereadable(item.path) == 1 then
		local max_lines = (M.config and M.config.completion.preview_max_lines) or 100
		local lines = vim.fn.readfile(item.path, "", max_lines)
		return lines
	end

	-- Buffer preview
	if item.bufnr and vim.api.nvim_buf_is_valid(item.bufnr) then
		local max_lines = (M.config and M.config.completion.preview_max_lines) or 100
		local lines = vim.api.nvim_buf_get_lines(item.bufnr, 0, max_lines, false)
		return lines
	end

	-- LSP symbol preview
	if item.location then
		-- Try to extract preview from location
		local location = item.location
		if location.uri or location.targetUri then
			local uri = location.uri or location.targetUri
			local path = vim.uri_to_fname(uri)

			if vim.fn.filereadable(path) == 1 then
				local range = location.range or location.targetRange
				if range then
					local start_line = range.start.line
					local end_line = math.min(range["end"].line + 10, start_line + 50)
					local lines = vim.fn.readfile(path, "", end_line + 1)
					return vim.list_slice(lines, start_line + 1, end_line + 1)
				end
			end
		end
	end

	-- Description as preview
	if item.desc then
		return vim.split(item.desc, "\n")
	end

	return nil
end

---Show file picker with enhanced preview
---@param callback function
function M.show_file_picker(callback)
	if not M.available then
		Context.get_project_files(function(files)
			M.fallback_picker(
				vim.tbl_map(function(f)
					return { text = f, path = f, kind = "File" }
				end, files),
				callback
			)
		end)
		return
	end

	local opts = M.get_default_opts({
		prompt_title = "Find Files",
		preview = true,
	})

	builtin.find_files(vim.tbl_extend("force", opts, {
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				if selection and callback then
					vim.schedule(function()
						callback({ text = selection[1], path = selection.path })
					end)
				end
			end)
			return true
		end,
	}))
end

---Show buffer picker with enhanced display
---@param callback function
function M.show_buffer_picker(callback)
	if not M.available then
		local buffers = Context.get_buffers()
		M.fallback_picker(
			vim.tbl_map(function(b)
				return { text = b.name, bufnr = b.bufnr, path = b.path, kind = "Buffer" }
			end, buffers),
			callback
		)
		return
	end

	local opts = M.get_default_opts({
		prompt_title = "Buffers",
		preview = true,
	})

	builtin.buffers(vim.tbl_extend("force", opts, {
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				if selection and callback then
					vim.schedule(function()
						callback({
							text = selection.filename,
							bufnr = selection.bufnr,
						})
					end)
				end
			end)
			return true
		end,
	}))
end

---Show LSP document symbols picker
---@param callback function
function M.show_lsp_symbols(callback)
	if not M.available then
		Context.get_lsp_symbols(function(symbols)
			M.fallback_picker(symbols, callback)
		end)
		return
	end

	local opts = M.get_default_opts({
		prompt_title = "Document Symbols",
		preview = true,
	})

	builtin.lsp_document_symbols(vim.tbl_extend("force", opts, {
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				if selection and callback then
					vim.schedule(function()
						callback({
							text = selection.value,
							name = selection.value,
							kind = selection.symbol_type,
						})
					end)
				end
			end)
			return true
		end,
	}))
end

---Show workspace symbols picker
---@param query string?
---@param callback function
function M.show_workspace_symbols(query, callback)
	if not M.available then
		Context.get_workspace_symbols(query, function(symbols)
			M.fallback_picker(symbols, callback)
		end)
		return
	end

	local opts = M.get_default_opts({
		prompt_title = "Workspace Symbols",
		preview = true,
	})

	builtin.lsp_workspace_symbols(vim.tbl_extend("force", opts, {
		query = query or "",
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				if selection and callback then
					vim.schedule(function()
						callback({
							text = selection.value,
							name = selection.value,
						})
					end)
				end
			end)
			return true
		end,
	}))
end

---Show live grep picker
---@param callback function
function M.show_live_grep(callback)
	if not M.available then
		vim.notify("Live grep requires Telescope", vim.log.levels.WARN)
		return
	end

	local opts = M.get_default_opts({
		prompt_title = "Live Grep",
		preview = true,
	})

	builtin.live_grep(vim.tbl_extend("force", opts, {
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				if selection and callback then
					vim.schedule(function()
						callback({
							text = selection.value,
							path = selection.filename,
							lnum = selection.lnum,
						})
					end)
				end
			end)
			return true
		end,
	}))
end

---Show git files picker
---@param callback function
function M.show_git_files(callback)
	if not M.available then
		M.show_file_picker(callback)
		return
	end

	local opts = M.get_default_opts({
		prompt_title = "Git Files",
		preview = true,
	})

	builtin.git_files(vim.tbl_extend("force", opts, {
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				if selection and callback then
					vim.schedule(function()
						callback({
							text = selection[1],
							path = selection.path,
						})
					end)
				end
			end)
			return true
		end,
	}))
end

---Show help tags picker
---@param callback function
function M.show_help_tags(callback)
	if not M.available then
		vim.notify("Help tags requires Telescope", vim.log.levels.WARN)
		return
	end

	local opts = M.get_default_opts({
		prompt_title = "Help Tags",
		preview = true,
	})

	builtin.help_tags(vim.tbl_extend("force", opts, {
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				if selection and callback then
					vim.schedule(function()
						callback({
							text = selection.value,
						})
					end)
				end
			end)
			return true
		end,
	}))
end

---Fallback picker when Telescope is not available
---@param items table[]
---@param on_select function
function M.fallback_picker(items, on_select)
	if #items == 0 then
		vim.notify("No items to select", vim.log.levels.INFO)
		return
	end

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
			vim.schedule(function()
				on_select(items[idx])
			end)
		end
	end)
end

---Enhanced fuzzy filtering using Telescope's sorter
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

	local sorter = conf.values.generic_sorter({})
	local results = {}

	for _, item in ipairs(items) do
		local score = sorter:score(item.text or item.name or "", query)
		if score > 0 then
			table.insert(results, {
				item = item,
				score = score,
			})
		end
	end

	table.sort(results, function(a, b)
		return a.score < b.score -- Lower score is better in Telescope
	end)

	return vim.tbl_map(function(r)
		return r.item
	end, results)
end

return M
