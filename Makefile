PREFIX ?= /usr/local
BIN    ?= $(PREFIX)/bin
LIB    ?= $(PREFIX)/lib/mindoro
LIBEXEC ?= $(PREFIX)/libexec/mindoro
SHARE  ?= $(PREFIX)/share/mindoro

SCRIPTS = bin/mindoro libexec/mindoro-break adapters/tmux adapters/cmux adapters/herdr mindoro.tmux
LIBS    = $(wildcard lib/mindoro/*.sh)

.PHONY: lint test check install uninstall

# -x follows the `# shellcheck source=` directives into lib/, so the
# entry points are checked with their libraries as one program.
lint:
	shellcheck -x -s bash $(SCRIPTS)

test:
	bats tests

check: lint test

# A symlink for the launcher and copies for the rest: the launcher
# resolves its own symlink to find lib/, so BIN alone is enough for a
# checkout on PATH (make install BIN=~/.eden/bin).
install:
	mkdir -p $(BIN)
	ln -sf $(CURDIR)/bin/mindoro $(BIN)/mindoro

uninstall:
	rm -f $(BIN)/mindoro
