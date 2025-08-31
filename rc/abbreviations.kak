declare-option str math_symbols_dir %sh{ echo $(dirname "$kak_source") }
declare-option str math_symbols_dir %sh{ echo "$PWD" }

declare-option str math_symbols_file "%opt{math_symbols_dir}/symbols.txt"
declare-option str math_completions_file "%opt{math_symbols_dir}/symbols.kak-completions"

# for showing the completions under the cursor
declare-option -hidden str-list math_completion_entries
declare-option -hidden completions math_completions

# loads math_completion_entries
evaluate-commands %sh{
  while read -r line; do
    printf "set -add global math_completion_entries %%@%s@\n" "$line"
  done < "$kak_opt_math_completions_file"
}

define-command -hidden math-complete-abbreviation -docstring '
  complete the abbreviation under the cursor
'%{
  evaluate-commands -draft -save-regs '^/' %{
    # save the selection for the abbreviation including the leading backslash.
    #
    # this selects everything after the last backslash, which should be the
    # abbreviation. there may be text before the backslash, for example if
    # entering something like {\R, ..}.
    #
    # this fails if there is no backslash in this WORD.
    execute-keys -save-regs '' <a-i><a-w>1s.*(\\[^\\]+)<ret>Z

    # save the abbreviation text, excluding the leading backslash
    execute-keys -save-regs '' 1s\\([^\\]+)<ret>

    # compute the abbreviation using symbols_file
    # TODO(enricozb): change this to echo the zc$found<esc> or to fail with
    # a message
    evaluate-commands %sh{
      found=$(awk -v q="$kak_selection" 'index($1, q) == 1 { print $2; exit }' "$kak_opt_math_symbols_file")

      if [ -z "$found" ]; then
        # show an error message
        printf 'fail %s' "no abbreviation found for: $kak_selection"
      fi

      # restore the original selection, including the lead backslash, and replace
      # it with the abbreviation
      printf 'execute-keys zc%s<esc>' "$found"
    }
  }
}

define-command math-enter-completion-mode %{
  set-option window math_completions "%val{cursor_line}.%val{cursor_column}@%val{timestamp}" %opt{math_completion_entries}
  set-option window completers option=math_completions %opt{completers}

  hook -group math-completion -once window InsertKey '<space>' %{
    try %{
      evaluate-commands -draft %{
        execute-keys hh
        math-complete-abbreviation
      }
    }

    math-exit-completion-mode
  }

  hook -group math-completion -once window ModeChange '.*' %{
    math-exit-completion-mode
  }
}

define-command math-exit-completion-mode %{
  set-option -remove window completers option=math_completions

  remove-hooks window math-completion
}

hook buffer InsertKey '\\'  math-enter-completion-mode
