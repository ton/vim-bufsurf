" bufsurf.vim
"
" MIT license applies, see LICENSE for licensing details.
if exists('g:loaded_bufsurf')
    finish
endif

let g:loaded_bufsurf = 1

" Initialises var to value in case the variable does not yet exist.
function s:InitVariable(var, value)
    if !exists(a:var)
        exec 'let ' . a:var . ' = ' . "'" . a:value . "'"
    endif
endfunction

call s:InitVariable('g:BufSurfIgnore', '')
call s:InitVariable('g:BufSurfMessages', 1)

command BufSurfBack :call <SID>BufSurfBack()
command BufSurfForward :call <SID>BufSurfForward()
command BufSurfList :call <SID>BufSurfList()

" List of buffer names that we should not track.
let s:ignore_buffers = split(g:BufSurfIgnore, ',')

" Indicates whether the plugin is enabled or not. 
let s:disabled = 0

" Open the previous buffer in the navigation history for the current window.
function s:BufSurfBack()
    if w:history_index > 0
        let w:history_index -= 1
        let s:disabled = 1
        execute "b " . w:history[w:history_index]
        let s:disabled = 0
    else
        call s:BufSurfEcho("reached start of window navigation history")
    endif
endfunction

" Open the next buffer in the navigation history for the current window.
function s:BufSurfForward()
    if w:history_index < len(w:history) - 1
        let w:history_index += 1
        let s:disabled = 1
        execute "b " . w:history[w:history_index]
        let s:disabled = 0
    else
        call s:BufSurfEcho("reached end of window navigation history")
    endif
endfunction

" Add the given buffer number to the navigation history for the window
" identified by winnr.
function s:BufSurfAppend(bufnr)
    " In case the specified buffer should be ignored, do not append it to the
    " navigation history of the window.
    if s:BufSurfIsDisabled(a:bufnr)
        return
    endif

    " In case no navigation history exists for the current window, initialize
    " the navigation history.
    if !exists('w:history_index')
        " Make sure that the current buffer will be inserted at the start of
        " the window navigation list.
        let w:history_index = 0
        let w:history = []

        " Add all buffers loaded for the current window to the navigation
        " history.
        let s:i = a:bufnr + 1
        while bufexists(s:i)
            call add(w:history, s:i)
            let s:i += 1
        endwhile

    " In case the newly added buffer is the same as the previously active
    " buffer, ignore it.
    elseif w:history_index != -1 && w:history[w:history_index] == a:bufnr
        return

    " Add the current buffer to the buffer navigation history list of the
    " current window.
    else
        let w:history_index += 1
    endif

    " In case the buffer that is being appended is already the next buffer in
    " the history, ignore it. This happens in case a buffer is loaded that is
    " also the next buffer in the forward browsing history. Thus, this
    " prevents duplicate entries of the same buffer occurring next to each
    " other in the browsing history.
    let l:is_buffer_listed = (w:history_index != len(w:history) && w:history[w:history_index] == a:bufnr)

    if !l:is_buffer_listed
        let w:history = insert(w:history, a:bufnr, w:history_index)
    endif
endfunction

" Displays buffer navigation history for the current window.
function s:BufSurfList()
    let l:buffer_names = []
    for l:bufnr in w:history
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

" Remove buffer with number bufnr from all navigation histories.
function s:BufSurfDelete(bufnr)
    if s:BufSurfIsDisabled(a:bufnr)
        return
    endif

    " Remove the buffer from all window histories.
    call filter(w:history, 'v:val !=' . a:bufnr)

    " In case the current window history index is no longer valid, move it within boundaries.
    if w:history_index >= len(w:history)
        let w:history_index = len(w:history) - 1
    endif
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
  autocmd BufEnter * :call s:BufSurfAppend(winbufnr(winnr()))
  autocmd WinEnter * :call s:BufSurfAppend(winbufnr(winnr()))
  autocmd BufWipeout * :call s:BufSurfDelete(winbufnr(winnr()))
augroup End
