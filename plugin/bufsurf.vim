" bufsurf.vim
"
" MIT license applies, see LICENSE for licensing details.

if exists("g:loaded_bufsurfer")
    finish
endif

let g:loaded_bufsurfer = 1

command BufSurfBack :call <SID>BufSurfBack()
command BufSurfForward :call <SID>BufSurfForward()

" Show a warning in case Ruby is not available.
function! s:BufSurfRubyWarning()
  echohl WarningMsg
  echo "bufsurf.vim requires Vim to be compiled with Ruby support. For more information type :help bufsurf."
  echohl none
endfunction

" Vim to Ruby function calls.
function! s:BufSurfBack()
    if has('ruby')
        ruby $bufSurfer.back
    else
        call s:BufSurfRubyWarning()
    endif
endfunction

function! s:BufSurfForward()
    if has('ruby')
        ruby $bufSurfer.forward
    else
        call s:BufSurfRubyWarning()
    endif
endfunction

if !has('ruby')
  finish
endif

" Setup the autocommands that handle MRU buffer ordering per window.
augroup BufSurf
  autocmd!
  autocmd BufEnter * ruby $bufSurfer.append
  autocmd WinEnter * ruby $bufSurfer.append
  autocmd BufUnload * ruby $bufSurfer.delete
augroup End

ruby << EOF

class BufSurf
    def initialize
        @window_history = {}
        @window_navigation_index = {}

        # disabled is used to temporarily disable the append and delete methods that are also called when surfing through the buffer list.
        @disabled = false
    end

    def forward
        if @window_navigation_index[$curwin] < @window_history[$curwin].length - 1
            @window_navigation_index[$curwin] += 1
            @disabled = true
            VIM::command "b #{@window_history[$curwin][@window_navigation_index[$curwin]]}"
            @disabled = false
        end
    end

    def back
        if @window_navigation_index[$curwin] > 0
            @window_navigation_index[$curwin] -= 1
            @disabled = true
            VIM::command "b #{@window_history[$curwin][@window_navigation_index[$curwin]]}"
            @disabled = false
        end
    end

    def append
        return if @disabled

        # In case no navigation history exists for the current window, initialize the navigation history.
        if not @window_history.has_key?($curwin)
            @window_history[$curwin] = []
            @window_navigation_index[$curwin] = 0
        # In case the newly added buffer is the same as the previously active buffer, ignore it.
        elsif @window_history[$curwin][@window_navigation_index[$curwin]] == $curbuf.number
            return
        else
            @window_navigation_index[$curwin] += 1
        end
        @window_history[$curwin].insert(@window_navigation_index[$curwin], $curbuf.number)
    end

    def delete
        return if @disabled

        # Remove any history of the current buffer, and adjust the current navigation index accordingly. Use abuf here instead of curbuf, since for
        # the BufUnload event, the current buffer might not be equal to the buffer that is unloaded (abuf).
        buf_nr = VIM::evaluate('expand("<abuf>")')
        for i in 0..@window_navigation_index[$curwin]
            @window_navigation_index[$curwin] -= 1 if @window_history[$curwin][i] == buf_nr
        end
        @window_history[$curwin].delete(buf_nr)
    end
end

$bufSurfer = BufSurf.new

EOF
