" ---------------------------------------------------------------------------------
" 
"   ,--------.,--.                 ,--. ,--.                                   
"   '--.  .--'`--',--,--,--. ,---. |  .'   / ,---.  ,---.  ,---.  ,---. ,--.--.
"      |  |   ,--.|        || .-. :|  .   ' | .-. :| .-. :| .-. || .-. :|  .--'
"      |  |   |  ||  |  |  |\   --.|  |\   \\   --.\   --.| '-' '\   --.|  |   
"      `--'   `--'`--`--`--' `----'`--' '--' `----' `----'|  |-'  `----'`--'   
" 
"     file: timekeeper
"     desc: This is the timekeeper syntax file.
" 
"   author: Peter Antoine
"     date: 29/03/2013
" ---------------------------------------------------------------------------------
"                      Copyright (c) 2013 Peter Antoine
"                            All rights Reserved.
"                       Released Under the MIT Licence
" ---------------------------------------------------------------------------------

" Quit when a syntax file was already loaded
"if exists("b:current_syntax")
"  finish
"endif

let b:current_syntax = "tk"

" Project lines
syn region	tkProjectLine	start="^▸" start="^▾" start="^+" start="^-" end="$"	keepend contains=tkMarker,tkProjectLine,tkTime,@NoSpell

" Marker for project selection
syn match	tkMarker		"▸ "	contained containedin=tkProjectLine nextgroup=tkProjectName
syn match	tkMarker		"▾ "	contained containedin=tkProjectLine nextgroup=tkProjectName
syn match	tkMarker		"- "	contained containedin=tkProjectLine nextgroup=tkProjectName
syn match	tkMarker		"+ "	contained containedin=tkProjectLine nextgroup=tkProjectName

syn match	tkProjectName			"[0-9A-Za-z\._#]\+"					contained containedin=tkProjectLine nextgroup=tkTime
syn match	tkCurrentProjectName	"*[0-9A-Za-z\._#]\+"				contained containedin=tkProjectLine nextgroup=tkTime
syn match 	tkTime					"[0-9]\+\:[0-9][0-9]\:[0-9][0-9]"	contained containedin=tkProjectLine,tkJobLine nextgroup=tkJobName

" syntax for the job line
syn region	tkJobLine		start="^ [•✓+✗x•\- ]" end="$" keepend contains=tkStateStarted,tkStateAbandoned,tkStateComplete,tkJobName,@NoSpell

" Status markers
syn match	tkStateComplete		" ✓"								contained containedin=tkJobLine nextgroup=tkJobTime
syn match	tkStateComplete		" +"								contained containedin=tkJobLine nextgroup=tkJobTime
syn match	tkStateAbandoned	" ✗"								contained containedin=tkJobLine nextgroup=tkJobTime
syn match	tkStateAbandoned	" x"								contained containedin=tkJobLine nextgroup=tkJobTime
syn match	tkStateStarted		" •"								contained containedin=tkJobLine nextgroup=tkJobTime
syn match	tkStateStarted		" -"								contained containedin=tkJobLine nextgroup=tkJobTime
syn match 	tkJobTime			" [0-9]\+\:[0-9][0-9]\:[0-9][0-9] "	contained containedin=tkJobLine nextgroup=tkJobName,tkCurrentJobName
syn match	tkJobName			"[0-9A-Za-z\._#\-]\+"				contained containedin=tkJobLine contains=@NoSpell
syn match	tkCurrentJobName	"*[0-9A-Za-z\._#\-]\+"				contained containedin=tkJobLine contains=@NoSpell

" set the colours
hi link tkProjectLine			Normal
hi link tkJobLine				Normal
hi link tkTime					Special
hi link tkJobTime				Special
hi link tkMarker				Number
hi link tkJobName				String
hi link tkProjectName			Identifier
hi 		tkCurrentProjectName	term=bold ctermfg=Yellow guifg=Yellow
hi 		tkCurrentJobName		term=bold ctermfg=Yellow guifg=Yellow
hi 		tkStateComplete			term=bold ctermfg=Green guifg=Green
hi 		tkStateAbandoned		term=bold ctermfg=Red guifg=Red
hi 		tkStateStarted			term=bold ctermfg=Yellow guifg=Yellow




