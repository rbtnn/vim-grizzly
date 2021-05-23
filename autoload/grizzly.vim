
let s:complete_winid = get(s:, 'complete_winid', -1)
let s:complete_t_winid = get(s:, 'complete_t_winid', -1)
let s:complete_t_cache = get(s:, 'complete_t_cache', { 'key' : '', 'items' : [], })
let g:grizzly_history = get(g:, 'grizzly_history', '~/.grizzly_history')

function! grizzly#complete_next() abort
	call s:complete(v:false)
endfunction

function! grizzly#complete_prev() abort
	call s:complete(v:true)
endfunction

function! grizzly#reset_timer() abort
	if exists('s:timer')
		call timer_stop(s:timer)
		unlet s:timer
	endif
	if !empty(term_list())
		let s:timer = timer_start(500, function('s:complete_t'), { 'repeat': -1 })
	endif
endfunction

function! s:complete_t(...) abort
	if get(g:, 'grizzly_disable', v:false)
		return
	endif
	call popup_close(s:complete_t_winid)
	let s:complete_t_winid = -1
	if -1 != s:complete_winid
		return
	endif
	if &buftype != 'terminal'
		return
	endif
	let input = s:prompt_input(term_getline(bufnr(), '.'))
	if empty(input)
		let items = s:cmdprompt_suggestions(input)
	elseif s:complete_t_cache['key'] != input
		let items = s:cmdprompt_suggestions(input)
		let s:complete_t_cache['key'] = input
		let s:complete_t_cache['items'] = items
	else
		let items = s:complete_t_cache['items']
	endif
	if len(items) < 1
		return
	elseif (len(items) == 1) && (items[0] == input)
		return
	endif
	let s:complete_t_winid = popup_create(items, {})
	call s:setoptions(s:complete_t_winid)
endfunction

function! s:complete(bot) abort
	if get(g:, 'grizzly_disable', v:false)
		return
	endif
	let input = s:prompt_input(term_getline(bufnr(), '.'))
	let items = s:cmdprompt_suggestions(input)
	if 0 < len(items)
		call s:settermline(-1, items[(a:bot ? -1 : 0)])
		if 1 < len(items)
			let s:complete_winid = popup_menu(items, {
				\ 'filter' : function('s:filter'),
				\ 'callback' : function('s:callback'),
				\ })
			call s:setoptions(s:complete_winid)
			if a:bot
				call s:setcursor(s:complete_winid, line('$', s:complete_winid))
			endif
		endif
	endif
endfunction

function! s:setoptions(winid) abort
	let curpos = term_getcursor(bufnr())
	let winpos = win_screenpos(winnr())
	let col = winpos[1] - 1 + s:prompt_length()
	let line = winpos[0] + curpos[0]
	let height = winheight(a:winid)
	if &lines < line + height
		let line -= height + 1
		if line < 0
			let height += line - 1
			let line = 1
		endif
	endif
	call popup_setoptions(a:winid, {
		\ 'minwidth' : &pumwidth,
		\ 'maxheight' : height,
		\ 'border' : [ 0, 0, 0, 0],
		\ 'padding' : [ 0, 1, 0, 1],
		\ 'pos' : 'topleft',
		\ 'line' : line,
		\ 'col' : col,
		\ })
endfunction

function! s:prompt_pattern() abort
	return get(g:, 'grizzly_prompt_pattern', has('win32') ? '^[A-Z]:\\.*>\zs.*' : '^[\$#]\zs.*')
endfunction

function! s:prompt_length() abort
	let line = term_getline(bufnr(), '.')
	let n = len(matchstr(line, s:prompt_pattern()))
	return len(line) - n
endfunction

function! s:prompt_input(line) abort
	return trim(matchstr(a:line, s:prompt_pattern()))
endfunction

function! s:cmdprompt_suggestions(input) abort
	let caches = []
	if filereadable(expand(g:grizzly_history))
		let caches = readfile(expand(g:grizzly_history))
	endif

	let lines = getbufline(bufnr(), 1, line('$') - 1)
		\ + map(range(1, line('$') - 1), { i,x -> term_getline(bufnr(), x) })
	call map(lines, { i, x -> s:prompt_input(x) })
	if -1 == index(caches, a:input)
		call filter(lines, { i,x -> (x != a:input) })
	endif

	let merge_lines = caches + lines
	for j in range(len(merge_lines) - 1, 0, -1)
		for k in range(j - 1, 0, -1)
			if merge_lines[j] == merge_lines[k]
				let merge_lines[k] = ''
			endif
		endfor
	endfor

	call filter(merge_lines, { i,x -> !empty(x) && (x !~# '^cd ') })
	call writefile(merge_lines, expand(g:grizzly_history))
	call filter(merge_lines, { i,x -> -1 != stridx(x, a:input) })
	return merge_lines
endfunction

function! s:setcursor(winid, lnum) abort
	call win_execute(a:winid, printf('call setpos(".", [0, %d, 1, 0])', a:lnum))
endfunction

function! s:settermline(winid, line) abort
	if has('win32')
		call term_sendkeys(bufnr(), "\<esc>")
	else
		call term_sendkeys(bufnr(), "\<C-u>")
	endif
	sleep 10m
	if -1 != a:winid
		call s:setoptions(a:winid)
	endif
	call term_sendkeys(bufnr(), a:line)
endfunction

func s:xxx(winid, lines, i)
	call s:setcursor(a:winid, a:i + 1)
	call s:settermline(a:winid, a:lines[(a:i)])
	return 1
endfunction

func s:filter(winid, key)
	let n = char2nr(a:key)
	let lines = getbufline(winbufnr(a:winid), 1, '$')

	if n == 27
		" Esc
		call popup_close(a:winid)
		return 1

	elseif n == 21
		" Ctrl-u
		call s:settermline(a:winid, '')
		call popup_close(a:winid)
		return 1

	elseif n == 13
		" Enter
		call popup_close(a:winid)
		return popup_filter_menu(a:winid, "\<Cr>")

	elseif (n == 9) || (n == 14)
		" Ctrl-n
		if len(lines) <= line('.', a:winid)
			return s:xxx(a:winid, lines, 0)
		else
			return s:xxx(a:winid, lines, line('.', a:winid))
		endif

	elseif (n == 128) || (n == 16)
		" Ctrl-p
		if 1 == line('.', a:winid)
			return s:xxx(a:winid, lines, len(lines) - 1)
		else
			return s:xxx(a:winid, lines, line('.', a:winid) - 2)
		endif

	else
		call popup_close(a:winid)
		return 0

	endif
endfunction

func s:callback(winid, key)
	let s:complete_winid = -1
endfunction

