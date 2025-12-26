local M = {}

M.defaults = {
	-- Window configuration - now more comfortable at bottom
	window = {
		relative = "editor",
		position = "bottom", -- Pinned to bottom
		width = 65, -- Fixed 80 columns (comfortable) - change to 0.7 for 70% if you prefer
		-- width = 0.7,           -- Alternative: 70% of screen width (uncomment if preferred)
		height = 1,
		max_height = 15,
		border = "rounded", -- Beautiful curved edges
		zindex = 50,
		title = "",
		title_pos = nil,
		blend = 5, -- Slight transparency for modern feel (0 = solid)
	},

	-- Rest of your config remains the same...
	animation = {
		enabled = true,
		duration = 150,
		slide_distance = 5,
	},

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

		Modified = "󰏫 ",
		Added = "󰐕 ",
		Deleted = "󰍴 ",
		Untracked = "󰎔 ",

		more = "…",
	},

	-- Keep the rest exactly as before (completion, features, keymaps, etc.)
	completion = {
		enabled = true,
		auto_trigger = true,
		trigger_delay = 50,
		fuzzy = true,
		max_items = 40,
		show_kind = true,
		show_desc = true,
		auto_select = false,
		smart_enabled = true,
		lsp_enabled = true,
		telescope_enabled = true,
		treesitter_enabled = true,
	},

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

	lsp = { enabled = true, debounce_ms = 100 },
	telescope = { enabled = true, preview = true },
	treesitter = { enabled = true, highlight = true, validate = true },
}

return M
