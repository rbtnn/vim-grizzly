
let g:loaded_grizzly = 1

if has('popupwin')
	if !get(g:, 'grizzly_disable_default_mappings', v:false)
		tnoremap <silent><nowait><C-n>  <C-w>:call grizzly#complete()<cr>
		tnoremap <silent><nowait><C-p>  <C-w>:call grizzly#complete()<cr>
	endif
endif

if exists('*timer_start')
	call timer_start(500, 'grizzly#complete_t', { 'repeat': -1 })
endif
