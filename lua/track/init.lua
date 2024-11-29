local M = {}

-- Sidebar buffer and window IDs
M.sidebar_buf = nil
M.sidebar_win = nil

M.config = {
	enabled = true,
	max_tracking = 70,
	window = {
		width = 0.25,
		position = "right",
	},
}

local keylog_state = {
	key_counts = {},
}

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
		relative = "editor",
		width = width,
		height = lines,
		col = columns - width,
		row = 0,
		style = "minimal",
		border = "none",
	})

	-- Set some options for the window
	vim.wo[M.sidebar_win].wrap = false
	vim.wo[M.sidebar_win].cursorline = true
	vim.api.nvim_buf_set_lines(M.sidebar_buf, 0, -1, false, { "Key Log" })
end

-- Log commands to the sidebar
function M.log_command(cmd)
	if not (M.sidebar_buf and vim.api.nvim_buf_is_valid(M.sidebar_buf)) then
		return
	end

	vim.bo[M.sidebar_buf].modifiable = true
	vim.api.nvim_buf_set_lines(M.sidebar_buf, -1, -1, false, { cmd })
	vim.bo[M.sidebar_buf].modifiable = false
end

function M.display()
	if not (M.sidebar_buf and vim.api.nvim_buf_is_valid(M.sidebar_buf)) then
		return
	end

	local count_key_pairs = {}
	for key, count in pairs(keylog_state.key_counts) do
		table.insert(count_key_pairs, { key, count })
	end

	table.sort(count_key_pairs, function(a, b)
		return a[2] > b[2]
	end)

	local summary = {}
	for _, pair in pairs(count_key_pairs) do
		local key, count = pair[1], pair[2]
		local line = key .. "\t" .. count
		table.insert(summary, line)
	end

	vim.bo[M.sidebar_buf].modifiable = true
	vim.api.nvim_buf_set_lines(M.sidebar_buf, 1, -1, false, summary)
	vim.bo[M.sidebar_buf].modifiable = false
end

--@param key string
--@param typed string
function M.on_key(_, typed)
	if not typed then
		return
	end

	local mode = vim.api.nvim_get_mode().mode
	if mode == "i" then
		return
	end

	if string.sub(typed, 1, 2) == "\x80\xfd" then
		typed = "🖱️"
	end

	local count = keylog_state.key_counts[typed] or 0
	keylog_state.key_counts[typed] = count + 1

	M.display()
end

-- Setup autocommand to track normal mode commands
function M.setup()
	if not M.config.enabled then
		return
	end

	M.create_sidebar()

	vim.on_key(M.on_key, nil, {})
end

return M
