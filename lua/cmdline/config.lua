local M = {}

M.defaults = {
	-- Window configuration - modern and comfortable
	window = {
		relative = "editor",
		position = "bottom", -- Pinned to bottom
		width = 0.8, -- 80% of screen width for better visibility
		height = 1,
		max_height = 20, -- Increased for better completion display
		border = "rounded",
		zindex = 50,
		title = "", -- Can be set dynamically
		title_pos = "center",
		blend = 0, -- Solid by default for better readability
		padding = { top = 0, bottom = 0, left = 1, right = 1 }, -- Internal padding
	},

	animation = {
		enabled = true,
		duration = 180, -- Slightly longer for smoother feel
		slide_distance = 8, -- More noticeable slide
		fade_enabled = true,
		scale_enabled = true,
	},

	-- Modern theme with better contrast
	theme = {
		bg = "#1e1e2e",
		fg = "#cdd6f4",
		border_fg = "#89b4fa",
		border_bg = nil,
		prompt_bg = "#313244", -- Slightly different for prompt area
		prompt_fg = "#89b4fa",
		prompt_icon_fg = "#f9e2af", -- Gold/yellow for icons
		cursor_bg = "#f38ba8", -- Pink cursor
		cursor_fg = "#1e1e2e",
		selection_bg = "#585b70", -- Lighter selection
		selection_fg = "#cdd6f4",
		item_fg = "#cdd6f4",
		item_kind_fg = "#89dceb", -- Cyan for kinds
		item_desc_fg = "#6c7086",
		header_fg = "#cba6f7",
		header_bg = "#313244",
		separator_fg = "#45475a",
		hint_fg = "#7f849c",
		error_fg = "#f38ba8",
		success_fg = "#a6e3a1",
		info_fg = "#89b4fa",
		warn_fg = "#f9e2af",

		-- Additional UI elements
		scrollbar_fg = "#585b70",
		match_fg = "#f9e2af", -- Highlight matched characters
		preview_bg = "#181825",
	},

	-- Improved icon set with fallbacks
	icons = {
		-- Main prompt icons
		cmdline = { utf8 = "󰘳 ", fallback = ": " },
		search = { utf8 = "󰍉 ", fallback = "/ " },
		search_up = { utf8 = "󰞘 ", fallback = "? " },
		filter = { utf8 = "󰈲 ", fallback = "# " },
		lua = { utf8 = "󰢱 ", fallback = "= " },
		help = { utf8 = "󰋖 ", fallback = "? " },

		-- Completion kinds with fallbacks
		Command = { utf8 = "󰘳 ", fallback = "C " },
		Function = { utf8 = "󰊕 ", fallback = "f " },
		Variable = { utf8 = "󰀫 ", fallback = "v " },
		Action = { utf8 = "󰜎 ", fallback = "a " },
		History = { utf8 = "󰋚 ", fallback = "H " },
		File = { utf8 = "󰈙 ", fallback = "F " },
		Buffer = { utf8 = "󰈔 ", fallback = "B " },
		Word = { utf8 = "󰊄 ", fallback = "W " },
		Help = { utf8 = "󰋖 ", fallback = "? " },

		Text = { utf8 = "󰉿 ", fallback = "T " },
		Method = { utf8 = "󰆧 ", fallback = "m " },
		Module = { utf8 = "󰕳 ", fallback = "M " },
		Class = { utf8 = "󰠱 ", fallback = "C " },
		Property = { utf8 = "󰜢 ", fallback = "p " },
		Field = { utf8 = "󰜢 ", fallback = "F " },
		Constructor = { utf8 = "󰆴 ", fallback = "c " },
		Enum = { utf8 = "󰕘 ", fallback = "E " },
		Interface = { utf8 = "󰜰 ", fallback = "I " },
		Keyword = { utf8 = "󰌋 ", fallback = "K " },
		Snippet = { utf8 = "󰩫 ", fallback = "S " },
		Color = { utf8 = "󰏘 ", fallback = "# " },
		Reference = { utf8 = "󰈇 ", fallback = "R " },
		Folder = { utf8 = "󰉋 ", fallback = "D " },
		EnumMember = { utf8 = "󰎠 ", fallback = "e " },
		Constant = { utf8 = "󰏿 ", fallback = "C " },
		Struct = { utf8 = "󰙅 ", fallback = "S " },
		Event = { utf8 = "󰉁 ", fallback = "E " },
		Operator = { utf8 = "󰆕 ", fallback = "O " },
		TypeParameter = { utf8 = "󰊄 ", fallback = "T " },
		Unit = { utf8 = "󰑭 ", fallback = "U " },
		Value = { utf8 = "󰎠 ", fallback = "V " },

		-- Status icons
		Modified = { utf8 = "󰫙 ", fallback = "* " },
		Added = { utf8 = "󰐕 ", fallback = "+ " },
		Deleted = { utf8 = "󰍴 ", fallback = "- " },
		Untracked = { utf8 = "󰎔 ", fallback = "? " },

		-- UI elements
		more = { utf8 = "…", fallback = "..." },
		separator = { utf8 = "│", fallback = "|" },
		selected = { utf8 = "❯", fallback = ">" },
		unselected = { utf8 = " ", fallback = " " },
		scrollbar = { utf8 = "█", fallback = "|" },
	},

	completion = {
		enabled = true,
		auto_trigger = true,
		trigger_delay = 80, -- Faster response
		fuzzy = true,
		max_items = 50, -- Show more items
		max_items_per_group = 10, -- More per group
		show_kind = true,
		show_desc = true,
		auto_select = false,

		-- Display options
		show_icons = true,
		kind_format = "compact", -- "compact" | "full" | "icon_only"
		show_source = true, -- Show where completion came from

		-- Preview
		preview_enabled = true,
		preview_max_lines = 15,

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

	features = {
		default_mappings = true,
		smart_quit = true,
		auto_pairs = true,
		undo_redo = true,
		history_nav = true,
		inline_hints = true,
		syntax_validation = true,
		telescope_picker = true,
		show_mode_hint = true, -- Show mode description
		show_stats = false, -- Show completion stats
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

		-- Additional useful mappings
		scroll_up = "<C-u>",
		scroll_down = "<C-d>",
	},

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
		max_symbols = 100,
	},

	telescope = {
		enabled = true,
		preview = true,
		layout_strategy = "vertical",
		layout_config = {
			height = 0.95,
			width = 0.9,
			preview_cutoff = 40,
			preview_height = 0.6,
		},
		-- Custom mappings for telescope picker
		mappings = {
			i = {
				["<C-j>"] = "move_selection_next",
				["<C-k>"] = "move_selection_previous",
			},
		},
	},

	treesitter = {
		enabled = true,
		highlight = true,
		validate = true,
	},

	-- Icon rendering preferences
	ui = {
		use_nerd_fonts = true, -- Try Nerd Fonts first
		icon_spacing = 2, -- Space after icons
		min_icon_width = 3, -- Minimum width for icon column
		separator_style = "thin", -- "thin" | "thick" | "dotted"
	},
}

-- Helper to get icon with fallback
function M.get_icon(icon_name, use_nerd_fonts)
	local icon = M.defaults.icons[icon_name]
	if not icon then
		return "  "
	end

	if type(icon) == "table" then
		if use_nerd_fonts == nil then
			use_nerd_fonts = M.defaults.ui.use_nerd_fonts
		end
		return use_nerd_fonts and icon.utf8 or icon.fallback
	end

	return icon
end

return M
