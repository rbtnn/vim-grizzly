
let s:complete_winid = get(s:, 'complete_winid', -1)
let s:complete_t_winid = get(s:, 'complete_t_winid', -1)
let s:complete_t_cache = get(s:, 'complete_t_cache', { 'key' : '', 'items' : [], })

function! grizzly#complete_t(...) abort
	try
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
			return
		endif
		if s:complete_t_cache['key'] != input
			let s:complete_t_cache['key'] = input
			let s:complete_t_cache['items'] = s:cmdprompt_suggestions(input)
		endif
		if len(s:complete_t_cache['items']) < 1
			return
		elseif (len(s:complete_t_cache['items']) == 1) && (s:complete_t_cache['items'][0] == input)
			return
		endif
		let s:complete_t_winid = popup_create(s:complete_t_cache['items'], {})
		call s:setoptions(s:complete_t_winid)
	catch
		echo v:throwpoint
		echo v:exception
	endtry
endfunction

function! grizzly#complete() abort
	if get(g:, 'grizzly_disable', v:false)
		return
	endif
	let input = s:prompt_input(term_getline(bufnr(), '.'))
	let items = s:cmdprompt_suggestions(input)
	if 0 < len(items)
		call s:settermline(-1, items[0])
		if 1 < len(items)
			let s:complete_winid = popup_menu(items, {
				\ 'filter' : function('s:filter'),
				\ 'callback' : function('s:callback'),
				\ })
			call s:setoptions(s:complete_winid)
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
	let lines = []
	let path = expand(get(g:, 'grizzly_history', '~/.grizzly_history'))
	if filereadable(path)
		let lines += readfile(path)
	endif
	let lines += map(getbufline(bufnr(), 1, line('$') - 1)
		\ + map(range(1, line('$') - 1), { i,x -> term_getline(bufnr(), x) })
		\ , { i, x -> s:prompt_input(x) })
	for j in range(len(lines) - 1, 0, -1)
		for k in range(j - 1, 0, -1)
			if lines[j] == lines[k]
				let lines[k] = ''
			endif
		endfor
	endfor
	call filter(lines, { i,x -> !empty(x) })
	call writefile(lines, path)
	call filter(lines, { i,x -> (x =~# a:input) && (x != a:input) })
	return lines
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

