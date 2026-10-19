#!/bin/bash
# Z Privacy on a test vault, for the attack (خطة الهجوم، القسم أ).
# Your real vault in ~/.local/share/zprivacy is never opened by this.
mkdir -p "$HOME/z-attack-data"
XDG_DATA_HOME="$HOME/z-attack-data" exec "$HOME/.local/opt/zprivacy/zprivacy"
