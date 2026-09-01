" ============================================================================
" Astronaut
" Vim colorscheme based on Ghostty Astronaut
" Syntax tuned to match GNU nano visual contrast
" ============================================================================

hi clear

if exists('syntax_on')
    syntax reset
endif

let g:colors_name = 'astronaut'
set background=dark


" ============================================================================
" Base
" ============================================================================

hi Normal       guifg=#fefbf6 guibg=#292c33 gui=NONE
hi NormalNC     guifg=#fefbf6 guibg=#292c33 gui=NONE

hi Cursor       guifg=#292c33 guibg=#ea4029 gui=NONE
hi CursorLine   guibg=#373738 gui=NONE
hi CursorColumn guibg=#373738 gui=NONE

hi LineNr       guifg=#656565 guibg=#292c33 gui=NONE
hi CursorLineNr guifg=#f8d96a guibg=#373738 gui=bold
hi SignColumn   guifg=#656565 guibg=#292c33 gui=NONE


" ============================================================================
" Selection / search
" ============================================================================

hi Visual       guifg=#fefefe guibg=#133649 gui=NONE
hi VisualNOS    guifg=#fefefe guibg=#133649 gui=NONE

hi Search       guifg=#292c33 guibg=#f5c643 gui=bold
hi IncSearch    guifg=#292c33 guibg=#f8d96a gui=bold
hi CurSearch    guifg=#292c33 guibg=#f8d96a gui=bold

hi MatchParen   guifg=#292c33 guibg=#98f9f2 gui=bold


" ============================================================================
" UI
" ============================================================================

hi StatusLine   guifg=#292c33 guibg=#f5c643 gui=bold
hi StatusLineNC guifg=#656565 guibg=#373738 gui=NONE

hi TabLine      guifg=#656565 guibg=#373738 gui=NONE
hi TabLineFill  guifg=#656565 guibg=#292c33 gui=NONE
hi TabLineSel   guifg=#292c33 guibg=#f5c643 gui=bold

hi VertSplit    guifg=#373738 guibg=#292c33 gui=NONE
hi WinSeparator guifg=#373738 guibg=#292c33 gui=NONE

hi Pmenu        guifg=#fefbf6 guibg=#373738 gui=NONE
hi PmenuSel     guifg=#292c33 guibg=#f5c643 gui=bold
hi PmenuSbar    guibg=#373738
hi PmenuThumb   guibg=#656565

hi Folded       guifg=#656565 guibg=#373738 gui=NONE
hi FoldColumn   guifg=#656565 guibg=#292c33 gui=NONE


" ============================================================================
" Messages
" ============================================================================

hi ErrorMsg     guifg=#eb5256 guibg=#292c33 gui=bold
hi WarningMsg   guifg=#f8d96a guibg=#292c33 gui=bold
hi ModeMsg      guifg=#c0e27c guibg=#292c33 gui=bold
hi MoreMsg      guifg=#c0e27c guibg=#292c33 gui=bold
hi Question     guifg=#98f9f2 guibg=#292c33 gui=bold


" ============================================================================
" Syntax
" ============================================================================

" Comments: bright cyan, like nano
hi Comment        guifg=#64daec gui=NONE
hi SpecialComment guifg=#98f9f2 gui=NONE

" Strings: yellow
hi String          guifg=#f5c643 gui=NONE
hi Character       guifg=#f8d96a gui=NONE

" Constants: purple
hi Constant        guifg=#a47ce8 gui=NONE
hi Number          guifg=#a47ce8 gui=NONE
hi Boolean         guifg=#a47ce8 gui=bold
hi Float           guifg=#a47ce8 gui=NONE

" Identifiers
hi Identifier      guifg=#fefbf6 gui=NONE
hi Function        guifg=#49a3f7 gui=NONE

" Statements / commands / keywords: green
hi Statement       guifg=#aae046 gui=NONE
hi Conditional     guifg=#aae046 gui=NONE
hi Repeat          guifg=#aae046 gui=NONE
hi Keyword         guifg=#aae046 gui=NONE
hi Exception       guifg=#aae046 gui=NONE

" Labels
hi Label           guifg=#f8d96a gui=NONE

" Operators
hi Operator        guifg=#fefbf6 gui=NONE

" Preprocessor
hi PreProc         guifg=#c0e27c gui=NONE
hi Include         guifg=#49a3f7 gui=NONE
hi Define          guifg=#c0e27c gui=NONE
hi Macro           guifg=#c0e27c gui=NONE
hi PreCondit       guifg=#c0e27c gui=NONE

" Types
hi Type            guifg=#98f9f2 gui=NONE
hi StorageClass    guifg=#98f9f2 gui=NONE
hi Structure       guifg=#98f9f2 gui=NONE
hi Typedef         guifg=#98f9f2 gui=NONE

" Special
hi Special         guifg=#eb5256 gui=NONE
hi SpecialChar     guifg=#eb5256 gui=NONE
hi Tag             guifg=#49a3f7 gui=NONE
hi Delimiter       guifg=#fefbf6 gui=NONE
hi Debug           guifg=#eb5256 gui=NONE

hi Underlined      guifg=#49a3f7 gui=underline
hi Ignore          guifg=#656565
hi Error           guifg=#eb5256 guibg=#292c33 gui=bold
hi Todo            guifg=#292c33 guibg=#f8d96a gui=bold


" ============================================================================
" Diff
" ============================================================================

hi DiffAdd     guifg=#c0e27c guibg=#292c33 gui=NONE
hi DiffChange  guifg=#f8d96a guibg=#292c33 gui=NONE
hi DiffDelete  guifg=#eb5256 guibg=#292c33 gui=NONE
hi DiffText    guifg=#292c33 guibg=#f8d96a gui=bold


" ============================================================================
" Spell
" ============================================================================

hi SpellBad   guifg=#eb5256 gui=undercurl
hi SpellCap   guifg=#49a3f7 gui=undercurl
hi SpellLocal guifg=#98f9f2 gui=undercurl
hi SpellRare  guifg=#a47ce8 gui=undercurl


" ============================================================================
" GitGutter
" ============================================================================

hi GitGutterAdd          guifg=#aae046 guibg=#292c33
hi GitGutterChange       guifg=#f5c643 guibg=#292c33
hi GitGutterDelete       guifg=#ea4029 guibg=#292c33
hi GitGutterChangeDelete guifg=#eb5256 guibg=#292c33


" ============================================================================
" ALE
" ============================================================================

hi ALEErrorSign   guifg=#eb5256 guibg=#292c33
hi ALEWarningSign guifg=#f8d96a guibg=#292c33
hi ALEInfoSign    guifg=#49a3f7 guibg=#292c33

hi ALEError   gui=undercurl guisp=#eb5256
hi ALEWarning gui=undercurl guisp=#f8d96a


" ============================================================================
" Terminal
" ============================================================================

let g:terminal_ansi_colors = [
      \ '#373738',
      \ '#ea4029',
      \ '#aae046',
      \ '#f5c643',
      \ '#479ff2',
      \ '#7b5caf',
      \ '#64daec',
      \ '#fefefe',
      \ '#656565',
      \ '#eb5256',
      \ '#c0e27c',
      \ '#f8d96a',
      \ '#49a3f7',
      \ '#a47ce8',
      \ '#98f9f2',
      \ '#fefefe'
      \ ]