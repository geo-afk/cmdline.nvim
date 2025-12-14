-- Tree-sitter integration for parsing and understanding cmdline input
-- Provides syntax highlighting and semantic analysis

local M = {}

-- Check if Tree-sitter is available
local has_treesitter, ts = pcall(require, "nvim-treesitter")
local has_parsers, parsers = pcall(require, "nvim-treesitter.parsers")
local has_highlighter, ts_highlighter = pcall(require, "vim.treesitter.highlighter")

M.available = has_treesitter and has_parsers

---Setup Tree-sitter integration
function M.setup()
	if not M.available then
		vim.notify("Tree-sitter not available. Syntax highlighting will be limited.", vim.log.levels.INFO)
		return
	end

	-- Ensure required parsers are installed
	M.ensure_parsers()
end

---Ensure required parsers are installed
function M.ensure_parsers()
	if not M.available then
		return
	end

	local required = { "vim", "lua", "bash" }

	for _, lang in ipairs(required) do
		if not parsers.has_parser(lang) then
			vim.notify(string.format("Tree-sitter parser for %s not installed", lang), vim.log.levels.WARN)
		end
	end
end

---Parse command text and return AST
---@param text string
---@param mode string
---@return table|nil ast
function M.parse_command(text, mode)
	if not M.available or text == "" then
		return nil
	end

	local lang = M.infer_language(text, mode)
	if not lang or not parsers.has_parser(lang) then
		return nil
	end

	-- Create a parser
	local ok, parser = pcall(vim.treesitter.get_string_parser, text, lang)
	if not ok or not parser then
		return nil
	end

	-- Parse the text
	local tree = parser:parse()[1]
	if not tree then
		return nil
	end

	return {
		root = tree:root(),
		tree = tree,
		lang = lang,
	}
end

---Infer language from command mode and text
---@param text string
---@param mode string
---@return string|nil lang
function M.infer_language(text, mode)
	if mode == ":" then
		-- Check for Lua commands
		if text:match("^lua%s") or text:match("^=%s") then
			return "lua"
		end
		return "vim"
	elseif mode == "/" or mode == "?" then
		return "regex"
	elseif mode == "!" then
		return "bash"
	end

	return nil
end

---Extract tokens from parsed AST
---@param ast table
---@return table[] tokens
function M.extract_tokens(ast)
	if not ast or not ast.root then
		return {}
	end

	local tokens = {}
	local query_string = [[
    (identifier) @identifier
    (string) @string
    (number) @number
    (comment) @comment
  ]]

	local ok, query = pcall(vim.treesitter.query.parse, ast.lang, query_string)
	if not ok or not query then
		return {}
	end

	for id, node, metadata in query:iter_captures(ast.root, text, 0, -1) do
		local name = query.captures[id]
		local start_row, start_col, end_row, end_col = node:range()

		table.insert(tokens, {
			type = name,
			text = vim.treesitter.get_node_text(node, text),
			range = {
				start_row = start_row,
				start_col = start_col,
				end_row = end_row,
				end_col = end_col,
			},
		})
	end

	return tokens
end

---Get syntax highlights for text
---@param text string
---@param mode string
---@return table[] highlights
function M.get_highlights(text, mode)
	if not M.available or text == "" then
		return {}
	end

	local ast = M.parse_command(text, mode)
	if not ast then
		return M.fallback_highlights(text, mode)
	end

	local highlights = {}
	local lang = ast.lang

	-- Get highlight query
	local ok, query = pcall(vim.treesitter.query.get, lang, "highlights")
	if not ok or not query then
		return M.fallback_highlights(text, mode)
	end

	-- Extract highlights from query
	for id, node in query:iter_captures(ast.root, text, 0, -1) do
		local hl_group = query.captures[id]
		local start_row, start_col, end_row, end_col = node:range()

		-- Map Tree-sitter highlight groups to Neovim highlight groups
		local nvim_hl = M.map_highlight_group(hl_group)

		table.insert(highlights, {
			group = nvim_hl,
			line = start_row,
			col_start = start_col,
			col_end = end_col,
		})
	end

	return highlights
end

---Map Tree-sitter highlight group to Neovim group
---@param ts_group string
---@return string nvim_group
function M.map_highlight_group(ts_group)
	local map = {
		["keyword"] = "Keyword",
		["function"] = "Function",
		["string"] = "String",
		["number"] = "Number",
		["comment"] = "Comment",
		["operator"] = "Operator",
		["variable"] = "Identifier",
		["parameter"] = "Parameter",
		["type"] = "Type",
		["constant"] = "Constant",
	}

	return map[ts_group] or "Normal"
end

---Fallback highlighting without Tree-sitter
---@param text string
---@param mode string
---@return table[] highlights
function M.fallback_highlights(text, mode)
	local highlights = {}

	if mode == ":" then
		-- Highlight Vim commands
		local cmd_pattern = "^%s*(%w+)"
		local cmd = text:match(cmd_pattern)
		if cmd then
			table.insert(highlights, {
				group = "CmdlinePrompt",
				line = 0,
				col_start = text:find(cmd) - 1,
				col_end = text:find(cmd) + #cmd - 1,
			})
		end

		-- Highlight strings
		for start_pos, content, end_pos in text:gmatch("()([\"'])(.-)%2()") do
			table.insert(highlights, {
				group = "String",
				line = 0,
				col_start = start_pos - 1,
				col_end = end_pos - 1,
			})
		end

		-- Highlight numbers
		for pos, num in text:gmatch("()(%d+)") do
			table.insert(highlights, {
				group = "Number",
				line = 0,
				col_start = pos - 1,
				col_end = pos + #num - 1,
			})
		end
	elseif mode == "/" or mode == "?" then
		-- Basic regex highlighting
		-- Highlight special characters
		for pos, char in text:gmatch("()([.*+?^$|\\()%[%]])") do
			table.insert(highlights, {
				group = "Special",
				line = 0,
				col_start = pos - 1,
				col_end = pos,
			})
		end
	end

	return highlights
end

---Analyze command structure for context
---@param text string
---@param mode string
---@return table structure
function M.analyze_structure(text, mode)
	local structure = {
		command = nil,
		args = {},
		flags = {},
		complete = false,
	}

	if mode ~= ":" then
		return structure
	end

	-- Parse command structure
	local parts = vim.split(text, "%s+", { trimempty = true })

	if #parts > 0 then
		structure.command = parts[1]

		for i = 2, #parts do
			local part = parts[i]
			if part:match("^%-") then
				table.insert(structure.flags, part)
			else
				table.insert(structure.args, part)
			end
		end

		-- Check if command looks complete
		structure.complete = text:match("%s$") ~= nil
	end

	return structure
end

---Get semantic information about cursor position
---@param text string
---@param cursor_pos number
---@param mode string
---@return table|nil context
function M.get_cursor_context(text, cursor_pos, mode)
	local ast = M.parse_command(text, mode)
	if not ast then
		return nil
	end

	-- Find node at cursor position
	local node = ast.root:descendant_for_range(0, cursor_pos - 1, 0, cursor_pos)
	if not node then
		return nil
	end

	return {
		node_type = node:type(),
		parent_type = node:parent() and node:parent():type(),
		text = vim.treesitter.get_node_text(node, text),
	}
end

---Validate syntax and return errors
---@param text string
---@param mode string
---@return table[] errors
function M.validate_syntax(text, mode)
	local errors = {}

	if not M.available or text == "" then
		return errors
	end

	local ast = M.parse_command(text, mode)
	if not ast or not ast.root then
		return errors
	end

	-- Check for ERROR nodes in the tree
	local function check_errors(node)
		if node:type() == "ERROR" then
			local start_row, start_col, end_row, end_col = node:range()
			table.insert(errors, {
				message = "Syntax error",
				line = start_row,
				col_start = start_col,
				col_end = end_col,
			})
		end

		for child in node:iter_children() do
			check_errors(child)
		end
	end

	check_errors(ast.root)
	return errors
end

return M
