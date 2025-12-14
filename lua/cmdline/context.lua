-- Context provider module for intelligent cmdline suggestions
-- Queries LSP, project state, and environment for context-aware completions

local M = {}

-- Cache for expensive operations
local cache = {
	lsp_clients = nil,
	lsp_symbols = {},
	buffers = nil,
	git_status = nil,
	cache_time = {},
}

local CACHE_TTL = 2000 -- 2 seconds in milliseconds

---Check if cache is valid
---@param key string
---@return boolean
local function is_cache_valid(key)
	local now = vim.uv.now()
	local cached_time = cache.cache_time[key]
	return cached_time and (now - cached_time) < CACHE_TTL
end

---Update cache timestamp
---@param key string
local function update_cache_time(key)
	cache.cache_time[key] = vim.uv.now()
end

---Setup context provider
function M.setup()
	-- Clear cache on buffer changes
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
		group = vim.api.nvim_create_augroup("CmdlineContext", { clear = true }),
		callback = function()
			cache = {
				lsp_clients = nil,
				lsp_symbols = {},
				buffers = nil,
				git_status = nil,
				cache_time = {},
			}
		end,
	})
end

---Get active LSP clients with caching
---@return table[] clients
function M.get_lsp_clients()
	if is_cache_valid("lsp_clients") and cache.lsp_clients then
		return cache.lsp_clients
	end

	local clients = {}
	local buf = vim.api.nvim_get_current_buf()

	-- Use vim.lsp.get_clients (Neovim 0.10+) or fallback
	local ok, buf_clients = pcall(vim.lsp.get_clients, { bufnr = buf })
	if not ok then
		-- Fallback for older Neovim versions
		ok, buf_clients = pcall(vim.lsp.buf_get_clients, buf)
	end

	if ok and buf_clients then
		for _, client in pairs(buf_clients) do
			if client.name then
				table.insert(clients, {
					name = client.name,
					id = client.id,
					capabilities = client.server_capabilities or {},
				})
			end
		end
	end

	cache.lsp_clients = clients
	update_cache_time("lsp_clients")
	return clients
end

---Query LSP for document symbols asynchronously
---@param callback function
function M.get_lsp_symbols(callback)
	if is_cache_valid("lsp_symbols") and #cache.lsp_symbols > 0 then
		callback(cache.lsp_symbols)
		return
	end

	local buf = vim.api.nvim_get_current_buf()
	local params = { textDocument = vim.lsp.util.make_text_document_params() }

	vim.lsp.buf_request(buf, "textDocument/documentSymbol", params, function(err, result)
		if err or not result then
			callback({})
			return
		end

		local symbols = {}
		local function extract_symbols(items, prefix)
			prefix = prefix or ""
			for _, item in ipairs(items or {}) do
				local symbol = item.name or item.text
				if symbol then
					table.insert(symbols, {
						name = symbol,
						kind = vim.lsp.protocol.SymbolKind[item.kind] or "Unknown",
						location = item.location or item.range,
						prefix = prefix,
					})

					-- Recursively extract children
					if item.children then
						extract_symbols(item.children, prefix .. symbol .. ".")
					end
				end
			end
		end

		extract_symbols(result)
		cache.lsp_symbols = symbols
		update_cache_time("lsp_symbols")
		callback(symbols)
	end)
end

---Get workspace symbols via LSP
---@param query string
---@param callback function
function M.get_workspace_symbols(query, callback)
	local params = { query = query or "" }

	vim.lsp.buf_request(0, "workspace/symbol", params, function(err, result)
		if err or not result then
			callback({})
			return
		end

		local symbols = {}
		for _, item in ipairs(result) do
			table.insert(symbols, {
				name = item.name,
				kind = vim.lsp.protocol.SymbolKind[item.kind] or "Unknown",
				location = item.location,
				container = item.containerName,
			})
		end

		callback(symbols)
	end)
end

---Get available buffers with metadata
---@return table[] buffers
function M.get_buffers()
	if is_cache_valid("buffers") and cache.buffers then
		return cache.buffers
	end

	local buffers = {}
	local current_buf = vim.api.nvim_get_current_buf()

	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			local name = vim.api.nvim_buf_get_name(buf)
			local buftype = vim.bo[buf].buftype
			local modified = vim.bo[buf].modified

			if name ~= "" and buftype == "" then
				local short_name = vim.fn.fnamemodify(name, ":t")
				local path = vim.fn.fnamemodify(name, ":~:.")

				table.insert(buffers, {
					bufnr = buf,
					name = short_name,
					path = path,
					full_path = name,
					modified = modified,
					current = buf == current_buf,
				})
			end
		end
	end

	-- Sort: current first, then modified, then alphabetically
	table.sort(buffers, function(a, b)
		if a.current ~= b.current then
			return a.current
		end
		if a.modified ~= b.modified then
			return a.modified
		end
		return a.name < b.name
	end)

	cache.buffers = buffers
	update_cache_time("buffers")
	return buffers
end

---Get git status asynchronously
---@param callback function
function M.get_git_status(callback)
	if is_cache_valid("git_status") and cache.git_status then
		callback(cache.git_status)
		return
	end

	-- Check if we're in a git repo
	local git_dir = vim.fn.finddir(".git", vim.fn.getcwd() .. ";")
	if git_dir == "" then
		callback({})
		return
	end

	-- Run git status asynchronously
	local stdout = vim.uv.new_pipe()
	local handle
	local output = {}

	handle = vim.uv.spawn("git", {
		args = { "status", "--porcelain=v1", "--untracked-files=all" },
		stdio = { nil, stdout, nil },
	}, function(code)
		stdout:close()
		handle:close()

		if code == 0 then
			local status = {
				modified = {},
				added = {},
				deleted = {},
				untracked = {},
			}

			for _, line in ipairs(output) do
				local state, file = line:match("^(..)%s+(.+)$")
				if state and file then
					if state:match("M") then
						table.insert(status.modified, file)
					elseif state:match("A") then
						table.insert(status.added, file)
					elseif state:match("D") then
						table.insert(status.deleted, file)
					elseif state:match("%?") then
						table.insert(status.untracked, file)
					end
				end
			end

			cache.git_status = status
			update_cache_time("git_status")
			callback(status)
		else
			callback({})
		end
	end)

	if stdout then
		stdout:read_start(function(err, data)
			if data then
				for line in data:gmatch("[^\r\n]+") do
					table.insert(output, line)
				end
			end
		end)
	end
end

---Get file type and language context
---@return table context
function M.get_filetype_context()
	local buf = vim.api.nvim_get_current_buf()
	return {
		filetype = vim.bo[buf].filetype,
		syntax = vim.bo[buf].syntax,
		language = vim.treesitter.language.get_lang(vim.bo[buf].filetype),
	}
end

---Get project files using various methods
---@param callback function
function M.get_project_files(callback)
	local files = {}

	-- Try ripgrep first (fastest)
	local has_rg = vim.fn.executable("rg") == 1
	if has_rg then
		local stdout = vim.uv.new_pipe()
		local handle
		local output = {}

		handle = vim.uv.spawn("rg", {
			args = { "--files", "--hidden", "--no-ignore-vcs" },
			cwd = vim.fn.getcwd(),
			stdio = { nil, stdout, nil },
		}, function(code)
			stdout:close()
			handle:close()

			if code == 0 then
				for _, file in ipairs(output) do
					table.insert(files, file)
				end
			end
			callback(files)
		end)

		if stdout then
			stdout:read_start(function(err, data)
				if data then
					for line in data:gmatch("[^\r\n]+") do
						table.insert(output, line)
					end
				end
			end)
		end
		return
	end

	-- Fallback to fd
	local has_fd = vim.fn.executable("fd") == 1
	if has_fd then
		local stdout = vim.uv.new_pipe()
		local handle
		local output = {}

		handle = vim.uv.spawn("fd", {
			args = { "--type", "f", "--hidden" },
			cwd = vim.fn.getcwd(),
			stdio = { nil, stdout, nil },
		}, function(code)
			stdout:close()
			handle:close()

			if code == 0 then
				for _, file in ipairs(output) do
					table.insert(files, file)
				end
			end
			callback(files)
		end)

		if stdout then
			stdout:read_start(function(err, data)
				if data then
					for line in data:gmatch("[^\r\n]+") do
						table.insert(output, line)
					end
				end
			end)
		end
		return
	end

	-- Last resort: use Vim's glob
	vim.schedule(function()
		local glob_files = vim.fn.glob("**/*", false, true)
		for _, file in ipairs(glob_files) do
			if vim.fn.isdirectory(file) == 0 then
				table.insert(files, file)
			end
		end
		callback(files)
	end)
end

---Infer intent from partial command input
---@param text string
---@return table intent
function M.infer_intent(text)
	local intent = {
		type = "unknown",
		context = {},
		suggestions = {},
	}

	-- File operations
	if text:match("^e%s") or text:match("^edit%s") or text:match("^tabe%s") then
		intent.type = "file_edit"
		intent.context.needs_files = true
	elseif text:match("^w%s") or text:match("^write%s") then
		intent.type = "file_write"
	elseif text:match("^b%s") or text:match("^buffer%s") then
		intent.type = "buffer_switch"
		intent.context.needs_buffers = true
	elseif text:match("^bd%s") or text:match("^bdelete%s") then
		intent.type = "buffer_delete"
		intent.context.needs_buffers = true
	-- Search operations
	elseif text:match("^%/%s") or text:match("^%?%s") then
		intent.type = "search"
		intent.context.needs_patterns = true
	-- LSP operations
	elseif text:match("symbol") or text:match("definition") or text:match("reference") then
		intent.type = "lsp_query"
		intent.context.needs_lsp = true
	-- Git operations
	elseif text:match("^Git") or text:match("^G%s") then
		intent.type = "git_command"
		intent.context.needs_git = true
	-- Help
	elseif text:match("^h%s") or text:match("^help%s") then
		intent.type = "help"
	end

	return intent
end

return M
