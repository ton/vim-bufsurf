" bufsurf.vim
"
" MIT license applies, see LICENSE for licensing details.
if exists('g:loaded_bufsurfer')
    finish
endif

let g:loaded_bufsurfer = 1

" Initialises var to value in case the variable does not yet exist.
function s:InitVariable(var, value)
    if !exists(a:var)
        exec 'let ' . a:var . ' = ' . "'" . a:value . "'"
    endif
endfunction

call s:InitVariable('g:BufSurfIgnore', '')
call s:InitVariable('g:BufSurfMessages', 1)

command BufSurfBack :call <SID>BufSurfBack(winnr())
command BufSurfForward :call <SID>BufSurfForward(winnr())
command BufSurfList :call <SID>BufSurfList(winnr())

" Mapping from a window ID to a list of opened buffers.
let s:window_history = {}

" Mapping from a window ID to an index in the list of opened buffers.
let s:window_history_index = {}

" List of buffer names that we should not track.
let s:ignore_buffers = split(g:BufSurfIgnore, ',')

" Indicates whether the plugin is enabled or not. 
let s:disabled = 0

" Open the previous buffer in the navigation history for window identified by
" winnr.
function s:BufSurfBack(winnr)
    if s:window_history_index[a:winnr] > 0
        let s:window_history_index[a:winnr] -= 1
        let s:disabled = 1
        execute "b " . s:window_history[a:winnr][s:window_history_index[a:winnr]]
        let s:disabled = 0
    else
        call s:BufSurfEcho("reached start of window navigation history")
    endif
endfunction

" Open the next buffer in the navigation history for window identified by
" winnr.
function s:BufSurfForward(winnr)
    if s:window_history_index[a:winnr] < len(s:window_history[a:winnr]) - 1
        let s:window_history_index[a:winnr] += 1
        let s:disabled = 1
        execute "b " . s:window_history[a:winnr][s:window_history_index[a:winnr]]
        let s:disabled = 0
    else
        call s:BufSurfEcho("reached end of window navigation history")
    endif
endfunction

" Add the given buffer number to the navigation history for the window
" identified by winnr.
function s:BufSurfAppend(bufnr, winnr)
    " In case the specified buffer should be ignored, do not append it to the
    " navigation history of the window.
    if s:BufSurfIsDisabled(a:bufnr)
        return
    endif

    " In case no navigation history exists for the current window, initialize
    " the navigation history.
    if !has_key(s:window_history, a:winnr)
        " Add all buffers loaded for the current window to the navigation
        " history.
        let s:i = a:bufnr + 1
        let s:window_history[a:winnr] = []
        while bufexists(s:i)
            call add(s:window_history[a:winnr], s:i)
            let s:i += 1
        endwhile

        " Make sure that the current buffer will be inserted at the start of
        " the window navigation list.
        let s:window_history_index[a:winnr] = 0

    " In case the newly added buffer is the same as the previously active
    " buffer, ignore it.
    elseif s:window_history[a:winnr][s:window_history_index[a:winnr]] == a:bufnr
        return

    " Add the current buffer to the buffer navigation history list of the
    " current window.
    else
        let s:window_history_index[a:winnr] += 1
    endif

    let s:window_history[a:winnr] = insert(s:window_history[a:winnr], a:bufnr, s:window_history_index[a:winnr])
endfunction

" Remove buffer with number bufnr from all navigation histories.
function s:BufSurfDelete(bufnr)
    if s:BufSurfIsDisabled(a:bufnr)
        return
    endif

    " Remove the buffer from all window histories.
    for [winnr, buflist] in items(s:window_history)
        call filter(buflist, 'v:val !=' . a:bufnr)

        " In case the current window history index is no longer valid, move it
        " within boundaries.
        if len(s:window_history[winnr]) == 0
            unlet s:window_history[winnr]
            unlet s:window_history_index[winnr]
        elseif s:window_history_index[winnr] >= len(s:window_history[winnr])
            let s:window_history_index[winnr] = len(s:window_history[winnr]) - 1
        endif
    endfor
endfunction

" Displays buffer navigation history for the current window.
function s:BufSurfList(winnr)
    let l:buffer_names = []
    for l:bufnr in s:window_history[a:winnr]
        let l:buffer_name = bufname(l:bufnr)
        if bufnr("%") == l:bufnr
            let l:buffer_name .= "*"
        endif
        let l:buffer_names = l:buffer_names + [l:buffer_name]
    endfor
    call s:BufSurfEcho("window buffer navigation history (* = current): " . join(l:buffer_names, ', '))
endfunction

" Returns whether recording the buffer navigation history is disabled for the
" given buffer number *bufnr*.
function s:BufSurfIsDisabled(bufnr)
    if s:disabled
        return 1
    endif

    for bufpattern in s:ignore_buffers
        if match(bufname(a:bufnr), bufpattern) != -1
            return 1
        endif
    endfor

    return 0
endfunction

" Echo a BufSurf message in the Vim status line.
function s:BufSurfEcho(msg)
    if g:BufSurfMessages == 1
        echohl WarningMsg
        echomsg 'BufSurf: ' . a:msg
        echohl None
    endif
endfunction

" Setup the autocommands that handle MRU buffer ordering per window.
augroup BufSurf
  autocmd!
  autocmd BufEnter * :call s:BufSurfAppend(winbufnr(winnr()), winnr())
  autocmd WinEnter * :call s:BufSurfAppend(winbufnr(winnr()), winnr())
  autocmd BufDelete * :call s:BufSurfDelete(winbufnr(winnr()))
augroup End
