let mapleader=" "

set autoread
au FocusGained,BufEnter * checktime

set hid

set hidden
set noswapfile
set termguicolors
set nobackup
set cmdheight=2
set updatetime=300
set shortmess+=c
set nowritebackup
set noerrorbells
set rnu
set nu
set so=7
set undodir=~/.vim/undodir
set undofile
set incsearch
set laststatus=2
set showcmd
set notimeout
set ttimeout
" ---- Default Spacing Rules
set smartindent   " Do smart autoindenting when starting a new line
set autoindent
set expandtab     " When using <Tab>, put spaces instead of a <tab>
set tabstop=2
set shiftwidth=2
set softtabstop=2
" ---- Show Invisibles Character
set list
set listchars=tab:▸\ ,eol:¬
set colorcolumn=120
set background=dark

map j gj
map k gk

inoremap <C-k> <Up>
inoremap <C-j> <Down>
inoremap <C-h> <Left>
inoremap <C-l> <Right>
inoremap <C-p> <C-r>+

set backspace=indent,eol,start

nnoremap Q @q
nnoremap Y y$
noremap H     ^
noremap L     $

nnoremap <leader>1 :Vex<Cr>
nnoremap <leader>t :tabnew<Cr>
nnoremap <leader>h :wincmd h<CR>
nnoremap <leader>j :wincmd j<CR>
nnoremap <leader>k :wincmd k<CR>
nnoremap <leader>l :wincmd l<CR>
nnoremap <leader>s :wincmd s<CR>
nnoremap <leader>v :wincmd v<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>w :w<CR>
nnoremap <leader>e :e<Space>
nnoremap <leader>p "+p
nnoremap <leader>[ "+P
nnoremap <leader>u :UndotreeShow<CR>
noremap <leader>J J
nnoremap <leader><leader>q :q!<CR>
nnoremap <leader><leader>s :source ~/.vimrc<CR>
nnoremap <leader><leader>e :e ~/.vimrc<CR>
nnoremap <leader><leader>, :PlugInstall<CR>
nnoremap <leader><leader>m :terminal<CR>

" Close buffer and open previous buffer
noremap <C-x> :bp<Bar>bd #<Cr>

augroup RestoreCursorShapeOnExit
autocmd!
    autocmd VimLeave * set guicursor=a:hor20
augroup END

let g:netrw_banner = 0
let g:netrw_liststyle = 3
let g:netrw_browse_split = 2
let g:netrw_winsize = 20

set statusline=%1*\ %n\ %*
set statusline+=%1*\ %f\ %*
set statusline+=%1*\ %m\ %*
set statusline+=%1*\ %y\ %*
set statusline+=%2*\ %{FugitiveStatusline()}\ %*
set statusline+=%r
set statusline+=%=
set statusline+=%3*\ %l\ %*
set statusline+=%3*\ ::\ %*
set statusline+=%3*\ %L\ %*
set statusline+=%3*\ %P\ %*

if empty(glob('~/.vim/autoload/plug.vim'))
    silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')
" I Need these
Plug 'tpope/vim-surround'
Plug 'justinmk/vim-sneak'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-fugitive'
Plug 'adelarsq/vim-matchit'
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-unimpaired'
Plug 'mbbill/undotree'
Plug 'mattn/emmet-vim'
if has('python3')
  Plug 'sirver/UltiSnips'
endif
" gc{motion} to comment
Plug 'tpope/vim-commentary'
Plug 'pangloss/vim-javascript'
Plug 'leafgarland/typescript-vim'
Plug 'tpope/vim-obsession'

" Favorite Color Scheme
Plug 'morhetz/gruvbox'
" FZF - To search files by name
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
" LSP
Plug 'neoclide/coc.nvim', {'branch': 'release'}

Plug 'neoclide/coc.nvim', {'branch': 'release'}
let g:coc_global_extensions = [
  \ 'coc-tsserver'
  \ ]

" Rainbow Colors
Plug 'kien/rainbow_parentheses.vim'
" Auto Pairs
Plug 'jiangmiao/auto-pairs'
" Rails Helper
Plug 'tpope/vim-rails'
" Rails - auto write end keyword
Plug 'tpope/vim-endwise'
" Ack - To search files by text
Plug 'mileszs/ack.vim'
" Tagbar
Plug 'majutsushi/tagbar'
" Linting
" Plug 'dense-analysis/ale'
call plug#end()

colorscheme gruvbox

" find new bindings

let g:sneak#streak = 1

nmap <silent> ]g <Plug>(coc-diagnostic-prev)
nmap <silent> [g <Plug>(coc-diagnostic-next)
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gr <Plug>(coc-references)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)
nmap <silent> do <Plug>(coc-codeaction)
nmap <leader>rn <Plug>(coc-rename)
nmap <silent> <leader>f <Plug>(coc-fix-current)

nmap <silent> K :call CocAction('doHover')<CR>
nmap <silent> <leader>d :<C-u>CocList diagnostic<cr>
nmap <silent> <leader>i :<C-u>CocList symbols<cr>

" Remap <C-f> and <C-b> for scroll float windows/popups.
if has('nvim-0.4.0') || has('patch-8.2.0750')
  nnoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-f>"
  nnoremap <silent><nowait><expr> <C-b> coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-b>"
  inoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(1)\<cr>" : "\<Right>"
  inoremap <silent><nowait><expr> <C-b> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(0)\<cr>" : "\<Left>"
  vnoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-f>"
  vnoremap <silent><nowait><expr> <C-b> coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-b>"
endif


nnoremap <leader>f :Files<CR>
nnoremap <leader>g :GFiles<CR>

" Lint Setup
" let g:ale_linters = {
"       \ageFunction returns a Promise, then page.$$eval would wait for the¬
"        >>  14   }¬                           promise to'ruby': ['rubocop'],
"       \   'python': ['flake8', 'pylint'],
"       \   'javascript': ['eslint'],
"       \}

" Autofix setup
" let g:ale_fixers = {
"    \    'ruby': ['rubocop'],
"    \}
" let g:ale_fix_on_save = 1 

" Use ripgrep for searching ⚡️
 let g:ackprg = 'rg --vimgrep --type-not sql --smart-case'

" Any empty ack search will search for the work the cursor is on
let g:ack_use_cword_for_empty_search = 1

" Don't jump to first match
cnoreabbrev Ack Ack!

" Maps <leader>/ so we're ready to type the search keyword
noremap <leader><leader>/ :Ack!<Space>

set completeopt=menu,menuone,noinsert,noselect

hi User1 guibg=Purple
hi User2 guibg=Purple4
hi User3 guibg=Purple2

let g:user_emmet_leader_key=','
let g:UltiSnipsExpandTrigger="<tab>"
let g:UltiSnipsJumpForwardTrigger="<tab>"
let g:UltiSnipsJumpBackwardTrigger="<s-tab>"

" Coc Recommended Settings
if has("patch-8.1.1564")
  " Recently vim can merge signcolumn and number column into one
  set signcolumn=number
else
  set signcolumn=yes
endif

" Add `:Format` command to format current buffer.
command! -nargs=0 Format :call CocAction('format')

inoremap <silent><expr> <C-n>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><C-p> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

if isdirectory('./node_modules') && isdirectory('./node_modules/prettier')
  let g:coc_global_extensions += ['coc-prettier']
endif

if isdirectory('./node_modules') && isdirectory('./node_modules/eslint')
  let g:coc_global_extensions += ['coc-eslint']
endif

function! ShowDocIfNoDiagnostic(timer_id)
  if (coc#float#has_float() == 0)
    silent call CocActionAsync('doHover')
  endif
endfunction

function! s:show_hover_doc()
  call timer_start(500, 'ShowDocIfNoDiagnostic')
endfunction

