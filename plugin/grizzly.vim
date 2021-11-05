
let g:loaded_grizzly = 1

if has('nvim') || !has('popupwin')
	finish
endif

call grizzly#init()

if !g:grizzly_disable_default_mappings
	tnoremap <silent><nowait><C-n>  <C-w>:call grizzly#complete_next()<cr>
	tnoremap <silent><nowait><C-p>  <C-w>:call grizzly#complete_prev()<cr>
endif

augroup grizzly
	autocmd!
	autocmd TerminalOpen,WinEnter * :call grizzly#reset_timer()
	autocmd WinLeave     *          :call grizzly#close_popupwins()
augroup END

