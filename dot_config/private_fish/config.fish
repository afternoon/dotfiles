set -gx HOMEBREW_PREFIX /opt/homebrew
set -gx HOMEBREW_BIN /opt/homebrew/bin
set -gx EDITOR $HOMEBREW_BIN/nvim

fish_add_path $HOMEBREW_BIN
fish_add_path ~/.local/bin
fish_add_path ~/.bun/bin
fish_add_path ~/.cargo/bin

alias vi=$EDITOR

if status is-interactive
  set -g fish_greeting
end
