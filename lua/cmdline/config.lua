-- Modified config.lua (add or adjust defaults for better bottom UI)
local M = {}

M.defaults = {
	-- Window configuration
	window = {
		relative = "editor",
		position = "bottom", -- Changed to "bottom" for bottom positioning
		width = 0.9, -- Wider for bottom bar feel
		height = 1,
		max_height = 15,
		border = "single", -- Simpler border for bottom bar
		zindex = 50,
		title = "", -- No title for cleaner look
		title_pos = nil,
		blend = 0, -- No transparency for solid bar
	},

	-- Animation settings for smoother UI transitions
	animation = {
		enabled = true,
		duration = 150, -- Shorter duration
		slide_distance = 5, -- Subtle slide
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
		cmdline = "󰘳 ", -- command palette
		search = "󰍉 ",
		search_up = "󰍞 ",
		filter = "󰈲 ", -- funnel (upgrade from "$")
		lua = "󰢱 ",
		help = "󰋖 ",

		-- Completion kinds (cmdline / menu)
		Command = "󰘳 ",
		Function = "󰊕 ",
		Variable = "󰀫 ",
		Action = "󰜎 ",
		History = "󰋚 ",
		File = "󰈙 ",
		Buffer = "󰈔 ",
		Word = "󰊄 ",
		Help = "󰋖 ",

		-- LSP kinds (VS Code / lspkind compatible)
		Text = "󰉿 ",
		Method = "󰆧 ",
		Module = "󰕳 ",
		Class = "󰠱 ",
		Property = "󰜢 ",
		Field = "󰜢 ",
		Constructor = "󰆴 ", -- added
		Enum = "󰕘 ",
		Interface = "󰜰 ",
		Keyword = "󰌋 ",
		Snippet = "󰩫 ",
		Color = "󰏘 ",
		Reference = "󰈇 ",
		Folder = "󰉋 ",
		EnumMember = "󰎠 ", -- added
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
		Rena...(truncated 315 characters)...
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
