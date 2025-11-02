" Neovim Configuration - Managed by dev-bootstrap
" Basic Settings
set number                     " Show line numbers
set relativenumber             " Show relative line numbers
set mouse=a                    " Enable mouse support
set clipboard=unnamedplus      " Use system clipboard
set ignorecase                 " Case insensitive search
set smartcase                  " Case sensitive when uppercase present
set expandtab                  " Use spaces instead of tabs
set tabstop=2                  " Tab width
set shiftwidth=2               " Indent width
set softtabstop=2              " Backspace removes 2 spaces
set autoindent                 " Copy indent from current line
set smartindent                " Smart auto-indenting
set wrap                       " Wrap lines
set linebreak                  " Break lines at word boundaries
set scrolloff=8                " Keep 8 lines above/below cursor
set sidescrolloff=8            " Keep 8 columns left/right of cursor
set hlsearch                   " Highlight search results
set incsearch                  " Incremental search
set termguicolors              " Enable 24-bit RGB colors
set updatetime=300             " Faster completion
set timeoutlen=500             " Faster key sequence completion
set hidden                     " Allow hidden buffers
set backup                     " Enable backups
set undofile                   " Persistent undo
set backupdir=~/.config/nvim/backup//
set undodir=~/.config/nvim/undo//
set directory=~/.config/nvim/swap//
set signcolumn=yes             " Always show sign column
set cursorline                 " Highlight current line
set splitright                 " Split windows to the right
set splitbelow                 " Split windows below

" Leader key
let mapleader = " "

" Key mappings
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>h :nohl<CR>
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Better indenting
vnoremap < <gv
vnoremap > >gv

" Move selected lines
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

" Create directories for backups if they don't exist
if !isdirectory($HOME . "/.config/nvim/backup")
    call mkdir($HOME . "/.config/nvim/backup", "p")
endif
if !isdirectory($HOME . "/.config/nvim/undo")
    call mkdir($HOME . "/.config/nvim/undo", "p")
endif
if !isdirectory($HOME . "/.config/nvim/swap")
    call mkdir($HOME . "/.config/nvim/swap", "p")
endif
