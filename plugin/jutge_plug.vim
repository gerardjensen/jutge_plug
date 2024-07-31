" Title:        Jutge Plugin
" Description:  A plugin to interface with jutge.org within vim.
" Last Change:  31 July 2024
" Maintainer:   Gerard Jensen <https://github.com/gerardjensen>

" Prevents the plugin from being loaded multiple times. If the loaded
" variable exists, do nothing more. Otherwise, assign the loaded
" variable and continue running this instance of the plugin.
if exists("g:loaded_jutge_plug")
    finish
endif
let g:loaded_jutge_plug = 1

" Exposes the plugin's functions for use as commands in Vim.
command! -nargs=* JutgeSetCredentials call jutge_plug#JutgeSetCredentials(<f-args>)
command! -nargs=0 JutgeCheckCookieValidity call http#print_valid_cookie()
command! -nargs=0 JutgeShowProblems call ui#JutgeShowProblems()

command! -nargs=0 JutgeGetExerciseFiles call ui#get_exercise_files()

call http#init()
