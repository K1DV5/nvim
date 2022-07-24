local tabs = require'tabs'

local default_shell = vim.api.nvim_get_option('shell')

local function height(size)
	-- if the size is less than 1, it will be taken as the fraction of the file
	-- window
    local term_height
	if size > 1 then
		term_height = size
	else
        local alt_win = tabs.get_alt_win(0)
        if alt_win and vim.api.nvim_buf_get_option(0, 'buftype') == 'terminal' then
            term_height = vim.api.nvim_win_get_height(alt_win) + vim.api.nvim_win_get_height(0) + 1 * size
        else
            term_height = vim.api.nvim_win_get_height(0) * size 
        end
    end
	return term_height
end

-- get terminal buffers or windows
local function terminals(wins)
    local list
    local get_buffer = vim.api.nvim_win_get_buf
    if wins then  -- windows
        list = vim.api.nvim_list_wins()
    else  -- buffers
        list = vim.api.nvim_list_bufs()
        get_buffer = function(buf) return buf end
    end
    local filter_func = function(item) return vim.api.nvim_buf_get_option(get_buffer(item), 'buftype') == 'terminal' end
    return vim.tbl_filter(filter_func, list)
end

-- find and go to terminal pane, return success
local function go()
	-- terminal windows
	local tbufwins = terminals(true)
    -- if there is a terminal window
    if vim.tbl_count(tbufwins) > 0 then
        -- go to that window
        vim.api.nvim_set_current_win(tbufwins[1])
        return true
    end
    return false
end

local function toggle(size)
    -- a:size - number | float - the desired size of the pane
	-- work only if buffer is a normal file or a terminal
    local current_is_terminal = vim.api.nvim_buf_get_option(0, 'buftype') == 'terminal'
	if not vim.api.nvim_buf_get_option(0, 'modifiable') and not current_is_terminal then
        print("Not a file buffer, aborting...")
		return true
	end
	local term_height = height(size)
	-- if in terminal pane
	if current_is_terminal then
		if vim.api.nvim_win_get_height(0) < term_height then -- maximize
            vim.api.nvim_win_set_height(term_height)
		else
            vim.api.nvim_set_var('term_current_buf', vim.api.nvim_get_current_buf())
            vim.api.nvim_win_hide(0)
		end
        return true
    elseif go() then
        return true
    end
    -- terminal buffers
    local tbuflist = terminals()
    -- if last opened terminal is hidden but exists
    local current_buf = tabs.get_var('term_current_buf')
    if current_buf and vim.api.nvim_buf_is_loaded(current_buf) then
        vim.api.nvim_command('belowright ' .. term_height .. ' split +buffer\\ ' .. current_buf)
    elseif vim.tbl_count(tbuflist) > 0 then -- choose one of the others
        vim.api.nvim_command('belowright ' .. term_height .. ' split +buffer\\ ' .. tbuflist[1])
    else -- create a new one
        return
    end
    -- bring other terminal buffers into this window
    vim.api.nvim_win_set_var(0, 'tabs_buflist', tbuflist)
    return true
end

function term(cmd, dir)
    -- cmd - string | number - the cmd name or the desired win height
    if type(cmd) == 'number' then
        if toggle(cmd) then
            return
        end
        cmd = default_shell
    elseif not cmd or cmd == '' then
        cmd = default_shell
    end
    -- NEW TERMINAL
	-- terminal buffer numbers like [1, 56, 78]
	local tbuflist = terminals()
    -- same command terminal buffers
    if not dir then
        dir = vim.fn.fnamemodify('.', ':p')
    end
    local buf_name = 'term://' .. vim.fn.substitute(dir, '[\\/]\\+$', '', '') .. '//' .. cmd
    if vim.api.nvim_buf_get_option(0, 'buftype') == 'terminal' or go() then
        -- open a new terminal
        vim.api.nvim_command('edit ' .. buf_name)
    else
        -- create a new terminal in split
        vim.api.nvim_command('belowright ' .. height(0.3) .. ' split ' .. buf_name)
        -- bring other terminal buffers into this window
        vim.api.nvim_win_set_var(0, 'tabs_buflist', tbuflist)
        if cmd == 1 then
            local term_height = height(cmd)
            if vim.api.nvim_win_get_height(0) < term_height then -- maximize
                vim.api.nvim_command('resize ' .. term_height)
            end
        end
    end
    vim.api.nvim_command('lua tabs_reload()')
	-- if the cmd has argumets, delete existing with the same cmd
    if not string.find(cmd, ' ') then
        return
    end
    for i, buf in pairs(tbuflist) do
        local name = vim.fn.substitute(vim.api.nvim_buf_get_name(buf), '//\\d\\+:', '//', '')
        if name == buf_name then
            vim.api.nvim_command('bdelete! ' .. buf)
        end
    end
end

vim.api.nvim_create_user_command("T", function(opts) term(unpack(opts.fargs)) end, {complete = 'shellcmd', nargs = '*'})

vim.api.nvim_create_augroup("term", { clear = true })
vim.api.nvim_create_autocmd("TermOpen", {
    group = "term",
    command = "setlocal nonumber norelativenumber nowrap",
})
