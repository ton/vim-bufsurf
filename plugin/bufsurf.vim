if exists('g:loaded_bufsurfer')
    finish
endif

let g:loaded_bufsurfer = 1

command -nargs=0 BufSurfBack         :call <SID>BufSurfBack()
command -nargs=0 BufSurfForward      :call <SID>BufSurfForward()
command -nargs=0 BufSurfHistory      :call <SID>BufSurfHistory()
command -nargs=0 BufSurfHistoryClear :call setloclist(0, [], 'r')

let g:BufSurfMessages = exists('g:BufSurfMessages') ? g:BufSurfMessages : 1
let g:BufSurfClearHistory = exists('g:BufSurfClearHistory') ? g:BufSurfClearHistory : 1
let s:ignore_buffers = exists('g:BufSurfIgnore') ? split(g:BufSurfIgnore, ',') : []

function! <SID>BufSurfBack()
	if ! exists('w:bufsurf_offset')
		let w:bufsurf_offset = 0
	endif
	if w:bufsurf_offset < len(getloclist(0)) - 1
		let w:bufsurf_offset += 1
		lnext
	else
		call s:BufSurfEcho("reached end of window navigation history")
	endif
endfunction

function! <SID>BufSurfForward()
	if ! exists('w:bufsurf_offset') || w:bufsurf_offset < 0
		let w:bufsurf_offset = 0
	endif
	if w:bufsurf_offset > 0
		let w:bufsurf_offset -= 1
		lprevious
	else
		call s:BufSurfEcho("reached start of window navigation history")
	endif
endfunction

function! <SID>BufSurfUpdateOffset()
	let g:bufsurf_offset = line('.') - 1
	call feedkeys("\<CR>", 'n')
endfunction

function! <SID>BufSurfHistory()
	" this workaround is needed, because it's impossible to tell whether the
	" location or the quickfix windows was opened
	lopen
	nnoremap <buffer> <silent> <CR> :call <SID>BufSurfUpdateOffset()<CR>
endfunction

function! s:BufSurfAppend(bufnr)
	if ! exists('w:bufsurf_offset')
		let w:bufsurf_offset = 0
	endif

	" workaround for transporting the new offset from the locationlist window
	" to the current window
	let l:bufsurf_offset_old = -1
	if exists('g:bufsurf_offset')
		let l:bufsurf_offset_old = w:bufsurf_offset
		let w:bufsurf_offset = g:bufsurf_offset
		unlet g:bufsurf_offset
	endif

	let l:bn = bufname(a:bufnr)
	if &buftype == 'quickfix' || l:bn == ''
		return
	endif

	for n in s:ignore_buffers
		if match(l:bn, n) == -1
			return
		endif
	endfor

	let l:loclist = getloclist(0)
	if len(l:loclist) <= w:bufsurf_offset
		let w:bufsurf_offset = 0
	endif

	if len(l:loclist) == 0 || l:loclist[w:bufsurf_offset]['bufnr'] != a:bufnr
		if l:bufsurf_offset_old >= 0 && l:loclist[l:bufsurf_offset_old]['bufnr'] == a:bufnr
			" when selecting an item in the locationlist this function is
			" also triggered when entering the current (old) buffer. This
			" should not lead to a new item in surf history
			return
		elseif w:bufsurf_offset > 0 && len(l:loclist) > w:bufsurf_offset && l:loclist[w:bufsurf_offset - 1]['bufnr'] == a:bufnr
			" the same buffer can not be appended in history in consecutive order
			return
		endif

		" insert new entry in history
		call setloclist(0, insert(l:loclist, {'bufnr': a:bufnr, 'filename': 3, 'lnum': line('.'), 'text': strftime('%Y-%m-%d %H:%M:%S')}, w:bufsurf_offset), 'r')

		" workaround be on the right loclist item after updateing the
		" loclist; variable is interpreted by function s:BufSurfJump()
		if w:bufsurf_offset != 0
			let w:bufsurf_go = w:bufsurf_offset + 1
		endif
	endif
endfunction

function! s:BufSurfJump()
	if exists('w:bufsurf_go')
		let l:go = w:bufsurf_go
		unlet w:bufsurf_go
		exec ':ll ' . l:go
	endif
endfunction

function s:BufSurfEcho(msg)
    if g:BufSurfMessages == 1
        echohl WarningMsg
        echomsg 'BufSurf: ' . a:msg
        echohl None
    endif
endfunction

augroup BufSurf
	autocmd!
	autocmd BufEnter * :call s:BufSurfAppend(winbufnr(winnr())) | call s:BufSurfJump()
	autocmd WinEnter * :if exists('w:bufsurf_offset') == 0 && exists('g:BufSurfClearHistory') && g:BufSurfClearHistory != 0 | exec 'BufSurfHistoryClear' | call s:BufSurfAppend(winbufnr(winnr())) | call s:BufSurfJump() | endif
	" TODO maybe BufWipeout should be implemented. The downside is that only
	" for the current window it makes sense to clean up the history. Better
	" use :bd instead of :bw - that solves the problem
augroup End
