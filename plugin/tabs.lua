local devicons = require'nvim-web-devicons'

function get_icon()
    if vim.api.nvim_buf_get_option(0, 'buftype') == 'terminal' then
        local icon, hi = devicons.get_icon('', 'terminal')
        return {icon, hi}
    end
    local fname = vim.fn.expand('%')
    local ext = vim.fn.expand('%:e')
    local icon, hi = devicons.get_icon(fname, ext)
    if icon == nil then
        return {'', 'Normal'}
    end
    return {icon, hi}
end

local function get_winvar(win, name)
    local ok, value = pcall(vim.api.nvim_win_get_var, win, name)
    if ok then
        return value
    end
end

local function get_alt_buf(win)  -- get the alternate buffer for the given window
    local bufs = get_winvar(win, 'tabs_buflist') or {}
    local l_bufs = vim.tbl_count(bufs)
    if l_bufs < 2 then
        return
    end
    local alt = get_winvar(win, 'tabs_alt_file') or 0
    local current = vim.api.nvim_win_get_buf(win)
    if vim.tbl_contains(bufs, alt) and alt ~= current then
        return alt
    end
    for i, buf in pairs(bufs) do
        if buf == current then
            if i == l_bufs - 1 then -- last, return first
                return bufs[0]
            end
            return bufs[i]  -- next
        end
    end
end

local function get_alt_win(win)
    local alt = vim.api.nvim_win_get_var(win, 'tabs_alt_win') or 0  -- win id, not winnr
    local wins = vim.api.nvim_list_wins()  -- win ids, not numbers
    if index(wins, alt_win) ~= -1 then
        return alt_win
    end
    local l_wins = vim.tbl_count(wins)
    if l_wins < 2 then
        return
    end
    -- find the next one
    local win = win_getid(win)
    local i_win = index(wins, win)
    -- assuming win is in wins
    if i_win == l_wins - 1 then
        return wins[0]
    end
    return wins[i_win + 1]
end

function tabs_status_text()
    local bufnr = vim.api.nvim_get_current_buf()
    local win = vim.fn.bufwinid(bufnr)
    local bufs = vim.api.nvim_win_get_var(win, 'tabs_buflist') or {bufnr}
    local text = '%<%#StatuslineNC#'
    local is_current_win = vim.api.nvim_get_current_win() == win
    local alt = get_alt_buf(win)  -- alternate buffer for the current win
    for i, buf in pairs(bufs) do
        local name = vim.api.nvim_buf_get_name(buf)
        if name then
            name = vim.fn.fnamemodify(name, ':t')
        else
            name = '[No name]'
        end
        if buf == bufnr then  -- current buf
            local icon
            if is_current_win then
                local iconhl = get_icon()
                local hl_icon = '%#' .. iconhl[2] .. '#'
                icon = hl_icon .. ' ' .. iconhl[1] .. ' '
            else
                icon = '%#Normal# %{v:lua.get_icon()[0]} '
            end
            text = text .. icon .. '%#Normal#' .. name .. '%m %#StatuslineNC#'
        else
            local num
            if not is_current_win then
                num = ''
            elseif buf == alt then
                num = '# '
            else
                num = i .. ':'
            end
            text = text .. ' ' .. num .. name .. ' '
        end
    end
    return text
end
