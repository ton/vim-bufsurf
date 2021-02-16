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
command BufSurfListAll :call <SID>BufSurfListAll()
command BufSurfClear :call <SID>BufSurfClear()

nnoremap <silent> <Plug>(buf-surf-back) :BufSurfBack<CR>
nnoremap <silent> <Plug>(buf-surf-forward) :BufSurfForward<CR>

" List of buffer names that we should not track.
let s:ignore_buffers = split(g:BufSurfIgnore, ',')

" Indicates whether the plugin is enabled or not.
let s:disabled = 0

" Clear the navigation history
function s:BufSurfClear()
    let w:history_index = -1
    let w:history = []
endfunction

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
            let l:buffer_name = "* >" . l:buffer_name
        else
            let l:buffer_name = "  >" . l:buffer_name
        endif
        let l:buffer_names = l:buffer_names + [l:buffer_name]
    endfor
    call s:BufSurfEcho("window buffer navigation history (* = current):" . join(l:buffer_names, "\n"))
endfunction

" Displays buffer navigation history for all windows in all tabs.
function s:BufSurfListAll()
    let name_lines = []

    for tab_info in gettabinfo()
        for win_id in tab_info.windows
            call add(name_lines, '')
            if win_getid() == win_id
                let cur_str = '* >'
            else
                let cur_str = '  >'
            endif
            let fmt_win = cur_str . 'tab: ' . tab_info.tabnr . ' window: ' . win_id2win(win_id)
            call add(name_lines, fmt_win)

            let history = gettabwinvar(tab_info.tabnr, win_id, 'history')
            let history_index = gettabwinvar(tab_info.tabnr, win_id, 'history_index')

            if type(history) != v:t_list
                continue
            endif

            for hist_idx in range(len(history))
                let name = bufname(history[hist_idx])
                if history_index == hist_idx
                    let cur_str = '  * >'
                else
                    let cur_str = '    >'
                endif
                let fmt_name = cur_str . name
                call add(name_lines, fmt_name)
            endfor
        endfor
    endfor

    call s:BufSurfEcho('window buffer nav hist (* = current):' . join(name_lines, "\n"))
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

    " Go into each window of each tab and remove the buffer from each window's history.
    for tab_info in gettabinfo()
        for win_idx in tab_info.windows
            let history = gettabwinvar(tab_info.tabnr, win_idx, 'history')
            if type(history) != v:t_list
                continue
            endif
            let history_index = gettabwinvar(tab_info.tabnr, win_idx, 'history_index')

            call filter(history, 'v:val != ' . a:bufnr)
            " Remove duplicate buffers that have been made adjacent from the deletion.
            call uniq(history)
            call settabwinvar(tab_info.tabnr, win_idx, 'history', history)

            " In case the current window history index is no longer valid, move it within boundaries.
            if history_index >= len(history)
                let history_index = len(history) - 1
                call settabwinvar(tab_info.tabnr, win_idx, 'history_index', history_index)
            endif
        endfor
    endfor
endfunction

" Echo a BufSurf message in the Vim status line.
function s:BufSurfEcho(msg)
    if g:BufSurfMessages == 1
        echohl WarningMsg
        let lines = split(a:msg, '\n')
        echomsg 'BufSurf: ' . lines[0]
        for l in lines[1:]
          echomsg l
        endfor
        echohl None
    endif
endfunction

" Setup the autocommands that handle MRU buffer ordering per window.
augroup BufSurf
  autocmd!
  autocmd BufEnter * :call s:BufSurfAppend(winbufnr(winnr()))
  autocmd WinEnter * :call s:BufSurfAppend(winbufnr(winnr()))
  autocmd BufWipeout * :call s:BufSurfDelete(str2nr(expand('<abuf>')))
augroup End
