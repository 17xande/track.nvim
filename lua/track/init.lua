local M = {}

-- Sidebar buffer and window IDs
M.sidebar_buf = nil
M.sidebar_win = nil

M.config = {
	enabled = false,
	max_tracking = 70,
	window = {
		width = 0.15,
		position = "right",
	},
	log_file = vim.fn.stdpath("data") .. "/nvim/track.json",
	debounce_ms = 1000,
}

-- State management
local state = {
	current_command = "",
	operator_pending = false,
	count = "",
	last_write_time = 0,
	action_counts = {},
	keymaps = {},
}

-- Initialize keymaps
local function update_keymaps()
	state.keymaps = {}
	local modes = { "n", "v", "x" }
	for _, mode in ipairs(modes) do
		local maps = vim.api.nvim_get_keymap(mode)
		for _, map in ipairs(maps) do
			state.keymaps[mode .. map.lhs] = map.rhs
		end
	end
end

-- Load existing counts from JSON file
local function load_action_counts()
	local file = io.open(M.config.log_file, "r")
	if file then
		local content = file:read("*all")
		file:close()
		if content and content ~= "" then
			state.action_counts = vim.json.decode(content)
		end
	end
end

-- Write counts to JSOn file with debouncing
local function write_to_log()
	local current_time = vim.loop.now()
	if current_time - state.last_write_time >= M.config.debounce_ms then
		local file = io.open(M.config.log_file, "w")
		if file then
			file:write(vim.json.encode(state.action_counts))
			file:close()
			state.last_write_time = current_time
		end
	end
end

-- Log a complete command
local function log_command(command)
	-- Increment the count for this command
	state.action_counts[command] = (state.action_counts[command] or 0) + 1

	-- Update the sidebar display
	M.display()

	vim.defer_fn(write_to_log, M.config.debounce_ms)
end

-- Create the sidebar window
function M.create_sidebar()
	if M.sidebar_win and vim.api.nvim_win_is_valid(M.sidebar_win) then
		return
	end

	-- Create a new buffer
	M.sidebar_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[M.sidebar_buf].bufhidden = "wipe"
	vim.bo[M.sidebar_buf].modifiable = true

	-- Get the current editor dimensions
	local columns = vim.o.columns
	local lines = vim.o.lines
	local width = math.floor(columns * M.config.window.width)

	-- Create a floating window
	M.sidebar_win = vim.api.nvim_open_win(M.sidebar_buf, false, {
		width = width,
		split = "right",
		style = "minimal",
	})

	-- Set some options for the window
	vim.wo[M.sidebar_win].wrap = false
	vim.wo[M.sidebar_win].cursorline = true
	vim.api.nvim_buf_set_lines(M.sidebar_buf, 0, -1, false, { "Key Log" })
end

function M.display()
	if not (M.sidebar_buf and vim.api.nvim_buf_is_valid(M.sidebar_buf)) then
		return
	end

	local count_key_pairs = {}
	for key, count in pairs(state.action_counts) do
		table.insert(count_key_pairs, { key, count })
	end

	table.sort(count_key_pairs, function(a, b)
		return a[2] > b[2]
	end)

	local summary = { "Action Counts:" }
	for _, pair in pairs(count_key_pairs) do
		local key, count = pair[1], pair[2]
		local line = string.format("%-20s %d", key, count)
		table.insert(summary, line)
	end

	vim.bo[M.sidebar_buf].modifiable = true
	vim.api.nvim_buf_set_lines(M.sidebar_buf, 1, -1, false, summary)
	vim.bo[M.sidebar_buf].modifiable = false
end

--@param key string
--@param typed string
function M.on_key(_, typed)
	if not typed or not M.config.enabled then
		return
	end

	local mode = vim.api.nvim_get_mode().mode
	if mode == "i" or mode == "c" then
		return
	end

	-- Handle special keys/mouse
	if string.sub(typed, 1, 2) == "\x80\xfd" then
		typed = "🖱️"
	elseif string.sub(typed, 1, 1) == "\x80" then
		typed = string.sub(typed, 2)
	end

	-- Handle counts
	if typed:match("^%d$") and not state.operator_pending then
		state.count = state.count .. typed
		return
	end

	-- Handle operators
	if vim.fn.index({ "d", "y", "c" }, typed) >= 0 then
		state.operator_pending = true
		state.current_command = state.count .. typed
		return
	end

	-- Build complete command
	local complete_command = state.count .. state.current_command .. typed

	-- Check if it's a mapped command
	local map_key = mode .. complete_command
	if state.keymaps[map_key] then
		complete_command = complete_command .. " (" .. state.keymaps[map_key] .. ")"
	end

	-- Log the command if it's complete
	if not state.operator_pending or vim.fn.index({ "j", "k", "h", "l", "w", "b", "e" }, typed) >= 0 then
		log_command(complete_command)
		state.current_command = ""
		state.operator_pending = false
		state.count = ""
	end
	-- local count = state.key_counts[typed] or 0
	-- state.key_counts[typed] = count + 1
	-- M.display()
end

-- Setup autocommand to track normal mode commands
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	-- Create a log file directory if it doesn't exist
	local log_dir = vim.fn.fnamemodify(M.config.log_file, ":h")
	vim.fn.mkdir(log_dir, "p")

	-- Load existing counts from JSON file
	load_action_counts()

	-- Initialize keymaps
	update_keymaps()

	-- Create commands
	vim.api.nvim_create_user_command("TrackToggle", function()
		M.config.enabled = not M.config.enabled
		if M.config.enabled then
			M.create_sidebar()
		elseif M.sidebar_win and vim.api.nvim_win_is_valid(M.sidebar_win) then
			vim.api.nvim_win_close(M.sidebar_win, true)
		end
	end, {})

	-- Setup listener
	vim.on_key(M.on_key, nil, {})

	-- Watch for keymap changes
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "*",
		callback = update_keymaps,
	})

	-- automatically close the sidebar when quitting
	vim.api.nvim_create_autocmd("QuitPre", {
		callback = function()
			if M.sidebar_win and vim.api.nvim_win_is_valid(M.sidebar_win) then
				vim.api.nvim_win_close(M.sidebar_win, true)
			end
			-- Ensure final counts are written
			write_to_log()
		end,
	})
end

return M
