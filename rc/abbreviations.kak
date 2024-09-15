declare-option -hidden str abbreviation_position
declare-option -hidden range-specs abbreviation_range

add-highlighter global/abbreviation replace-ranges abbreviation_range

map buffer insert '\' '<esc>: abbreviation<ret>'

define-command -override -hidden abbreviation %{
  set-option window abbreviation_position "%val{cursor_line}.%val{cursor_column}"

  execute-keys 'i\<esc>'

  abbreviation-capture-keys
}

define-command -override -hidden abbreviation-capture-keys %{
  prompt -on-change %{
    evaluate-commands %sh{
      escaped_text=$( echo "$kak_text" | sed 's/|/\\|/g' )
      printf '%s\n' "set-option window abbreviation_range %val{timestamp} \"%opt{abbreviation_position},%opt{abbreviation_position}|{+bu}{\\}\\\\$escaped_text\""

      # if a space is pressed, the user has selected an abbreviation
      case "$kak_text" in
        *" ")
          # delete the space in the prompt, accept the prompt, re-insert the space
          printf 'execute-keys "<backspace><ret> "\n'
          ;;
      esac
    }

    # if a comma or a space is pressed, accept the prompt and insert that key
    execute-keys %sh{
    }
  } -on-abort %{
    unset-option window abbreviation_range
    execute-keys "i%val{text}"
  } -shell-script-candidates %{
    cat ./abbreviations.json
  } abbrev: %{
    unset-option window abbreviation_range

    execute-keys i
    execute-keys %sh{
      case "$kak_text" in
        # if a match contains a space, it was selected through tab-completion
        *" "*)
          symbol=$( echo "$kak_text" | sed 's/^[^ ]* //' )
          printf "<backspace>$symbol"
          ;;
        # otherwise, we have to fuzzy-find the most likely match
        *)
          # get the closest match through fuzzy search, stripping everything up until the first space (a space may be present due to tab completion)
          match=$(cat ./abbreviations.json | fzf --filter "$kak_text" | head -n 1 | sed 's/^[^ ]* //')

          if [ -n "$match" ]; then
            # insert the matched symbol, deleting the backslash
            printf "<backspace>$match"
          else
            # insert exactly what was typed
            printf "$kak_text"
          fi
          ;;
      esac
    }
  }
}

(h : ℱ ⊯ φ) ∫ 
