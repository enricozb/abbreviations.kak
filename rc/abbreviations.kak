declare-option str abbreviations_file "%val{source}/../abbreviations.txt"

define-command enable-abbreviations %{
  map buffer insert '<c-\>' '<esc>: abbreviation<ret>'
}

define-command abbreviation %{
  popup \
    --title abbreviation \
    --kak-script %{ execute-keys i %opt{popup_output} } \
    --padding 10 \
    -- \
    fish -c %exp{
      set -lx FZF_OPTS $FZF_OPTS --height 100%%

      cat %opt{abbreviations_file} |
      fzf $FZF_OPTS --delimiter=\u2008 --nth=2 |
      cut --fields 1 --delimiter ' '
    }
}
