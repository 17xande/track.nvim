local M = {}

-- Sidebar buffer and window IDs
M.sidebar_buf = nil
M.sidebar_win = nil

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
	local width = math.floor(columns * 0.25)

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
	vim.api.nvim_buf_set_lines(M.sidebar_buf, 0, -1, false, { "Command Log:" })
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

-- Setup autocommand to track normal mode commands
function M.setup()
	M.create_sidebar()

	vim.on_key(function(key, typed)
		M.log_command("key: " .. key .. " typed: " .. typed)
	end, nil, {})
end

return M
