.PHONY: all lint

all: lint

lint:
	@pip install vim-vint && \
	vint --error --enable-neovim --color ./plugin/samwise.vim
