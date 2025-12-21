-- config.lua
-- Enhanced modern cmdline configuration with proper icons and improved UI

local M = {}

M.defaults = {
	-- Window configuration
	window = {
		relative = "editor",
		position = "center", -- Modern floating popup like Noice.nvim
		width = 0.8,
		height = 1,
		max_height = 15,
		border = "rounded",
		zindex = 50,
		title = " Command ",
		title_pos = "center",
		blend = 10, -- Subtle transparency for modern look
	},

	-- Animation settings for smoother UI transitions
	animation = {
		enabled = true,
		duration = 200, -- milliseconds
		slide_distance = 10,
	},

	-- Theme - Catppuccin Mocha inspired (popular modern theme)
	theme = {
		-- Background and foreground
		bg = "#1e1e2e",
		fg = "#cdd6f4",

		-- Borders
		border_fg = "#89b4fa",
		border_bg = nil,

		-- Prompt area
		prompt_bg = "#1e1e2e",
		prompt_fg = "#89b4fa",
		prompt_icon_fg = "#f9e2af",

		-- Cursor
		cursor_bg = "#f38ba8",
		cursor_fg = "#1e1e2e",

		-- Selection
		selection_bg = "#45475a",
		selection_fg = "#cdd6f4",

		-- Completion items
		item_fg = "#cdd6f4",
		item_kind_fg = "#89b4fa",
		item_desc_fg = "#6c7086",

		-- Headers and groups
		header_fg = "#cba6f7",
		header_bg = "#313244",
		separator_fg = "#45475a",

		-- States
		hint_fg = "#6c7086",
		error_fg = "#f38ba8",
		success_fg = "#a6e3a1",
	},

	-- Icons (Nerd Font required) - Based on Noice.nvim and modern standards
	icons = {
		-- Mode icons
		cmdline = "󰘳 ",
		search = "󰍉 ",
		search_up = "󰍞 ",
		filter = "$ ",
		lua = "󰢱 ",
		help = "󰋖 ",

		-- Completion kinds (based on LSP specification and lspkind.nvim)
		Command = "󰘳 ",
		Function = "󰊕 ",
		Variable = "󰀫 ",
		Action = "󰜎 ",
		History = "󰋚 ",
		File = "󰈙 ",
		Buffer = "󰈔 ",
		Word = "󰊄 ",
		Help = "󰋖 ",

		-- LSP kinds (VS Code-style from lspkind.nvim)
		Text = "󰉿 ",
		Method = "󰆧 ",
		Module = "󰕳 ",
		Class = "󰠱 ",
		Property = "󰜢 ",
		Field = "󰜢 ",
		Constructor = " ",
		Enum = "󰕘 ",
		Interface = "󰜰 ",
		Keyword = "󰌋 ",
		Snippet = "󰩫 ",
		Color = "󰏘 ",
		Reference = "󰈇 ",
		Folder = "󰉋 ",
		EnumMember = " ",
		Constant = "󰏿 ",
		Struct = "󰙅 ",
		Event = "󰉁 ",
		Operator = "󰆕 ",
		TypeParameter = "󰊄 ",
		Unit = "󰑭 ",
		Value = "󰎠 ",

		-- Git kinds
		Modified = "󰏫 ",
		Added = "󰐕 ",
		Deleted = "󰍴 ",
		Untracked = "󰎔 ",
		Renamed = "󰁕 ",
		Ignored = " ",

		-- UI elements
		selected = "󰄵 ",
		item = "󰄱 ",
		separator = "─",
		more = "󰇘 ",
		ellipsis = "…",
		loading = "󰔟 ",
		error = " ",
		warning = " ",
		info = " ",
		hint = "󰌶 ",
		success = "󰄴 ",
	},

	-- Completion settings
	completion = {
		enabled = true,
		auto_trigger = true,
		trigger_delay = 50, -- milliseconds
		fuzzy = true,
		max_items = 40,
		max_items_per_group = 8,
		show_kind = true,
		show_desc = true,
		auto_select = false,

		-- Smart completion features
		smart_enabled = true,
		lsp_enabled = true,
		telescope_enabled = true,
		treesitter_enabled = true,

		-- Sources in priority order
		sources = {
			{ name = "cmdline", priority = 100 },
			{ name = "lsp", priority = 110, enabled = true },
			{ name = "quick_actions", priority = 90 },
			{ name = "history", priority = 80, max_items = 10 },
			{ name = "buffers", priority = 95 },
			{ name = "files", priority = 105 },
			{ name = "git", priority = 100 },
		},
	},

	-- Feature flags
	features = {
		default_mappings = true,
		smart_quit = true,
		auto_pairs = true,
		undo_redo = true,
		history_nav = true,
		inline_hints = true,
		syntax_validation = true,
		telescope_picker = true,
	},

	-- Custom keymaps
	keymaps = {
		-- Editing
		backspace = "<BS>",
		delete_word = "<C-w>",
		delete_line = "<C-u>",

		-- Movement
		move_left = "<C-b>",
		move_right = "<C-f>",
		move_home = "<C-a>",
		move_end = "<C-e>",

		-- History
		history_prev = "<C-p>",
		history_next = "<C-n>",

		-- Completion
		complete_next = "<Tab>",
		complete_prev = "<S-Tab>",
		complete_select = "<CR>",
		telescope_picker = "<C-Space>", -- Show Telescope enhanced picker

		-- Undo/Redo
		undo = "<C-z>",
		redo = "<C-y>",

		-- Execution
		execute = "<CR>",
		close = { "<Esc>", "<C-c>" },

		-- Paste
		paste = "<C-r>",
	},

	-- LSP integration settings
	lsp = {
		enabled = true,
		symbol_kinds = {
			"Function",
			"Method",
			"Variable",
			"Class",
			"Interface",
			"Module",
			"Property",
			"Field",
			"Constructor",
			"Enum",
			"Constant",
			"Struct",
			"Event",
			"Operator",
			"TypeParameter",
		},
		debounce_ms = 100,
	},

	-- Telescope integration settings
	telescope = {
		enabled = true,
		preview = true,
		layout_strategy = "vertical",
		layout_config = {
			height = 0.95,
			width = 0.9,
			preview_cutoff = 40,
		},
	},

	-- Tree-sitter settings
	treesitter = {
		enabled = true,
		highlight = true,
		validate = true,
	},
}

return M
