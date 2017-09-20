" sorter_bufsurf.vim
"
" MIT license applies, see LICENSE for licensing details.

let s:save_cpo = &cpo
set cpo&vim

function! unite#filters#sorter_bufsurf#define() "{{{
  return s:sorter
endfunction"}}}

let s:sorter = {
    \  'name': 'sorter_bufsurf',
    \  'description': 'sorts buffers to match with bufsurf history',
    \}

" bufsurf filter implementation.
"
" Filter expects candidate containing key `action__buffer_nr` (any other
" candidates are filtered out). Filter converts `w:history` variable
" mantained by bufsurf into list of matching candidates (matched by
" value of `candidate.action__buffer_nr`). Any buffer from `w:history`
" missing in candidates list is filtered out.
"
" Filter also preselects current buffer in resulting list (if selection
" wasn't explicitly set by user through `:Unite` option) according to variable
" `w:history_index` maintained by bufsurf.
function! s:sorter.filter(candidates, context) "{{{
  let l:window = winnr('#')
  let l:history = getwinvar(l:window, 'history', [])
  let l:history_index = getwinvar(l:window, 'history_index')
  let l:history_buffers =
      \ s:history_buffers(l:history, a:candidates, l:history_index)
  call s:preselect_current_buffer(l:history_buffers, a:context)
  " Get only those buffers from history that existed in candidates.
  return filter(map(l:history_buffers, 'v:val[0]'), 'v:val isnot 0')
endfunction"}}}

" Convert `w:history` variable into list of tuples consisting of buffer
" candidate and flag showing whether `w:history_index` points to this buffer.
function! s:history_buffers(history, candidates, history_index) "{{{
  " Make dictionary where number of buffer is mapped to candidate from
  " candidates list.
  let l:numbered_buffers = {}
  for l:candidate in a:candidates
    " If it doesn't have `action__buffer_nr`, it's not a buffer candidate (or,
    " at least, it's not a candidate from stock buffer source).
    if has_key(l:candidate, 'action__buffer_nr')
      let l:numbered_buffers[candidate.action__buffer_nr] = candidate
    endif
  endfor
  " Map `w:history` element to
  " `[matching_buffer_candidate_or_zero, element_is_the_current_buffer]`.
  return map(
         \ copy(a:history),
         \ '[get(l:numbered_buffers, v:val), (v:key == a:history_index)]')
endfunction"}}}

" Set `context.select` to index of current buffer.
function! s:preselect_current_buffer(history_buffers, context) "{{{
  " Context passed in arguments could be either a reference to real context or
  " a reference to its' copy. We need to change real context, so take
  " a guaranteed reference to it.
  let l:ctx = unite#get_context()
  " If `context.select` is set to 0 or positive number, it was probably
  " already explicitly set by user through `-select` Unite option, so default
  " behavior should be skipped.
  if l:ctx.select >= 0 | return | endif
  " Try to find current buffer amongst candidates and preselect it by setting
  " `context` value.
  let l:ctx.select = 0
  for [l:_, l:is_current_buffer] in a:history_buffers
    unlet! l:_ " because it could be of different types
    if !l:is_current_buffer
      let l:ctx.select += 1
      continue
    endif
    " When Unite is invoked with `-no-split` option, it shows up as a buffer
    " in current window and this Unite buffer is put in `w:history`. However,
    " this buffer isn't included in candidates returned by stock buffer
    " source. Here this situation is handled by selecting previous buffer in
    " history.
    while (l:ctx.select > -1) && (a:history_buffers[l:ctx.select][0] is 0)
      let l:ctx.select -= 1
    endwhile
    " Selection is set, so return early.
    return
  endfor
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
