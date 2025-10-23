fish_add_path /usr/local/bin
fish_add_path ~/.local/bin
fish_add_path ~/.bun/bin
fish_add_path ~/.cargo/bin

set -x EDITOR hx

alias vi=hx

if status is-interactive
    set -g fish_greeting
end
