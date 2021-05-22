
let g:loaded_grizzly = 1

if has('popupwin')
	if !get(g:, 'grizzly_disable_default_mappings', v:false)
		tnoremap <silent><nowait><C-n>  <C-w>:call grizzly#complete_next()<cr>
		tnoremap <silent><nowait><C-p>  <C-w>:call grizzly#complete_prev()<cr>
	endif
endif

if exists('*timer_start')
	augroup grizzly
		autocmd!
		autocmd TerminalOpen * :call grizzly#reset_timer()
	augroup END
endif
