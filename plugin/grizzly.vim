
let g:loaded_grizzly = 1

if has('popupwin')
	tnoremap <silent><nowait><C-n>  <C-w>:call grizzly#complete()<cr>
	tnoremap <silent><nowait><C-p>  <C-w>:call grizzly#complete()<cr>
endif
