" BSD 2-Clause License Copyright (c) 2021, Pranshu Srivastava et al. All rights reserved.

scriptencoding utf-8

if exists("g:samwise_loaded") || !has("nvim")
  finish
endif

let g:samwise_loaded = v:true

" Globals {{{

if !exists("g:samwise_buffer_opts") | let g:samwise_buffer_opts = "bo " . winheight(0)/10 . "sp" | endif
if !exists("g:samwise_dir") | let g:samwise_dir = $HOME . "/.samwise" | endif
if !exists("g:samwise_echo") | let g:samwise_echo = v:false | endif
if !exists("g:samwise_float") | let g:samwise_float = v:false | endif
if !exists("g:samwise_format") | let g:samwise_format = "txt" | endif
" }}}

" Script-scoped {{{

let s:back_hunks = []
let s:bufname = ""
let s:content = []
let s:fwd_hunks = []
let s:hl_active = v:false
let s:namespace_id = -1
let s:path = ""
let s:win_id = -1
" }}}

function! s:generatePath() abort"{{{
  if expand("%:t") =~ ".*.samwise." . g:samwise_format . "$"
    " Keep s:content updated at all times.
    let s:content = systemlist("cat " . s:path)
    return
  endif
  let s:bufname = expand("%:t") . "-" . sha256(expand("%:p:h")) . ".samwise." . g:samwise_format
  call mkdir(g:samwise_dir, "p", 0700)
  let s:path = g:samwise_dir . "/" . s:bufname
  if filereadable(s:path)
    " Does neovim have any interal API for this?
    let s:content = systemlist("cat " . s:path)
  endif
  " Add hunk logic.
  let counter = 0
  let offset = 1
  let content_len = len(s:content)
  let s:back_hunks = []
  let s:fwd_hunks = []
  while counter < content_len - 1
    if s:content[counter] != "" && s:content[counter + 1] == ""
      call add(s:back_hunks, counter + offset)
    endif
    if s:content[counter] == "" && s:content[counter + 1] != ""
      call add(s:fwd_hunks, counter + offset + 1)
    endif
    let counter = counter + 1
  endwhile
endfunction"}}}

function! s:openBuffer() abort"{{{
  setlocal scrollbind
  exec g:samwise_buffer_opts . " " . s:path . " | norm " . line(".") . "gg"
  call setbufvar(s:bufname, "&number", 1)
  call setbufvar(s:bufname, "&scrollbind", v:true)
  call setbufvar(s:bufname, "&relativenumber", 0)
  call setbufvar(s:bufname, "&scrolloff", 999)
endfunction"}}}

function! s:closeBuffer() abort"{{{
  if buflisted(s:path)
    setlocal noscrollbind
    exec "bdelete  " . s:path
  endif
endfunction"}}}

""
" Open or close the corresponding samwise buffer. Please note
" that samwise buffers, by design, do not have their corresponding
" samwise buffers, and so on. Furthermore, opening a samwise buffer
" for the current buffer will open it's own respective samwise buffer
" as defined by g:samwise_dir (defaults to "~/.samwise"), and upon
" closing the samwise buffer, will close *only* the corresponding
" samwise buffer of the current buffer.
function! s:toggleBuffer() abort"{{{
  if !buflisted(s:path)
    call s:openBuffer()
  else
    call s:closeBuffer()
  endif
endfunction"}}}

function! s:highlight() abort"{{{
  let counter = 0
  let s:namespace_id = nvim_create_namespace("samwise")
  for line in s:content
    if line != ""
      call nvim_buf_add_highlight(0, s:namespace_id, "CursorLine", counter, 0, -1)
    endif
    let counter = counter + 1
  endfor
  let s:hl_active = v:true
endfunction"}}}

function! s:syncHighlight() abort"{{{
  if !s:hl_active
    return
  endif
  call nvim_buf_clear_namespace(0, s:namespace_id, 0, -1)
  call s:highlight()
endfunction"}}}

""
" Highlight current buffer on the basis of it's corresponding samwise
" buffer. The highlights indicate where a non-null entry is present and
" these entries can be conveniently fetched using either :SamwiseEcho
" or :SamwiseFloat.
function! s:toggleHiglight() abort"{{{
  if exists("s:hl_active")
    if s:hl_active
      call nvim_buf_clear_namespace(0, s:namespace_id, 0, -1)
      let s:hl_active = v:false
    else
      call s:highlight()
    endif
  endif
endfunction"}}}

""
" Echoes the corresponding line in the samwise buffer.
function! s:echo() abort"{{{
  if !g:samwise_echo
    return
  endif
  if expand("%:t") =~ ".*.samwise." . g:samwise_format . "$"
    return
  endif
  let linenr = line(".") - 1
  if linenr >= len(s:content)
    return
  endif
  let content = s:content[linenr]
  if content != ""
    echohl Identifier
    echon "Samwise.nvim: "
    echohl None
    echon content
  endif
endfunction"}}}
  
""
" Floats the corresponding line in the samwise buffer.
function! s:float() abort"{{{
  if !g:samwise_float
    return
  endif
  if expand("%:t") =~ ".*.samwise." . g:samwise_format . "$"
    return
  endif
  if exists("s:win_id") && getwininfo(s:win_id) != []
    call nvim_win_close(s:win_id, v:false)
  endif
  if exists("s:content") && s:content != []
    let linenr = line(".") - 1
    if linenr >= len(s:content)
      return
    endif
    let message = s:content[linenr]
    let message_len = len(message)
    " let factor = 25
    " let col = min([factor, message_len + (factor / 10)])
    " let row = max([1, message_len / col])
    let row = 1
    let col = message_len
    let height = row
    let width = col
    if message == ""
      return
    endif
    let buf_id = nvim_create_buf(v:false, v:false)
    call setbufvar(buf_id, "&buftype", "nofile")
    call setbufvar(buf_id, "&buflisted", 0)
    call setbufvar(buf_id, "&bufhidden", "hide")
    " FIXME
    " call setbufvar(buf_id, "&wrap", v:true)
    " exec bufnr(buf_id) . "bufdo " . "setlocal wrap"
    call nvim_buf_set_lines(buf_id, 0, 0, v:true, [message])
    let default_samwise_floating_opts = {
          \ 'relative': 'cursor',
          \ 'row': row,
          \ 'col': col,
          \ 'width': width,
          \ 'height': height,
          \ 'focusable': v:false,
          \ 'style': 'minimal',
          \ 'border': 'shadow',
          \ 'noautocmd': v:true
          \ } 
    if !exists("g:samwise_floating_opts")
      let g:samwise_floating_opts = default_samwise_floating_opts
    endif
    let s:win_id = nvim_open_win(buf_id, v:false, g:samwise_floating_opts)
  endif
endfunction"}}}

""
" Move to the next samwise hunk.
function! s:moveFwd() abort"{{{
  let cur_pos = line(".")
  for pos in s:fwd_hunks
    if pos > cur_pos
      call cursor(pos, 0)
      return
    endif
  endfor
endfunction"}}}

""
" Move to the previous samwise hunk.
function! s:moveBack() abort"{{{
  let cur_pos = line(".")
  for pos in reverse(copy(s:back_hunks))
    if pos < cur_pos
      call cursor(pos, 0)
      return
    endif
  endfor
endfunction"}}}

augroup SAMWISE
  autocmd BufEnter,BufLeave * :call s:generatePath()
  autocmd BufLeave          * :setlocal noscrollbind
  autocmd FileWritePost     * :call s:syncHighlight()
  autocmd CursorHold        * :call s:float()
  autocmd CursorHold        * :call s:echo()
augroup END

command -bar SamwiseMoveBack        call s:moveBack()
command -bar SamwiseMoveFwd         call s:moveFwd()
command -bar SamwiseToggleBuffer    call s:toggleBuffer()
command -bar SamwiseToggleHighlight call s:toggleHiglight()
