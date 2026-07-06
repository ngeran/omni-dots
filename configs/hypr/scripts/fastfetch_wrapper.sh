#!/bin/bash
# Force a wide enough terminal (120 cols) for side-by-side logo and text
stty cols 120
clear

fastfetch --config ~/.config/fastfetch/config.jsonc

echo ""
# Center the exit message slightly
echo -e "\e[38;5;244m                   󱊟 Press any key to close\e[0m"
read -n 1 -s
