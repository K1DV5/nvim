"
" setlocal statusline is local to buffer, not window based!
" winid based
"     same buffer opened in another window may have a different stl
"     opening and closing the window containing the buffer can change the stl
"     NO!

" winnr based
"     opening and closing another window can change the winnr of the current one
"         misaligned stl
"     NO!

" buffer based
"     same file open in two windows will show both windows as active and same statusline as the new split
"     YES

" config vars:
" g:tabs_statusline_add - additional things to add to statusline
" g:tabs_custom_stl - list of filetypes to show in place of mode

lua << EOF
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
EOF

function! TabsStatusText()
    " get the section of the tabs
    let bufnr = bufnr()
    let win = bufwinid(bufnr)
    let bufs = getwinvar(win, 'tabs_buflist', [bufnr])
    let text = '%<%#StatuslineNC#'
    let i_buf = 1
    let is_current_win = win_getid() == win
    let i_this = index(bufs, bufnr)
    let alt = s:get_alt_buf(win)  " alternate buffer for the current win
    for buf in bufs
        let name = bufname(buf)
        let name = len(name) ? fnamemodify(name, ':t') : '[No name]'
        if buf == bufnr  " current buf
            if is_current_win
                let [icon, hl_icon] = v:lua.get_icon()
                let hl_icon = '%#' . hl_icon . '#'
                let icon = hl_icon . ' ' . icon . ' '
            else
                let icon = '%#Normal# %{v:lua.get_icon()[0]} '
            endif
            let text .= icon . '%#Normal#' . name . '%m %#StatuslineNC#'
        else
            let num = is_current_win ? (buf == alt ? '# ' : i_buf . ':') : ''
            let text .= ' ' . num . name . ' '
        endif
        let i_buf += 1
    endfor
    return text
endfunction

" ======================== Public Functions ============================

function! TabsReload()
    let buf = bufnr()
    if exists('w:tabs_buflist')
        call filter(w:tabs_buflist, {_, buf -> buflisted(buf)})  " maybe removed
        if index(w:tabs_buflist, buf) == -1  " maybe added
            call add(w:tabs_buflist, buf)
        endif
    elseif bufname(buf) == '' && !getbufvar(buf, '&modified')  " empty
        let w:tabs_buflist = []
    else
        let w:tabs_buflist = [buf]
    endif
    " redrawstatus
endfunction

function! TabsAllBuffers() abort
    let w:tabs_buflist = []
    for buf in range(1, bufnr('$'))
        let empty = bufname(buf) == '' && !getbufvar(buf, '&modified')
        if bufexists(buf) && !empty
            call add(w:tabs_buflist, buf)
        endif
    endfor
    call TabsReload()
endfunction

function! TabsNext()
    " cycle through tabs
    if len(w:tabs_buflist) < 2  " too few tabs
        return
    endif
    let buf = bufnr(@%)
    let i_buf = index(w:tabs_buflist, buf)
    if i_buf == len(w:tabs_buflist) - 1
        let i_next = 0
    else
        let i_next = i_buf + 1
    endif
    call nvim_set_current_buf(w:tabs_buflist[i_next])
endfunction

function! s:get_alt_buf(win)  " get the alternate buffer for the given window
    let bufs = getwinvar(a:win, 'tabs_buflist', [])
    let l_bufs = len(bufs)
    if l_bufs < 2
        return
    endif
    let alt = getwinvar(a:win, 'tabs_alt_file', 0)
    let i_alt = index(bufs, alt)
    let current = winbufnr(a:win)
    if i_alt == -1 || alt == current
        let i_current = index(bufs, current)
        if i_current == l_bufs - 1 " last, return first
            return bufs[0]
        endif
        return bufs[i_current + 1]  " next
    endif
    return alt
endfunction

function! s:get_alt_win(win)
    let alt_win = get(g:, 'tabs_alt_win', 0)  " win id, not winnr
    let wins = nvim_list_wins()  " win ids, not numbers
    if index(wins, alt_win) != -1
        return alt_win
    endif
    let l_wins = len(wins)
    if l_wins < 2
        return
    endif
    " find the next one
    let win = win_getid(a:win)
    let i_win = index(wins, win)
    " assuming win is in wins
    if i_win == l_wins - 1
        return wins[0]
    endif
    return wins[i_win + 1]
endfunction

function! TabsGo(where)
    " go to the specified buffer or win
    if type(a:where) == v:t_float  " win
        let where = float2nr(a:where)
        if where  " jump to alt
            call win_gotoid(win_getid(where))
        else
            call win_gotoid(s:get_alt_win(winnr()))
        endif
    else  " buffer
        " jump through the tabs
        let last = bufnr()
        if !a:where  " alt
            let alt = s:get_alt_buf(winnr())
            if alt
                call nvim_set_current_buf(alt)
            endif
        else  " to is an index + 1 (shown on the bar)
            if a:where <= len(w:tabs_buflist)
                call nvim_set_current_buf(w:tabs_buflist[a:where - 1])
            else
                echo 'No buffer at ' . (a:where)
            endif
        endif
        if last != bufnr()
            let w:tabs_alt_file = last
        else
            let w:tabs_alt_file = bufnr()
        endif
    endif
endfunction

function! TabsClose()
    " close current tab
    if &modified
        echo "File modified"
        return
    endif
    let bang = &buftype == 'terminal' ? '!' : ''
    let alt = s:get_alt_buf(winnr())
    if alt
        let to_del = bufnr()
        call nvim_set_current_buf(alt)
        execute 'bdelete'.bang to_del
        call TabsReload()
    else
        execute 'bdelete'.bang
    endif
endfunction

augroup Tabs
    autocmd!
    autocmd BufRead,BufNewFile,FileType,TermOpen * call TabsReload()
    " save the current window number before jumping to jump back, redrawing
    " the statusline to show which is the alt
    autocmd WinLeave * let g:tabs_alt_win = win_getid()
augroup END
