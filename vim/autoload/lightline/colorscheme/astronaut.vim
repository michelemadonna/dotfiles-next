" ============================================================================
" Lightline - Astronaut
" Based on the Ghostty Astronaut palette
" ============================================================================

let s:bg        = '#292c33'
let s:bg_alt    = '#373738'
let s:fg        = '#fefbf6'
let s:white     = '#fefefe'
let s:gray      = '#656565'

let s:red       = '#ea4029'
let s:red_hi    = '#eb5256'

let s:green     = '#aae046'
let s:green_hi  = '#c0e27c'

let s:yellow    = '#f5c643'
let s:yellow_hi = '#f8d96a'

let s:blue      = '#479ff2'
let s:blue_hi   = '#49a3f7'

let s:purple    = '#7b5caf'
let s:purple_hi = '#a47ce8'

let s:cyan      = '#64daec'
let s:cyan_hi   = '#98f9f2'


let s:p = {
      \ 'normal': {},
      \ 'insert': {},
      \ 'replace': {},
      \ 'visual': {},
      \ 'inactive': {},
      \ 'tabline': {}
      \ }


" ============================================================================
" NORMAL
" ============================================================================

let s:p.normal.left = [
      \ [ s:bg, s:yellow, 0, 0, 'bold' ],
      \ [ s:fg, s:bg_alt ]
      \ ]

let s:p.normal.middle = [
      \ [ s:fg, s:bg ]
      \ ]

let s:p.normal.right = [
      \ [ s:bg, s:yellow, 0, 0, 'bold' ],
      \ [ s:fg, s:bg_alt ]
      \ ]

let s:p.normal.error = [
      \ [ s:white, s:red_hi, 0, 0, 'bold' ]
      \ ]

let s:p.normal.warning = [
      \ [ s:bg, s:yellow_hi, 0, 0, 'bold' ]
      \ ]


" ============================================================================
" INSERT
" ============================================================================

let s:p.insert.left = [
      \ [ s:bg, s:green, 0, 0, 'bold' ],
      \ [ s:fg, s:bg_alt ]
      \ ]

let s:p.insert.right = [
      \ [ s:bg, s:green, 0, 0, 'bold' ],
      \ [ s:fg, s:bg_alt ]
      \ ]


" ============================================================================
" REPLACE
" ============================================================================

let s:p.replace.left = [
      \ [ s:white, s:red, 0, 0, 'bold' ],
      \ [ s:fg, s:bg_alt ]
      \ ]

let s:p.replace.right = [
      \ [ s:white, s:red, 0, 0, 'bold' ],
      \ [ s:fg, s:bg_alt ]
      \ ]


" ============================================================================
" VISUAL
" ============================================================================

let s:p.visual.left = [
      \ [ s:white, s:purple, 0, 0, 'bold' ],
      \ [ s:fg, s:bg_alt ]
      \ ]

let s:p.visual.right = [
      \ [ s:white, s:purple, 0, 0, 'bold' ],
      \ [ s:fg, s:bg_alt ]
      \ ]


" ============================================================================
" INACTIVE
" ============================================================================

let s:p.inactive.left = [
      \ [ s:gray, s:bg_alt ],
      \ [ s:gray, s:bg ]
      \ ]

let s:p.inactive.middle = [
      \ [ s:gray, s:bg ]
      \ ]

let s:p.inactive.right = [
      \ [ s:gray, s:bg_alt ],
      \ [ s:gray, s:bg ]
      \ ]


" ============================================================================
" TABLINE
" ============================================================================

let s:p.tabline.left = [
      \ [ s:gray, s:bg_alt ]
      \ ]

let s:p.tabline.tabsel = [
      \ [ s:bg, s:yellow, 0, 0, 'bold' ]
      \ ]

let s:p.tabline.middle = [
      \ [ s:gray, s:bg ]
      \ ]

let s:p.tabline.right = [
      \ [ s:gray, s:bg_alt ]
      \ ]


let g:lightline#colorscheme#astronaut#palette =
      \ lightline#colorscheme#fill(s:p)