" bufsurf.vim
"
" MIT license applies, see LICENSE for licensing details.

let s:save_cpo = &cpo
set cpo&vim

function! unite#sources#bufsurf#define()
  return s:source
endfunction

" Basically, just stock Unite buffer source with changed sorter.
let s:source = deepcopy(unite#get_all_sources('buffer'))
let s:source.name = 'bufsurf'
let s:source.description = 'candidates from bufsurf history'
let s:source.sorters = ['sorter_bufsurf']

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
