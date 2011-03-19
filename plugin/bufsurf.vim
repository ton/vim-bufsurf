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

command BufSurfBack :call <SID>BufSurfBack(winnr())
command BufSurfForward :call <SID>BufSurfForward(winnr())

" Mapping from a window ID to a list of opened buffers.
let s:window_history = {}

" Mapping from a window ID to an index in the list of opened buffers.
let s:window_history_index = {}

" List of buffer names that we should not track.
let s:ignore_buffers = split(g:BufSurfIgnore, ',')

" Indicates whether the plugin is enabled or not. 
let s:disabled = 0

" Open the previous buffer in the navigation history for window identified by winnr.
function s:BufSurfBack(winnr)
    if s:window_history_index[a:winnr] > 0
        let s:window_history_index[a:winnr] -= 1
        let s:disabled = 1
        execute "b " . s:window_history[a:winnr][s:window_history_index[a:winnr]]
        let s:disabled = 0
    endif
endfunction

" Open the next buffer in the navigation history for window identified by winnr.
function s:BufSurfForward(winnr)
    if s:window_history_index[a:winnr] < len(s:window_history[a:winnr]) - 1
        let s:window_history_index[a:winnr] += 1
        let s:disabled = 1
        execute "b " . s:window_history[a:winnr][s:window_history_index[a:winnr]]
        let s:disabled = 0
    endif
endfunction

" Add the given buffer number to the navigation history for the window identified by winnr.
function s:BufSurfAppend(bufnr, winnr)
    if s:BufSurfIsDisabled(a:bufnr)
        return
    endif

    " In case no navigation history exists for the current window, initialize the navigation history.
    if !has_key(s:window_history, a:winnr)
        let s:window_history[a:winnr] = []
        let s:window_history_index[a:winnr] = 0
    " In case the newly added buffer is the same as the previously active buffer, ignore it.
    elseif s:window_history[a:winnr][s:window_history_index[a:winnr]] == a:bufnr
        return
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

        " In case the current window history index is no longer valid, move it within boundaries.
        if len(s:window_history[winnr]) == 0
            unlet s:window_history[winnr]
            unlet s:window_history_index[winnr]
        elseif s:window_history_index[winnr] >= len(s:window_history[winnr])
            let s:window_history_index[winnr] = len(s:window_history[winnr]) - 1
        endif
    endfor
endfunction

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

" Setup the autocommands that handle MRU buffer ordering per window.
augroup BufSurf
  autocmd!
  autocmd BufEnter * :call s:BufSurfAppend(winbufnr(winnr()), winnr())
  autocmd WinEnter * :call s:BufSurfAppend(winbufnr(winnr()), winnr())
  autocmd BufDelete * :call s:BufSurfDelete(winbufnr(winnr()))
augroup End
