local M = {}

------------------------------------------------------------------------------
-- Configuration
------------------------------------------------------------------------------
---@class ContextProviderConfig
---@field cache_ttl number Cache time in milliseconds (default: 2000)
M.config = {
	cache_ttl = 2000, -- 2 seconds by default
}

------------------------------------------------------------------------------
-- Internal cache
------------------------------------------------------------------------------
local cache = {
	lsp_clients = nil,
	lsp_symbols = nil,
	buffers = nil,
	git_status = nil,
	project_files = nil, -- added for consistency
}

local cache_times = {}

------------------------------------------------------------------------------
-- Cache helpers
------------------------------------------------------------------------------
local function now_ms()
	return vim.loop.now()
end

---@param key string
local function is_cache_valid(key)
	local ts = cache_times[key]
	if not ts then
		return false
	end
	return (now_ms() - ts) < M.config.cache_ttl
end

---@param key string
---@param value any
local function set_cache(key, value)
	cache[key] = value
	cache_times[key] = now_ms()
end

---@param key string
---@return any|nil
local function get_cache(key)
	if is_cache_valid(key) then
		return cache[key]
	end
	return nil
end

local function clear_all_cache()
	cache = {
		lsp_clients = nil,
		lsp_symbols = nil,
		buffers = nil,
		git_status = nil,
		project_files = nil,
	}
	cache_times = {}
end

------------------------------------------------------------------------------
-- Setup
------------------------------------------------------------------------------
---Setup the module and configure cache invalidation
---@param opts? ContextProviderConfig
function M.setup(opts)
	if opts then
		M.config = vim.tbl_deep_extend("force", M.config, opts)
	end

	-- Clear cache when switching buffers or after writing
	local augroup = vim.api.nvim_create_augroup("ContextProviderCache", { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
		group = augroup,
		callback = clear_all_cache,
	})
end

------------------------------------------------------------------------------
-- LSP Clients
------------------------------------------------------------------------------
---Get attached LSP clients for the current buffer
---@return table[] List of client info tables
function M.get_lsp_clients()
	local cached = get_cache("lsp_clients")
	if cached then
		return cached
	end

	local clients = {}
	local buf = vim.api.nvim_get_current_buf()

	-- vim.lsp.get_clients is the current API (buf_get_clients is deprecated/removed)
	local attached = vim.lsp.get_clients({ bufnr = buf })

	for _, client in ipairs(attached) do
		table.insert(clients, {
			name = client.name,
			id = client.id,
			capabilities = client.server_capabilities or {},
			root_dir = client.config and client.config.root_dir or nil,
		})
	end

	set_cache("lsp_clients", clients)
	return clients
end

------------------------------------------------------------------------------
-- LSP Document Symbols (async)
------------------------------------------------------------------------------
---Asynchronously fetch document symbols via LSP
---@param callback fun(symbols: table[])
function M.get_lsp_symbols(callback)
	local cached = get_cache("lsp_symbols")
	if cached then
		callback(cached)
		return
	end

	local buf = vim.api.nvim_get_current_buf()
	local params = { textDocument = vim.lsp.util.make_text_document_params(buf) }

	vim.lsp.buf_request(buf, "textDocument/documentSymbol", params, function(err, result)
		if err then
			vim.notify("LSP documentSymbol error: " .. vim.inspect(err), vim.log.levels.ERROR)
			callback({})
			return
		end

		if not result or vim.tbl_isempty(result) then
			set_cache("lsp_symbols", {})
			callback({})
			return
		end

		local symbols = {}

		---Recursively extract symbols from hierarchical or flat response
		---@param items table[]
		---@param prefix string?
		local function extract(items, prefix)
			prefix = prefix or ""
			for _, item in ipairs(items or {}) do
				local name = item.name or item.text
				if name then
					table.insert(symbols, {
						name = name,
						kind = vim.lsp.protocol.SymbolKind[item.kind] or "Unknown",
						location = item.location or item.range,
						prefix = prefix,
					})

					if item.children then
						extract(item.children, prefix .. name .. ".")
					end
				end
			end
		end

		-- Handle both hierarchical and flat responses
		if result[1] and result[1].children then
			extract(result)
		else
			extract(result)
		end

		set_cache("lsp_symbols", symbols)
		callback(symbols)
	end)
end

------------------------------------------------------------------------------
-- Workspace Symbols (async)
------------------------------------------------------------------------------
---@param query string?
---@param callback fun(symbols: table[])
function M.get_workspace_symbols(query, callback)
	query = query or ""

	local params = { query = query }
	vim.lsp.buf_request(0, "workspace/symbol", params, function(err, result)
		if err then
			vim.notify("LSP workspace/symbol error: " .. vim.inspect(err), vim.log.levels.ERROR)
			callback({})
			return
		end

		local symbols = {}
		for _, item in ipairs(result or {}) do
			table.insert(symbols, {
				name = item.name or "unknown",
				kind = vim.lsp.protocol.SymbolKind[item.kind] or "Unknown",
				location = item.location,
				container = item.containerName,
			})
		end
		callback(symbols)
	end)
end

------------------------------------------------------------------------------
-- Buffers List
------------------------------------------------------------------------------
---Get list of loaded, named, normal buffers
---@return table[]
function M.get_buffers()
	local cached = get_cache("buffers")
	if cached then
		return cached
	end

	local list = {}
	local current_buf = vim.api.nvim_get_current_buf()

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			local name = vim.api.nvim_buf_get_name(bufnr)
			if name ~= "" and vim.bo[bufnr].buftype == "" then
				table.insert(list, {
					bufnr = bufnr,
					name = vim.fn.fnamemodify(name, ":t"),
					path = vim.fn.fnamemodify(name, ":~:."),
					full = name,
					modified = vim.bo[bufnr].modified,
					current = bufnr == current_buf,
				})
			end
		end
	end

	-- Sort: current first, then modified, then name
	table.sort(list, function(a, b)
		if a.current ~= b.current then
			return a.current
		end
		if a.modified ~= b.modified then
			return a.modified
		end
		return a.name < b.name
	end)

	set_cache("buffers", list)
	return list
end

------------------------------------------------------------------------------
-- Git Status (async)
------------------------------------------------------------------------------
---@param callback fun(status: table)
function M.get_git_status(callback)
	local cached = get_cache("git_status")
	if cached then
		callback(cached)
		return
	end

	local cwd = vim.fn.getcwd()
	if not vim.uv.fs_stat(cwd .. "/.git") then
		-- Not a git repo
		set_cache("git_status", {})
		callback({})
		return
	end

	local stdout = vim.loop.new_pipe()
	local output = {}
	local handle

	handle = vim.loop.spawn("git", {
		args = { "status", "--porcelain=v1", "--untracked-files=all" },
		cwd = cwd,
		stdio = { nil, stdout, nil },
	}, function(code)
		if stdout then
			stdout:close()
		end
		if handle then
			handle:close()
		end

		if code ~= 0 then
			callback({})
			return
		end

		local status = { modified = {}, added = {}, deleted = {}, untracked = {} }

		for _, line in ipairs(output) do
			local state, file = line:match("^(..)%s+(.+)$")
			if state and file then
				-- XY format: X = index, Y = worktree
				if state:match("M") or state:match("T") then
					table.insert(status.modified, file)
				elseif state:match("A") then
					table.insert(status.added, file)
				elseif state:match("D") then
					table.insert(status.deleted, file)
				elseif state:match("%?%?") then
					table.insert(status.untracked, file)
				end
			end
		end

		set_cache("git_status", status)
		callback(status)
	end)

	if not handle then
		callback({})
		return
	end

	stdout:read_start(function(_, data)
		if data then
			for line in data:gmatch("[^\r\n]+") do
				table.insert(output, line)
			end
		end
	end)
end

------------------------------------------------------------------------------
-- Filetype Context
------------------------------------------------------------------------------
---@return table
function M.get_filetype_context()
	local buf = vim.api.nvim_get_current_buf()
	local ok, lang = pcall(vim.treesitter.language.get_lang, vim.bo[buf].filetype)
	return {
		filetype = vim.bo[buf].filetype,
		syntax = vim.bo[buf].syntax,
		ts_lang = ok and lang or nil,
	}
end

------------------------------------------------------------------------------
-- Project Files (async)
------------------------------------------------------------------------------
---@param callback fun(files: string[])
function M.get_project_files(callback)
	local cached = get_cache("project_files")
	if cached then
		callback(cached)
		return
	end

	local cwd = vim.fn.getcwd()

	local function on_exit(files, code)
		if code == 0 then
			set_cache("project_files", files)
			callback(files)
		else
			callback({})
		end
	end

	local function spawn(cmd, args)
		local stdout = vim.loop.new_pipe()
		local output = {}
		local handle = vim.loop.spawn(cmd, {
			args = args,
			cwd = cwd,
			stdio = { nil, stdout, nil },
		}, function(code)
			stdout:close()
			if handle then
				handle:close()
			end
			on_exit(output, code)
		end)

		if not handle then
			callback({})
			return
		end

		stdout:read_start(function(_, data)
			if data then
				for line in data:gmatch("[^\r\n]+") do
					table.insert(output, line)
				end
			end
		end)
	end

	if vim.fn.executable("rg") == 1 then
		spawn("rg", { "--files", "--hidden", "--no-ignore-vcs" })
		return
	end

	if vim.fn.executable("fd") == 1 then
		spawn("fd", { "--type", "f", "--hidden", "--exclude", ".git" })
		return
	end

	-- Fallback: glob (slower, but works)
	vim.schedule(function()
		local files = vim.fn.globpath(cwd, "**/*", false, true)
		local filtered = {}
		for _, f in ipairs(files) do
			if vim.fn.isdirectory(f) == 0 then
				-- Make relative to cwd
				table.insert(filtered, vim.fn.fnamemodify(f, ":.:"))
			end
		end
		set_cache("project_files", filtered)
		callback(filtered)
	end)
end

------------------------------------------------------------------------------
-- Command Intent Inference
------------------------------------------------------------------------------
---@param text string
---@return table
function M.infer_intent(text)
	if not text or type(text) ~= "string" then
		return { type = "unknown", context = {}, suggestions = {} }
	end

	local lower = text:lower()
	local intent = {
		type = "unknown",
		context = {},
		suggestions = {},
	}

	if lower:match("^e%d*$") or lower:match("^edit") then
		intent.type = "file_edit"
		intent.context.needs_files = true
	elseif lower:match("^w%d*$") or lower:match("^write") then
		intent.type = "file_write"
	elseif lower:match("^b%d*$") or lower:match("^buffer") then
		intent.type = "buffer_switch"
		intent.context.needs_buffers = true
	elseif lower:match("symbol") or lower:match("definition") or lower:match("reference") then
		intent.type = "lsp_query"
		intent.context.needs_lsp = true
	elseif lower:match("^g%s") or lower:match("^git") then
		intent.type = "git_command"
		intent.context.needs_git = true
	end

	return intent
end

return M
