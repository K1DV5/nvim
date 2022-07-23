" term pane plugin
" Written by K1DV5
" depends on ./tabs.vim
"
" Constant(s):
let s:default_shell = exists('term_default_shell')? g:term_default_shell : &shell

" define command
command! -nargs=? -complete=shellcmd T call Term("<args>")

function! s:height(size) abort
	" if the size is less than 1, it will be taken as the fraction of the file
	" window
	if a:size > 1
		let l:term_height = a:size
	else
		if &buftype == 'terminal'
			let l:alt_window_id = nvim_list_wins()[index(nvim_list_wins(), bufwinid(@%)) - 1]
			let l:term_height = float2nr((winheight(l:alt_window_id) + winheight(0) + 1) * a:size)
		else
			let l:term_height = float2nr(winheight(0) * a:size) 
		endif
	endif	
	return l:term_height
endfunction

" get terminal buffers or windows
function! s:terminals(...) abort
    if a:0  " windows
        let list = nvim_list_wins()
        let Item = function('winbufnr')
    else  " buffers
        let list = nvim_list_bufs()
        let Item = {val -> val}
    endif
    return filter(list, {_, val -> getbufvar(Item(val), '&buftype') == 'terminal'})
endfunction

" find and go to terminal pane, return success
function! s:go() abort
	" terminal windows
	let l:tbufwins = s:terminals(1)
    " if there is a terminal window
    if l:tbufwins != []
        " go to that window
        call win_gotoid(l:tbufwins[0])
        return 1
    endif
    return 0
endfunction

function! s:toggle(size) abort
    " a:size - number | float - the desired size of the pane
	" work only if buffer is a normal file or a terminal
	if !&modifiable && &buftype != 'terminal'
        echo "Not a file buffer, aborting..."
		return 1
	endif
	let l:term_height = s:height(a:size)
	" if in terminal pane
	if &buftype == 'terminal'
		if winheight(0) < l:term_height " maximize
			execute 'resize' l:term_height
		else
			let g:term_current_buf = bufnr('%')
			hide
		endif
        return 1
    elseif s:go()
        return 1
    endif
    " terminal buffers
    let l:tbuflist = s:terminals()
    " if last opened terminal is hidden but exists
    if exists('g:term_current_buf') && buflisted(g:term_current_buf)
        execute 'belowright' l:term_height.'split +buffer\' g:term_current_buf
    elseif len(l:tbuflist) " choose one of the others
        execute 'belowright' l:term_height.'split +buffer\' l:tbuflist[0]
    else " create a new one
        return
    endif
    " bring other terminal buffers into this window
    let w:tabs_buflist = l:tbuflist
    return 1
endfunction

function! Term(cmd, ...)
    " a:cmd - string | number | float - the cmd name or the desired win height
    " if a:cmd is a number
    if index([v:t_number, v:t_float], type(a:cmd)) != -1
        if s:toggle(a:cmd)
            return
        endif
        let cmd = s:default_shell
    else
        let cmd = len(a:cmd) ? a:cmd : s:default_shell
    endif
    " NEW TERMINAL
	let l:term_height = s:height(0.3)
	" terminal buffer numbers like [1, 56, 78]
	let l:tbuflist = s:terminals()
    " same command terminal buffers
    let dir = a:0 ? a:1 : fnamemodify('.', ':p')
    let buf_name = 'term://'.substitute(dir, '[\/]\+$', '', '').'//'.cmd
    if &buftype == 'terminal' || s:go()
        " open a new terminal
        execute 'edit' buf_name
    else
        " create a new terminal in split
        execute 'belowright' l:term_height.'split '.buf_name
        " bring other terminal buffers into this window
        let w:tabs_buflist = l:tbuflist
        if a:cmd == 1
            let l:term_height = s:height(a:cmd)
            if winheight(0) < l:term_height " maximize
                execute 'resize' l:term_height
            endif
        endif
    endif
    tnoremap <buffer> <cr> <cmd>call timer_start(500, 'RenameTerm')<cr><cr>
    tnoremap <buffer> <c-c> <cmd>call timer_start(500, 'RenameTerm')<cr><c-c>
	" if the cmd has argumets, delete existing with the same cmd
    if cmd =~ '\s'
        for buf in l:tbuflist
            let name = substitute(bufname(buf), '//\d\+:', '//', '')
            if name == buf_name
                execute 'bdelete!' buf
            endif
        endfor
    endif
    lua tabs_reload()
endfunction

" use the current process in the terminal as the buffer name
function! RenameTerm(timer)
    try
        let pid = jobpid(&channel)
    catch  " the job ended
        return
    endtry
    let current_name = bufname()
    let cmd_part = substitute(current_name, 'term:\/\/.*\/\/\d\+:', '', '')
    if cmd_part =~ ' ' || &buftype != 'terminal' " dont rename one with a space or a normal file
        return
    endif
    let child = pid
    while child
        let ch = nvim_get_proc_children(child)
        if len(ch) == 1
            let child = ch[0]
        else
            break
        endif
    endwhile
    let name = substitute(nvim_get_proc(child)['name'], '.exe', '', '')
    if name == cmd_part " to prevent unnecessary unlisted buffer creation
        return
    endif
    let begin = 'term://'
    let dirstart = len(begin)
    let dir_part = current_name[dirstart: stridx(current_name, '//', dirstart) - 1]
    let new_name = begin.dir_part.'//'.child.':'.name
    execute 'file '.new_name
    " execute 'bwipeout!' bufnr(@#)
endfunction

augroup term
    autocmd!
    " remove line numbers from the terminal windows and offsets
    autocmd TermOpen * setlocal nonumber norelativenumber nowrap
    autocmd TermResponse * echo v:termresponse
augroup END
