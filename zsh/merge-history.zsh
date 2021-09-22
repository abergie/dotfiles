# Use following commands to merge multiple .zsh_history files

builtin fc -R -I "$hist_file"
builtin fc -R -I "$another_hist_file"

# write the loaded history to HISTFILE
builtin fc -W "$HISTFILE"