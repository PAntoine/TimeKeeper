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
syn match	tkMarker		"▸"	contained containedin=tkProjectLine nextgroup=tkProjectName
syn match	tkMarker		"▾"	contained containedin=tkProjectLine nextgroup=tkProjectName
syn match	tkMarker		"-"	contained containedin=tkProjectLine nextgroup=tkProjectName
syn match	tkMarker		"+"	contained containedin=tkProjectLine nextgroup=tkProjectName

syn match	tkProjectName	"[0-9A-Za-z\._#]\+"					contained containedin=tkProjectLine nextgroup=tkTime
syn match 	tkTime			"[0-9]\+\:[0-9][0-9]\:[0-9][0-9]"	contained containedin=tkProjectLine,tkJobLine

" syntax for the job line
syn region	tkJobLine		start="^ " end="$"	keepend contains=@NoSpell

" Status markers
syn match	tkStateComplete		"✓"					contained containedin=tkJobLine nextgroup=tkTime
syn match	tkStateComplete		"+"					contained containedin=tkJobLine nextgroup=tkTime
syn match	tkStateAbandoned	"✗"					contained containedin=tkJobLine nextgroup=tkTime
syn match	tkStateAbandoned	"x"					contained containedin=tkJobLine nextgroup=tkTime
syn match	tkStateStarted		"•"					contained containedin=tkJobLine nextgroup=tkTime
syn match	tkStateStarted		"-"					contained containedin=tkJobLine nextgroup=tkTime
syn match	tkJobName			"[0-9A-Za-z\._#]\+"	contained containedin=tkJobName nextgroup=tkTime

" set the colours
hi link tkProjectLine		Normal
hi link tkJobLine			Normal
hi link tkTime				Special
hi link tkMarker			Number
hi link tkJobLine			String
hi link tkProjectName		Identifier
hi link tkStateComplete		col_green
hi link tkStateAbandoned	col_red
hi link tkStateStarted		col_yellow



