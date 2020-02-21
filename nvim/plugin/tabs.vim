" config vars:
" g:tabs_statusline_add - additional things to add to statusline
" g:tabs_custom_stl - list of filetypes to show in place of mode

function! StatusLine(bufnr)
    " this is what is set in the autocmds
    let hi_stat = a:bufnr == bufnr() ? '%#Tabs_Status#' : '%#Tabs_Status_NC#'
    let tabs_section = '%<%#StatusLineNC#' . TabsGetBufsText(a:bufnr)  " tabs
    let ft = getbufvar(a:bufnr, '&filetype')
    if exists('g:tabs_custom_stl') && has_key(g:tabs_custom_stl, ft)  " custom buffer
        let custom = substitute(g:tabs_custom_stl[ft], ':tabs\>', tabs_section, '')
        return hi_stat . ' %{&filetype} %#StatusLineNC# ' . custom " filetype and custom
    endif
    let bt = getbufvar(a:bufnr, '&buftype')
    if len(bt) && bt != 'terminal'
        return hi_stat . ' ' . toupper(bt) . ' ' . tabs_section . '%*'  " buftype and tabs
    endif
    let text = hi_stat . ' %{toupper(mode())} ' . tabs_section  " mode and tabs
    let text .= hi_stat . '%= ' " custom highlighting and right align
    if bt == 'terminal'
        return text . toupper(bt) . ' '
    endif
    return text . get(g:, 'tabs_statusline_add', '')  " with additional from user
endfunction

function! TabsGetBufsText(bufnr)
    " get the section of the tabs
    let win = bufwinid(a:bufnr)
    let bufs = getwinvar(win, 'tabs_buflist')
    if !len(bufs)
        let bufs = [a:bufnr]
    endif
    let text = ''
    let i_buf = 1
    let is_current_win = win_getid() == win
    for buf in bufs
        let name = bufname(buf)
        let name = len(name) ? fnamemodify(name, ':t') : '[No name]'
        if buf == a:bufnr
            let text .= '%#TabLineSel# %{&filetype!=""?WebDevIconsGetFileTypeSymbol() . " ":""}' . name . '%m %*'
        else
            let num = is_current_win ? i_buf . ':' : ''
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

function! TabsGo(where)
    " jump through the tabs
    let last = bufnr()
    if !a:where  " jump to alt
        if exists('w:tabs_buflist')
            if !exists('w:tabs_alt_file') || index(w:tabs_buflist, w:tabs_alt_file) == -1 || w:tabs_alt_file == last
                call TabsNext()
            else
                call nvim_set_current_buf(w:tabs_alt_file)
            endif
        else
            echo 'Unchartered waters!'
        endif
    elseif a:where < 0  " a:where is a bufnr
        call nvim_set_current_buf(-a:where)
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
endfunction

function! TabsClose()
    " close current tab
    let bang = &buftype == 'terminal' ? '!' : ''
    let to_go = exists('w:tabs_alt_file') ? index(w:tabs_buflist, w:tabs_alt_file) : -1
    if to_go == -1  " alt file closed
        let to_go = index(w:tabs_buflist, bufnr()) - 1
        if to_go < 0
            if len(w:tabs_buflist) < 2  " last buffer, just close
                execute 'bdelete' . bang
                return
            endif
            let to_go += 2  " to the right
        endif
    endif
    call TabsGo(to_go)  " to the alt file
    execute 'bdelete'.bang w:tabs_alt_file
    call TabsReload()
endfunction

" add the filetype and fileformat to the <c-g>
noremap <c-g> <cmd>file <bar> echon '  ft:'.&filetype '  eol:'.&fileformat<cr>

" highlightings used
hi Tabs_Status guifg=white guibg=#0A7ACA
hi link Tabs_Status_NC StatusLine
hi Tabs_Error guifg=black guibg=red
hi Tabs_Warning guifg=black guibg=yellow

function! s:OnNew() abort
    if get(b:, 'tabs_status_set', 0)
        " already set
        return
    endif
    let b:tabs_status_set = 0
    execute 'setlocal statusline=%!StatusLine(' . bufnr() .')'
    call TabsReload()
    let alt = bufnr('#')
    if index(w:tabs_buflist, alt) != -1  " for when closing just after opening
        let w:tabs_alt_file = alt
    endif
endfunction

augroup Tabs
    autocmd!
    autocmd BufRead,BufNewFile,FileType,TermOpen * call s:OnNew()
augroup END