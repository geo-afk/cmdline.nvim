local M = {}

M.defaults = {
	-- Window configuration
	window = {
		relative = "editor",
		position = "bottom", -- "top", "bottom", "center"
		width = 0.6, -- percentage or absolute
		height = 1, -- initial height (grows with completions)
		max_height = 13,
		border = "rounded", -- "none", "single", "double", "rounded", "solid", "shadow"
		zindex = 50,
		title = " 󰘳 Command ",
		title_pos = "center",
	},

	-- Theme and colors
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

	-- Icons (Nerd Font required)

	icons = {
		cmdline = "󰘳 ",
		search = "󰍉 ",
		search_up = "󰍈 ",
		filter = "󰈲 ",
		lua = "󰢱 ",
		help = "󰋖 ",

		-- Completion kinds
		Command = "󰘳 ",
		Function = "󰊕 ",
		Variable = "󰫧 ",
		Action = "󰜎 ",
		History = "󰋚 ",
		File = "󰈔 ",
		Buffer = "󰈙 ",
		Word = "󰊄 ",
		Help = "󰋖 ",

		-- LSP kinds
		Module = "󰕳 ",
		Class = "󰠱 ",
		Method = "󰊕 ",
		Property = "󰜢 ",
		Field = "󰜢 ",
		Constructor = "󰆧 ",
		Enum = "󰕘 ",
		Interface = "󰜰 ",
		Keyword = "󰌋 ",
		Snippet = "󰩫 ",
		Color = "󰏘 ",
		Reference = "󰈇 ",
		Folder = "󰉋 ",
		Event = "󰉁 ",
		Operator = "󰆕 ",
		TypeParameter = "󰊄 ",

		-- Git kinds
		Modified = "󰏫 ",
		Added = "󰐕 ",
		Deleted = "󰍴 ",
		Untracked = "󰎔 ",

		-- UI elements
		selected = "󰄵 ",
		item = "󰄱 ",
		separator = "─",
		more = "󰊐 ",
	},
	-- Completion settings
	completion = {
		enabled = true,
		auto_trigger = true,
		trigger_delay = 50, -- ms
		fuzzy = true,
		max_items = 40,
		max_items_per_group = 8,
		show_kind = true,
		show_desc = true,
		auto_select = false,

		-- Smart completion features
		smart_enabled = true, -- Enable context-aware completions
		lsp_enabled = true, -- Query LSP for symbols
		telescope_enabled = true, -- Use Telescope for enhanced picking
		treesitter_enabled = true, -- Use Tree-sitter for parsing

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
		syntax_validation = true, -- Validate syntax with Tree-sitter
		telescope_picker = true, -- Show Telescope picker on <C-Space>
	},

	-- Custom keymaps (set to false to disable specific bindings)
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
		telescope_picker = "<C-1>", -- Show Telescope enhanced picker

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
		symbol_kinds = { -- Which LSP symbol kinds to include
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
		debounce_ms = 100, -- Debounce LSP requests
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
