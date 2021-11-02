
let s:cmdpropt_cmds = ['dir', 'cd', 'copy', 'move', 'set', 'rmdir', 'mkdir', 'exit', 'echo', 'call', 'cls']
let s:complete_winid = get(s:, 'complete_winid', -1)
let s:complete_t_winids = get(s:, 'complete_t_winids', [])
let s:complete_t_cache = get(s:, 'complete_t_cache', {})
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

function! grizzly#close_popupwins() abort
	call s:close_complete_t_winids()
	call s:close_complete_winid(v:true)
endfunction

function! s:close_complete_t_winids() abort
	for id in s:complete_t_winids
		call popup_close(id)
	endfor
	let s:complete_t_winids = []
	if 'c' != mode(1)
		redraw
	endif
endfunction

function! s:close_complete_winid(do_closing) abort
	if a:do_closing
		call popup_close(s:complete_winid)
	endif
	let s:complete_winid = -1
	if 'c' != mode(1)
		redraw
	endif
endfunction

function! s:complete_t(...) abort
	if get(g:, 'grizzly_disable', v:false)
		return
	endif

	" Never redraw the screen showing more-prompt.
	if mode(1) =~# '^r'
		return
	endif

	if -1 != s:complete_winid
		call s:close_complete_t_winids()
		return
	endif

	" Display when Terminal-Job mode only.
	if 't' != mode(1)
		call s:close_complete_t_winids()
		return
	endif

	if &buftype != 'terminal'
		call s:close_complete_t_winids()
		return
	endif

	let xs = s:prompt_input(term_getline(bufnr(), '.'))
	if empty(xs)
		call s:close_complete_t_winids()
		return
	endif
	let input = xs[0]

	let items = s:cmdprompt_suggestions(input)

	if len(items) == 0
		call s:close_complete_t_winids()
		return
	elseif (len(items) == 1) && (items[0] == input)
		call s:close_complete_t_winids()
		return
	endif

	if empty(s:complete_t_winids)
		let s:complete_t_winids += [popup_create([], {})]
	endif

	call popup_settext(s:complete_t_winids[-1], items)
	call s:setoptions(s:complete_t_winids[-1])
endfunction

function! s:complete(bot) abort
	if get(g:, 'grizzly_disable', v:false)
		return
	endif
	let input = get(s:prompt_input(term_getline(bufnr(), '.')), 0, '')
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
	let n = len(getbufline(winbufnr(a:winid), 1, '$'))
	if (0 < n) && (3 == len(curpos)) && (2 == len(winpos))
		let col = winpos[1] - 1 + s:prompt_length()
		let line = winpos[0] + curpos[0]
		let maxheight = n
		let minheight = n
		if 0 < &pumheight
			if &pumheight < n
				let maxheight = &pumheight
				let minheight = &pumheight
			endif
		endif
		if &lines < line + maxheight
			let line -= maxheight + 1
			if line < 0
				let maxheight += line - 1
				let line = 1
			endif
		endif
		call popup_setoptions(a:winid, {
			\ 'minwidth' : &pumwidth,
			\ 'minheight' : minheight,
			\ 'maxheight' : maxheight,
			\ 'border' : [ 0, 0, 0, 0],
			\ 'padding' : [ 0, 1, 0, 1],
			\ 'wrap' : v:false,
			\ 'pos' : 'topleft',
			\ 'line' : line,
			\ 'col' : col,
			\ })
	endif
endfunction

function! s:prompt_pattern() abort
	return get(g:, 'grizzly_prompt_pattern', has('win32') ? '^[A-Z]:\\.*>\zs.*' : '^[\$#]\zs.*')
endfunction

function! s:prompt_length() abort
	let line = term_getline(bufnr(), '.')
	if 'utf-8' != &encoding
		let line = iconv(line, 'utf-8', &encoding)
	endif
	let prompt = matchstr(line, s:prompt_pattern())
	return strdisplaywidth(line) - strdisplaywidth(prompt)
endfunction

function! s:prompt_input(line) abort
	if a:line =~# s:prompt_pattern()
		return [trim(matchstr(a:line, s:prompt_pattern()))]
	else
		return []
	endif
endfunction

function! s:cmdprompt_suggestions(input) abort
	let linecount = get(get(filter(getbufinfo(), { i,x -> x['bufnr'] == bufnr() }), 0, {}), 'linecount', 1)
	let use_cache =
		\ (get(s:complete_t_cache, 'linecount', 1) == linecount)
		\ &&
		\ (get(s:complete_t_cache, 'bufnr', 1) == bufnr())
	let s:complete_t_cache['linecount'] = linecount
	let s:complete_t_cache['bufnr'] = bufnr()

	if use_cache
		let lines = deepcopy(get(s:complete_t_cache, 'lines', []))
	else
		let lines = []
		if filereadable(expand(g:grizzly_history))
			for line in readfile(expand(g:grizzly_history))
				if s:is_completable(line)
					let lines += [line]
				endif
			endfor
		endif
		for line in filter(map(getbufline(bufnr(), 1, linecount - 1), { i, x -> get(s:prompt_input(x), 0, '') }), { i,x -> !empty(x) })
			if s:is_completable(line)
				let lines += [line]
			endif
		endfor
		for j in range(len(lines) - 1, 0, -1)
			for k in range(j - 1, 0, -1)
				if lines[j] == lines[k]
					let lines[k] = ''
				endif
			endfor
		endfor
		call filter(lines, { i,x -> !empty(x) && ((x !~# '^cd ') || (x == 'cd ..')) })
		let s:complete_t_cache['lines'] = lines
	endif

	if !use_cache
		call writefile(lines, expand(g:grizzly_history))
	endif
	call filter(lines, { i,x -> -1 != stridx(x, a:input) })

	return lines
endfunction

function! s:is_completable(line)
	let cmd = tolower(get(split(a:line, '\s'), 0, ''))
	return executable(cmd) || (-1 != index(s:cmdpropt_cmds, cmd))
endfunction

function! s:setcursor(winid, lnum) abort
	call win_execute(a:winid, printf('call setpos(".", [0, %d, 1, 0])', a:lnum))
	call win_execute(a:winid, 'redraw')
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
	echo printf('%x', n)
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

	elseif n == 14
		" Ctrl-n
		if len(lines) <= line('.', a:winid)
			return s:xxx(a:winid, lines, 0)
		else
			return s:xxx(a:winid, lines, line('.', a:winid))
		endif

	elseif n == 16
		" Ctrl-p
		if 1 == line('.', a:winid)
			return s:xxx(a:winid, lines, len(lines) - 1)
		else
			return s:xxx(a:winid, lines, line('.', a:winid) - 2)
		endif

	elseif (n == 128) || (n == 9)
		" If you move the mouse cursor in popup_menu(),
		" this function receives Down key or Up key.
		" Thus those are ignored.
		return 1

	else
		call popup_close(a:winid)
		call feedkeys(a:key, '')
		return 1

	endif
endfunction

func s:callback(winid, key)
	call s:close_complete_t_winids()
	call s:close_complete_winid(v:false)
endfunction

