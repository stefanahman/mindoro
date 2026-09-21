#!/usr/bin/env bash
# The TPM entry point. TPM runs the *.tmux files at a plugin's root;
# the work is `mindoro tmux-init`, so that a brew install can run the
# same thing from tmux.conf without TPM.
exec "$(dirname "${BASH_SOURCE[0]}")/bin/mindoro" tmux-init
