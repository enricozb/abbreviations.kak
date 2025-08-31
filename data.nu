let lean_url = "https://raw.githubusercontent.com/leanprover/vscode-lean4/refs/heads/master/lean4-unicode-input/src/abbreviations.json"

def escape [] {
    str replace --all --regex '(\\|\|)' '\${1}'
}

let abbreviations = http get $lean_url
    | transpose
    | rename key value
    | where value !~ 'CURSOR'
    | sort-by key

$abbreviations
    | each { $'($in.key) ($in.value)' }
    | save -f symbols.txt

$abbreviations
    | insert menu_text { |row| $'($row.key) ($row.value)'}
    | each { $'($in.key | escape)||($in.menu_text | escape)' }
    | save -f symbols.kak-completions

# let abbreviations = http get $lean_url
#     | transpose
#     | rename key value
#     | where value !~ 'CURSOR'
#     | each { $'($in.key) ($in.value)' }
#     | str replace --all '\' '\\'
#     | str replace --all '|' '\|'
#     | str replace "'" "''"
#     | each { $"'($in)||($in)'" }
#     | str join ' '

# let kak_source = 'declare-option str-list lean_abbreviations ' + $abbreviations

# $kak_source | save -f lean-abbreviations.kak
