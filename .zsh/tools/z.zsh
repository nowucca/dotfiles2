#!/usr/bin/env zsh
#
# z - Directory jumping (https://github.com/rupa/z)
#

if is_coder_workspace; then
    . ~/.config/work/dotfiles/init/z/z.sh
else
    . ~/init/z/z.sh
fi
