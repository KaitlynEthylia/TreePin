local tsparsers = require('nvim-treesitter.parsers')
local tshighlight = vim.treesitter.highlighter

--- @class TreePinConfig
--- @field hide_onscreen boolean # Hide's the pin buffer when the text of the pin is visible.
--- @field max_height? integer # Prevents the pin buffer from displaying when the pin is larger than x lines.
--- @field position 'relative'|'top'|'bottom' # May be 'relative', 'top', or 'bottom'. Determines the position of the pin buffer within the window.
--- @field icon? string # The icon to display in the sign column at the top of the pin. Set to nil to prevent the sign column being used.
--- @field zindex integer # The Z-index of the pin buffer.
--- @field seperator? string # A single character that may be used as a seperator between the editing buffer and the pin buffer.

--- @type TreePinConfig
local defaultConfig = {
	hide_onscreen = true,
	max_height = 30,
	position = 'relative',
	icon = '>',
	zindex = 50,
	seperator = nil,
}

--- @type TreePinConfig
local config = {}
local gid

--- @class TreePinPin
--- @field base TSNode
--- @field grow integer

--- @class TreePinPinTable
--- @field pin TreePinPin
--- @field bufnr buffer
--- @field lines { start: integer, end: integer }
--- @field win { winid: window, bufnr: buffer }
--- @field autocmd integer

--- @type TreePinPinTable[]
local winlocals = {}

local function update(winnr)
	local wl = winlocals[winnr]
	if not wl then return end

	local height = wl.lines[2] - wl.lines[1] + 1
	local row = 0

	if (config.hide_onscreen
		and vim.fn.line('w0', winnr) <= wl.lines[1]
		and vim.fn.line('w$', winnr) > wl.lines[2])
		or config.max_height < height
	then
		if wl.win then
			vim.api.nvim_win_close(wl.win.winid, false)
			vim.api.nvim_buf_delete(wl.win.bufnr, { force = true })
			wl.win = nil
		end
		return
	end

	if config.position == 'bottom'
		or (config.position == 'relative'
		and vim.fn.line('w0', winnr) < wl.lines[1])
	then
		row = vim.fn.winheight(winnr) - height
	end

	local lines = vim.api.nvim_buf_get_lines(wl.bufnr, wl.lines[1], wl.lines[2] + 1, false)

	if not wl.win then
		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, vim.api.nvim_buf_line_count(bufnr), false, lines)

		local ft = vim.bo[wl.bufnr].filetype
		local bufhl = tshighlight.active[wl.bufnr]
		vim.bo[bufnr].filetype = ft
		local lang = assert(vim.treesitter.language.get_lang(ft))
		bufhl:get_query(lang):query()

		if config.icon then
			vim.cmd('sign place 368 line=1 name=pin group=Pin buffer=' .. bufnr)
		end

		local winid = vim.api.nvim_open_win(bufnr, false, {
			relative = 'win',
			width = vim.fn.winwidth(winnr),
			height = height,
			row = row,
			col = 0,
			focusable = false,
			noautocmd = true,
			zindex = config.zindex,
			border = config.seperator
				and { '', '', '', '', config.seperator, config.seperator, config.seperator, '' }
		})
		winlocals[winnr].win = {
			winid = winid,
			bufnr = bufnr,
		}
		return
	end
	vim.api.nvim_buf_set_lines(wl.win.bufnr, 0, vim.api.nvim_buf_line_count(wl.win.bufnr), false, lines)
	vim.api.nvim_win_set_config(wl.win.winid, {
		relative = 'win',
		row = row,
		col = 0,
		height = height,
	})

	if config.icon then
		vim.cmd('sign place 368 line=1 name=pin group=Pin buffer=' .. wl.win.bufnr)
	end
end

local function growNode(node, n)
	local range1, _, range2, c = node:range()
	if c == 0 then range2 = range2 - 1 end
	local ranges = { range1, range2 }
	local growth = 0
	local lnode = node
	while lnode and lnode:parent() and lnode:parent():parent() do
		if growth >= n then break end
		local r1 = { lnode:range() }
		local r2 = { lnode:parent():range() }
		if r1[4] == 0 then r1[3] = r1[3] - 1 end
		if r2[4] == 0 then r2[3] = r2[3] - 1 end
		if r1[1] ~= r2[1] or r1[3] ~= r2[3] then
			growth = growth + 1
			ranges = { r2[1], r2[3] }
		end
		lnode = lnode:parent()
	end
	return ranges
end

local function getMaxGrowth(node)
	local growth = 0
	local lnode = node
	while lnode and lnode:parent() and lnode:parent():parent() do
		local r1 = { lnode:range() }
		local r2 = { lnode:parent():range() }
		if r1[4] == 0 then r1[3] = r1[3] - 1 end
		if r2[4] == 0 then r2[3] = r2[3] - 1 end
		if r1[1] ~= r2[1] or r1[3] ~= r2[3] then
			growth = growth + 1
		end
		lnode = lnode:parent()
	end
	return growth
end

local function recalc(winnr)
	local pin = winlocals[winnr].pin
	winlocals[winnr].lines = growNode(pin.base, pin.grow)
	if config.icon then
		vim.cmd('sign unplace * group=Pin')
		vim.cmd('sign place 367 line=' ..
			winlocals[winnr].lines[1] + 1 .. ' name=pin group=Pin buffer=' .. winlocals[winnr].bufnr)
	end
end

local M = {}

--Creates a pin on a treesitter node in some buffer to be
--displayed in some window.
--- @param winnr window # The window for the pin to display in.
--- @param base TSNode # The smallest treesitter node for the pin to enclose around.
--- @param grow integer? # How far to expand the base node. Defaults to 0.
--- @param bufnr buffer? # The buffer for the pin to reference. Defaults to the window's buffer.
function M.pin(winnr, base, grow, bufnr)
	if not winnr or type(winnr) == "table" then winnr = vim.api.nvim_get_current_win() end
	bufnr = bufnr or vim.api.nvim_win_get_buf(winnr)
	grow = grow or 0
	M.pinClear(winnr)
	winlocals[winnr] = {
		bufnr = bufnr,
		pin = {
			base = base,
			grow = grow,
		},
	}
	recalc(winnr)
	M.pinShow(winnr)
end

--Sets the window's pin at the treesitter node under the cursor.
--- @param winnr window? # The window for the pin to be displayed in. Defaults to the current window.
function M.pinLocal(winnr)
	if not winnr or type(winnr) == "table" then winnr = vim.api.nvim_get_current_win() end
	local bufnr = vim.api.nvim_win_get_buf(winnr)
	M.pin(winnr, assert(vim.treesitter.get_node({ bufnr = bufnr })))
end

--Sets the window's pin at the treesitter node under the
--cursor in bufnr.
--- @param winnr window? # The window for the pin to be displayed in. Defaults to the current window.
--- @param bufnr buffer # The buffer that the pin references.
function M.pinForeign(bufnr, winnr)
	if not winnr or type(winnr) == "table" then winnr = vim.api.nvim_get_current_win() end
	M.pin(winnr, assert(vim.treesitter.get_node({ bufnr = bufnr })), 0, bufnr)
end

--Sets the window's pin at the second largest treesitter node
--under the cursor (the largest is the file itself).
--- @param winnr window? # The window for the pin to be displayed in. Defaults to the current window.
function M.pinRoot(winnr)
	if not winnr or type(winnr) == "table" then winnr = vim.api.nvim_get_current_win() end
	local bufnr = vim.api.nvim_win_get_buf(winnr)
	local base = assert(vim.treesitter.get_node({ bufnr = bufnr }))
	local grow = getMaxGrowth(base)
	M.pin(winnr, base, grow)
end

--Expands the pin to the next parent treesitter node that sits
--on a different line.
--- @param winnr window? # The window of the pin to be affected. Defaults to the current window.
function M.pinGrow(winnr)
	if not winnr or type(winnr) == "table" then winnr = vim.api.nvim_get_current_win() end
	local base = winlocals[winnr].pin.base
	local grow = winlocals[winnr].pin.grow
	local lines = winlocals[winnr].lines
	if lines == growNode(base, grow + 1) then
		print("Already pinning largest possible node")
		return
	end
	winlocals[winnr].pin.grow = grow + 1
	recalc(winnr)
	update(winnr)
end

--Reverses the effect of growing the pin. Cannot be shrunk
--smaller than the node under the cursor when the pin was
--created.
--- @param winnr window? # The window of the pin to be affected. Defaults to the current window.
function M.pinShrink(winnr)
	if not winnr or type(winnr) == "table" then winnr = vim.api.nvim_get_current_win() end
	local grow = winlocals[winnr].pin.grow
	if grow == 0 then
		print("Already at the base of the pin")
		return
	end
	winlocals[winnr].pin.grow = grow - 1
	recalc(winnr)
	update(winnr)
end

--Removes the pin buffer and the pin itself.
--- @param winnr window? # The window of the pin to be affected. Defaults to the current window.
function M.pinClear(winnr)
	if not winnr or type(winnr) == "table" then winnr = vim.api.nvim_get_current_win() end
	M.pinHide(winnr)
	if config.icon then
		vim.cmd('sign unplace * group=Pin')
	end
	winlocals[winnr] = nil
end

--Jump to the first line of the pin.
--- @param winnr window? # The window of the pin to be affected. Defaults to the current window.
function M.pinGo(winnr)
	if not winnr or type(winnr) == "table" then winnr = vim.api.nvim_get_current_win() end
	if not winlocals[winnr] then
		print("No pin set for this window")
		return
	end
	vim.api.nvim_win_set_cursor(winnr, { winlocals[winnr].lines[1] + 1, 0 })
end

--Called automatically when a pin is created. Enables
--displaying the pin buffer.
--- @param winnr window? # The window of the pin to be affected. Defaults to the current window.
function M.pinShow(winnr)
	if not winnr or type(winnr) == "table" then winnr = vim.api.nvim_get_current_win() end
	if not winlocals[winnr] then return end
	vim.api.nvim_create_autocmd('WinScrolled', {
		group = gid,
		callback = function() update(winnr) end,
	})
	update(winnr)
end

--Hides the pin buffer but keeps the pin stored.
--- @param winnr window? # The window of the pin to be affected. Defaults to the current window.
function M.pinHide(winnr)
	if not winnr or type(winnr) == "table" then winnr = vim.api.nvim_get_current_win() end
	if not winlocals[winnr] then return end
	if winlocals[winnr].autocmd then
		vim.api.nvim_del_autocmd(winlocals[winnr].autocmd)
		winlocals[winnr].autocmd = nil
	end
	if winlocals[winnr].win then
		vim.api.nvim_win_close(winlocals[winnr].win.winid, false)
		vim.api.nvim_buf_delete(winlocals[winnr].win.bufnr, { force = true })
		winlocals[winnr].win = nil
	end
end

local has_setup = false

--- @param opts TreePinConfig
function M.setup(opts)
	if has_setup then return end
	has_setup = true
	opts = opts or {}

	config = vim.tbl_deep_extend('force', defaultConfig, opts)
	if config.icon then
		vim.cmd('sign define pin texthl=TreepinPin text=' .. config.icon)
	end
	gid = vim.api.nvim_create_augroup('treepin_update', {})
	tsparsers.get_parser()

	vim.api.nvim_create_user_command('TPPin', M.pinLocal, {})
	vim.api.nvim_create_user_command('TPRoot', M.pinRoot, {})
	vim.api.nvim_create_user_command('TPGrow', M.pinGrow, {})
	vim.api.nvim_create_user_command('TPShrink', M.pinShrink, {})
	vim.api.nvim_create_user_command('TPClear', M.pinClear, {})
	vim.api.nvim_create_user_command('TPShow', M.pinShow, {})
	vim.api.nvim_create_user_command('TPHide', M.pinHide, {})
	vim.api.nvim_create_user_command('TPGo', M.pinGo, {})

	vim.api.nvim_set_hl(0, 'TreepinPin', { fg = 'LightBlue', default = true })
end

return M
