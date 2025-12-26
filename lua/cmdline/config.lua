local M = {}

M.defaults = {
	-- Window configuration
	window = {
		relative = "editor",
		position = "bottom", -- Now bottom by default
		width = 0.9,
		height = 1,
		max_height = 15,
		border = "single",
		zindex = 50,
		title = "",
		title_pos = nil,
		blend = 0,
	},

	-- Animation settings
	animation = {
		enabled = true,
		duration = 150,
		slide_distance = 5,
	},

	-- Theme (Catppuccin Mocha inspired)
	theme = {
		bg = "#1e1e2e",
		fg = "#cdd6f4",
		border_fg = "#89b4fa",
		border_bg = nil,
		prompt_bg = "#1e1e2e",
		prompt_fg = "#89b4fa",
		prompt_icon_fg = "#f9e2af",
		cursor_bg = "#f38ba8",
		cursor_fg = "#1e1e2e",
		selection_bg = "#45475a",
		selection_fg = "#cdd6f4",
		item_fg = "#cdd6f4",
		item_kind_fg = "#89b4fa",
		item_desc_fg = "#6c7086",
		header_fg = "#cba6f7",
		header_bg = "#313244",
		separator_fg = "#45475a",
		hint_fg = "#6c7086",
		error_fg = "#f38ba8",
		success_fg = "#a6e3a1",
	},

	-- Icons
	icons = {
		cmdline = "󰘳 ",
		search = "󰍉 ",
		search_up = "󰍞 ",
		filter = "󰈲 ",
		lua = "󰢱 ",
		help = "󰋖 ",

		Command = "󰘳 ",
		Function = "󰊕 ",
		Variable = "󰀫 ",
		Action = "󰜎 ",
		History = "󰋚 ",
		File = "󰈙 ",
		Buffer = "󰈔 ",
		Word = "󰊄 ",
		Help = "󰋖 ",

		-- LSP kinds
		Text = "󰉿 ",
		Method = "󰆧 ",
		Module = "󰕳 ",
		Class = "󰠱 ",
		Property = "󰜢 ",
		Field = "󰜢 ",
		Constructor = "󰆴 ",
		Enum = "󰕘 ",
		Interface = "󰜰 ",
		Keyword = "󰌋 ",
		Snippet = "󰩫 ",
		Color = "󰏘 ",
		Reference = "󰈇 ",
		Folder = "󰉋 ",
		EnumMember = "󰎠 ",
		Constant = "󰏿 ",
		Struct = "󰙅 ",
		Event = "󰉁 ",
		Operator = "󰆕 ",
		TypeParameter = "󰊄 ",
		Unit = "󰑭 ",
		Value = "󰎠 ",

		-- Git
		Modified = "󰏫 ",
		Added = "󰐕 ",
		Deleted = "󰍴 ",
		Untracked = "󰎔 ",

		more = "…",
	},

	-- Completion
	completion = {
		enabled = true,
		auto_trigger = true,
		trigger_delay = 50,
		fuzzy = true,
		max_items = 40,
		max_items_per_group = 8,
		show_kind = true,
		show_desc = true,
		auto_select = false,
		smart_enabled = true,
		lsp_enabled = true,
		telescope_enabled = true,
		treesitter_enabled = true,
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

	-- Features
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

	-- Keymaps
	keymaps = {
		backspace = "<BS>",
		delete_word = "<C-w>",
		delete_line = "<C-u>",
		move_left = "<C-b>",
		move_right = "<C-f>",
		move_home = "<C-a>",
		move_end = "<C-e>",
		history_prev = "<C-p>",
		history_next = "<C-n>",
		complete_next = "<Tab>",
		complete_prev = "<S-Tab>",
		complete_select = "<CR>",
		telescope_picker = "<C-Space>",
		undo = "<C-z>",
		redo = "<C-y>",
		execute = "<CR>",
		close = { "<Esc>", "<C-c>" },
		paste = "<C-r>",
	},

	-- LSP
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

	-- Telescope
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

	-- Treesitter
	treesitter = {
		enabled = true,
		highlight = true,
		validate = true,
	},
}

return M
