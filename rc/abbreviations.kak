# abbreviations.kak
# -----------------
#
# A plugin to allow inserting unicode relevant to mathematics via latex-like
# inputs using a leading backslash. This is inspiried by how unicode is inserted
# into lean code files in vscode [1].
#
# [1]: https://leanprover-community.github.io/glossary.html#unicode-abbreviation

# TODO(enricozb): attempt to add some functionality where the abbreviation is
# completed after the first non-matching character is inserted. This can
# implicitly include <space> and <ret>, but it would allow for writing something
# like
#
#   \<<a, b\>>,
#
# and have it complete to ⟪a, b⟫, without needing to use backspace.
#
# TODO(enricozb): when deleting the initiating backslash in insert mode, the
# abbreviation is still "active" but no backslash exists. We should detect this
# and exit the abbreviation mode.

# ---------------------------------- options -----------------------------------
declare-option -docstring '
  The file containing newline-separated tuples of abbreviations and symbols.
  These lines should be sorted, as their order determines which symbol is used
  if multiple ones match.

  For example:
    a α
    b β
    c χ
    McL ℒ

  By default this is all symbols used by the lean unicode abbreviation plugin,
  excluding those with the CURSOR text.
' str math_symbols_file %sh{
  echo $(dirname "$kak_source")/symbols.txt
}

declare-option -docstring '
  The file containing the list of kakoune completions (see :doc options)
  to show under the cursor when abbreviation mode is active.

  For example:
    U0||U0 ⋃₀
    Un||Un ⋃
    Union||Union ⋃

  By default this is <symbol>||<symbol> <abbreviation>, where the symbols and
  abbreviations are found from the default `math_symbols_file` option.
' str math_completions_file %sh{
  echo $(dirname "$kak_source")/symbols.kak-completions
}

# ---------------------------------- commands ----------------------------------

define-command math-enable-abbreviations -docstring '
  Enables math abbreviations.

  Abbreviation mode is entered when a backslash is inserted into the buffer.
  Valid abbreviations are suggested under the cursor as characters are
  inserted.  Once <space> or <ret> is entered, the abbreviation text is used
  to find the appropriate symbol, and replaces the entered \<abbreviation>
  text. If a matching symbol is not found, the text is not replaced.

  The matching symbol is the first symbol whose abbreviation has the inputted
  text as a prefix.

  This command also loads the completion entries from the
  `math_completions_file` option
' %{
  # loads math_completion_entries, if it hasn't been loaded already
  evaluate-commands %sh{
    if [ -z "$kak_math_completion_entries" ]; then
      while read -r line; do
        printf "set -add global math_completion_entries %%@%s@\n" "$line"
      done < "$kak_opt_math_completions_file"
    fi
  }

  set-option window completers option=math_completions

  # remove existing highlighter in case abbreviations were previously enabled
  try %{ remove-highlighter window/math-abbreviations }
  add-highlighter window/math-active-abbreviations ranges math_active_abbreviation_ranges

  # remove existing hooks in case abbreviations were previously enabled
  remove-hooks window math-enter-completion-mode
  hook -group math-enter-completion-mode window InsertKey '\\' %{
    math-enter-completion-mode
  }
}

define-command math-disable-abbreviations -docstring '
  Disables math abbreviations.

  This command does not unload the completion entries read from the
  `math_completions_file` option.
' %{
  set-option -remove window completers option=math_completions
  remove-hooks window math-enter-completion-mode
}

# ------------------------------- implementation -------------------------------

# the location of each \ in an active abbreviation as a list of <line>.<column>
declare-option -hidden str-list math_active_abbreviations

# for showing the completions under the cursor
declare-option -hidden str-list math_completion_entries
declare-option -hidden completions math_completions

# the location of each \ in an active abbreviation as a list of
# <line>.<column>,<line>.<column+1>. this is used in a highlighter along with
# the timestamp of the insertion of the \ character, to bold every active
# abbreviation.
declare-option -hidden range-specs math_active_abbreviation_ranges

define-command -override -hidden math-complete-abbreviation -docstring '
  Completes the abbreviation under the cursor.
'%{
  evaluate-commands -save-regs '"^/' %{
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

    # compute the abbreviation using symbols_file, failing with a message if
    # no matching abbreviation is found.
    evaluate-commands %sh{
      found=$(
        awk -v \
          q="$kak_selection" \
          'index($1, q) == 1 { print $2; exit }' \
          "$kak_opt_math_symbols_file"
      )

      if [ -z "$found" ]; then
        # show an error message
        printf 'fail %s\n' "no abbreviation found for: $kak_selection"
      fi

      # restore the original selection, including the lead backslash, and
      # replace it with the abbreviation
      printf 'set-register dquote %%@%s@\n' "$found"
      printf 'execute-keys zR%s\n' "$found"
    }
  }
}

define-command -hidden math-complete-active-abbreviations -docstring '
  Restore the selections of the active completions and attempt to complete
  each of them.
' %{
  evaluate-commands -draft -save-regs '^' %{
    set-register '^' %opt{math_active_abbreviations}
    execute-keys z
    evaluate-commands -itersel %{ try math-complete-abbreviation }
  }
}

define-command -hidden math-enter-completion-mode -docstring '
  Enters the abbreviation completion "mode".

  This is called after an InsertKey "\\" hook fires. The location the inserted
  backslash is saved (of every backslash in the case of multiple cursors).
  Once a <space> or <ret> is entered, the abbreviations at each of the saved
  backslashes are attempted to be completed.

  If the mode changes (for example, to normal mode) the completion mode is
  exited, and no abbreviation matching is attempted.
'%{
  # save the selections for all leading backslashes
  evaluate-commands -draft -save-regs '^' %{
    execute-keys -save-regs '' hZ
    set-option window math_active_abbreviations %reg{^}
  }

  # add active abbreviation highlighters
  set-option window math_active_abbreviation_ranges %val{timestamp}
  evaluate-commands -draft -itersel %{
    # save cursor positions of the backslash and the column immediately after
    set-register e "%val{cursor_line}.%val{cursor_column}"
    execute-keys h
    set-register s "%val{cursor_line}.%val{cursor_column}"

    set-option -add window math_active_abbreviation_ranges \
      "%reg{s},%reg{e}|+b"
  }

  # set up the option to show completions under the cursor
  # TODO(enricozb): this does nothing under multiple cursors
  set-option window math_completions \
      "%val{cursor_line}.%val{cursor_column}@%val{timestamp}" \
    %opt{math_completion_entries}
  set-option window completers option=math_completions %opt{completers}

  hook -group math-exit-completion-mode -once window InsertKey '(<space>|<ret>)' %{
    math-complete-active-abbreviations
    math-exit-completion-mode
  }

  hook -group math-exit-completion-mode -once window ModeChange '.*' %{
    math-exit-completion-mode
  }
}

define-command -hidden math-exit-completion-mode -docstring '
  Cleans up options, hooks and highlighters.
' %{
  unset-option window math_completions
  unset-option window math_active_abbreviations
  unset-option window math_active_abbreviation_ranges

  remove-hooks window math-exit-completion-mode
}
