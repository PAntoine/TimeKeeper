" vim: ts=4 tw=4 fdm=marker nocin ai :
" ---------------------------------------------------------------------------------
"     file: TimeKeeper
" 
"  ,--------.,--.                 ,--. ,--.                                   
"  '--.  .--'`--',--,--,--. ,---. |  .'   / ,---.  ,---.  ,---.  ,---. ,--.--.
"     |  |   ,--.|        || .-. :|  .   ' | .-. :| .-. :| .-. || .-. :|  .--'
"     |  |   |  ||  |  |  |\   --.|  |\   \\   --.\   --.| '-' '\   --.|  |   
"     `--'   `--'`--`--`--' `----'`--' '--' `----' `----'|  |-'  `----'`--'   
"
"     desc: This plugin will keep track of the time spent in the editor. Will
"           try and workout how much time is being spent on the current activity.
"           It will allocate the time that is spent on the current task.
"
"           The timekeeping is organised by jobs and the jobs are grouped in the
"           projects.
"			
"			The timesheet data is stored in a comma separated format, so that
"           it is easy to use and import into different tools. It will stored
"           by default in the $(HOME)/timesheet.tmk
"
"           This plugin will also allow for the timesheet data to be added as a
"           git note. This will allow for the time to be read by software that
"           can read the contents of these notes.
"
"           The git notes are only added to the current branch for the current 
"           job, hopefully this will reduce the problems that git-notes have with
"           push/branching and merging.
"
"           This plugin will handle multiple instances of vim. It will let the
"           first instance of vim be the server and all others will send the updates
"           to the instance that is the server. If that instance goes away then the
"           first instance to notice will become the server.
"
"           The following flags effect the way that the plugin behaves:
"
"           config variable                  description
"           ---------------                  ---------------------------------------
"           g:TimeKeeperAwayTimeSec	         If the user does not type for this 
"                                            amount of time it is assumed that they
"                                            were away from the keyboard and the 
"                                            time is not registered. [360]
"           g:TimeKeeperDefaultProject		 The default project to add time to ['default']
"           g:TimeKeeperDefaultJob           The default job to add time to ['default']
"           g:TimeKeeperUseGitProjectBranch  If vim is in a git repository use the 
"                                            directory name as the project name and the
"                                            branch name as the job name. [1]
"           g:TimeKeeperUpdateFileTimeSec    The frequency that the timesheet file
"                                            will be updated. [60 * 15 - 15 mins]
"           g:TimeKeeperUseLocal             If this flag is set then the timekeeper
"                                            will create a file at the cwd of the
"                                            editor. [+clientsever:0, else 1]
"           g:TimeKeeperFileName             The filename that the timesheet will be
"                                            saved to. [(.)timekeeper.tmk] 
"           g:TimeKeeperUseGitNotes          If this flag is set then timekeeper will
"                                            create a git note in the current branch
"                                            if the editor is in a git repository. It
"                                            will create a note with the ref of you
"                                            guessed it "timekeeper". It will try and
"                                            keep the entries separate as it will use
"                                            the user.email as the key for the entries.[0]
"           g:TimeKeeperGitNoteUpdateTimeSec The time that the git notes will be updated
"                                            this is not that important as it re-writes
"                                            the note, but will cause you git history
"                                            to get quite large if you update the notes
"                                            too frequently.
"			g:TimeKeeperWorkingWeekLength	 Number of days in the working week [5]
"			g:TimeKeeperWorkingDaySecs		 Number of seconds in the working day [27000]
"			g:TimeKeeperUseAnnotatedTags     If set to '1' then use the annotated tags
"                                            to look for the current job name. It also
"                                            will fall back to the branch name if the
"                                            tag is not set.[0]
"           g:TimeKeeperTagPrefix            This is the prefix to the tag that is to
"                                            be removed before the job name is taken from
"                                            the tag.
"			g:TimeKeeperDontUseUnicode		 If exists then the Task List will use standard
"                                            ascii chars and the extended chars. [0]
"           g:TimeKeeperStartOnLoad          Start the TimeKeeper on vim load, this 
"                                            should not be done before the default file
"                                            has been created by running the start.
"
"   author: Peter Antoine
"     date: 16/11/2012 18:05:21
" ---------------------------------------------------------------------------------
"                    Copyright (c) 2012 - 2013 Peter Antoine
"                             All rights Reserved.
"                     Released Under the Artistic Licence
" ---------------------------------------------------------------------------------
"
" This plugin has a global dictionary so the plugin should only be loaded ones.
"
if exists("s:TimeKeeperPlugin")
	finish
endif

" Script Initialisation block												{{{
	let s:TimeKeeperPlugin = 1
	let s:TimeKeeperIsTracking = 0

	if !exists("g:TimeKeeperDontUseUnicode") || g:TimeKeeperDontUseUnicode == 0
		let s:TimeKeeperCompleted	= '✓'
		let s:TimeKeeperAbandoned	= '✗'
		let s:TimeKeeperStarted   	= '•'
		let s:TimeKeeperCreated   	= ' '
		let s:TimeKeeperClosed		= '▸'
		let s:TimeKeeperOpen		= '▾'
		let s:TimeKeeperHasNote		= '§'

	else
		let s:TimeKeeperCompleted	= '+'
		let s:TimeKeeperAbandoned	= 'x'
		let s:TimeKeeperStarted		= '-'
		let s:TimeKeeperCreated		= ' '
		let s:TimeKeeperClosed		= '-'
		let s:TimeKeeperOpen		= '+'
		let s:TimeKeeperHasNote		= '<'
	endif

	" global settings
	if !exists("g:TimeKeeperAwayTimeSec")
		let g:TimeKeeperAwayTimeSec = 360    			" 5ive minutes and then assume that the time was not working time.
	endif

	if !exists("g:TimeKeeperDefaultProject")
		let g:TimeKeeperDefaultProject = 'default'		" the name of the default/current project
	endif

	if !exists("g:TimeKeeperDefaultJob")
		let g:TimeKeeperDefaultJob = 'default'			" the name of the default/current job
	endif

	if !exists("g:TimeKeeperUseGitProjectBranch")
		let g:TimeKeeperUseGitProjectBranch = 1			" use the Git repository as the project name, and the branch as the job
	endif

	if !exists("g:TimeKeeperUpdateFileTimeSec")
		let g:TimeKeeperUpdateFileTimeSec = 60 * 15		" time before the timesheet is written to the file
	endif

	" deprecated !!! It's pointless and annoying
	" want to be able to do this on a project basis and
	" check the files into the repo.
	"if !exists("g:TimeKeeperUseLocal")
	"	if (has('clientserver'))
	"		let g:TimeKeeperUseLocal = 0				" Use the file local to where the browser was started or use the user default
	"	else
	"		let g:TimeKeeperUseLocal = 1				" Default to local, as without clientserver there will be race conditions.
	"	endif
	"endif

	if !exists("g:TimeKeeperFileName")					" What file should the TimeKeeper store the timesheet in.
		if filewritable('.timekeeper.tmk') || filereadable('.timekeeper.tmk')	" If the file exists try to use, it will fail later.
			let g:TimeKeeperFileName = '.timekeeper.tmk'
		else
			let g:TimeKeeperFileName = $HOME . '/' . '.timekeeper.tmk'			" else default to the global one
		endif
	endif

	if !exists("g:TimeKeeperUseGitNotes")				" If vim is in a git repository add git notes with the time periodically
		let g:TimeKeeperUseGitNotes = 0
	endif

	if !exists("g:TimeKeeperGitNoteUpdateTimeSec")
		let g:TimeKeeperGitNoteUpdateTimeSec = 60 * 60	" Update the git note once an hour - This will only be updated when the timesheet is updates.
	endif
	
	if !exists("g:TimeKeeperWorkingWeekLength")			" Number of days in the working week
		let g:TimeKeeperWorkingWeekLength = 5
	endif

	if !exists("g:TimeKeeperWorkingDaySecs")			" number of seconds in the working day
		let g:TimeKeeperWorkingDaySecs = float2nr(7.5*60*60)
	endif

	if !exists("g:TimeKeeperUseAnnotatedTags")			" default to not using annotated tags
		let g:TimeKeeperUseAnnotatedTags = 0
	else
		if !exists("g:TimeKeeperTagPrefix")				" the tag prefix for the tag versions
			let g:TimeKeeperTagPrefix = ''
		endif
	endif

	" Set the flag start on Load
	if !exists("g:TimeKeeperStartOnLoad")
		let g:TimeKeeperStartOnLoad = 0
	endif

	" internal data structures for holding the projects
	let s:current_job = g:TimeKeeperDefaultJob
	let s:project_list = {}
	let s:saved_sections = {}
	let s:current_section_number = 0

	" script level functions to start time capture
	let s:list_time_called = 0
	let s:user_stopped_typing = localtime()
	let s:user_started_typing = localtime()
	let s:last_update_time = localtime()
	let s:last_note_update_time = 0						" use zero to forced the update on start
	let s:current_job = g:TimeKeeperDefaultJob
	let s:current_project = g:TimeKeeperDefaultProject
	let s:current_server = ''
	let s:file_update_time = localtime()
	let s:start_editor_time = localtime()
	let s:start_tracking_time = 0
	
	" internal window states
	let s:tasklist_help = 0
	let s:note_window_open = 0
	let s:current_note_project = ''
	let s:current_note_job = ''

	" the help text for the tasklist
	let s:tasklist_helptext = [	'? help - to remove',
							\	'',
							\	'Listing controls',
							\	'<cr>  - Toggle job/project',
							\	'x     - close a project listing',
							\	'',
							\	'Item Controls',
							\	'A     - Add new project',
							\	'a     - add new job',
							\	't     - add time to job',
							\	'n     - toggle the notes',
							\	'd     - Delete a job',
							\	'',
							\	'Note Window Commands',
							\	'<C-S> - Save and close note',
							\	'<C-X> - Abandon and close note',
							\	'<C-L> - return to list window',
							\	'',
							\	'' ]

	" set up time strings
	let s:working_week_secs = g:TimeKeeperWorkingDaySecs * g:TimeKeeperWorkingWeekLength

	let s:times = {	'm':60,'min':60,'mins':60,'minutes':60,
				\	'h':3600,'hour':3600,'hours':3600,
				\	'd': g:TimeKeeperWorkingDaySecs,'day':g:TimeKeeperWorkingDaySecs,'days':g:TimeKeeperWorkingDaySecs,
				\	'w': s:working_week_secs,'week': s:working_week_secs,'weeks': s:working_week_secs}

	" needed to hold the start dir so the :cd changes can be detected
	let s:current_dir = getcwd()

	augroup TimeKeeper						" Create the group to hold all the events.
"																			}}}
" PUBLIC FUNCTIONS
" FUNCTION: TimeKeeper_StopTracking() 						 				{{{
"  
" This function will stop the TimeKeeper tracking the users time.
"
" vars:
"      none.
" returns:
"      nothing.
"
function! TimeKeeper_StopTracking()
	au! TimeKeeper
	call TimeKeeper_UpdateJob(s:current_project,s:current_job,(s:user_stopped_typing - s:user_started_typing),1)
	
	" check to see if we need to update the git note
	if g:TimeKeeperUseGitNotes
		call s:TimeKeeper_UpdateGitNote()
	endif

endfunction
"																			}}}
" FUNCTION: TimeKeeper_StartTracking()  									{{{
"  
" This function will start the TimeKeeper tracking the users time.
"
" vars:
"      none.
" returns:
"      nothing.
"
function! TimeKeeper_StartTracking()
	call s:TimeKeeper_LoadTimeSheet()

	call s:TimeKeeper_FindServer()
	
	let s:TimeKeeperIsTracking = 1

	if g:TimeKeeperUseGitProjectBranch
		call s:TimeKeeper_SetJobNameFromGitRepository()
	endif

	if s:current_project == ''
		let s:current_project = g:TimeKeeperDefaultProject
	endif

	if s:current_job == ''
		let s:current_job = g:TimeKeeperDefaultJob
	endif

	call s:TimeKeeper_AddJob(s:current_project,s:current_job)

	let s:start_tracking_time = s:project_list[s:current_project].job[s:current_job].total_time

	au TimeKeeper CursorHoldI * nested call s:TimeKeeper_UserStoppedTyping()
	au TimeKeeper CursorHold  * nested call s:TimeKeeper_UserStoppedTyping()
	au TimeKeeper FocusLost   * nested call s:TimeKeeper_UserStoppedTyping()
	au TimeKeeper VimLeave    * nested call TimeKeeper_StopTracking()

	if g:TimeKeeperUseGitProjectBranch
		au TimeKeeper CmdwinLeave : call s:TimeKeeper_CheckForCWDChange()
	endif
endfunction
"																			}}}
" FUNCTION: TimeKeeper_GetCurrentJobString() 								{{{
"  
" This function will return the current job string and the time that the current
" job has taken so far.
"
" vars:
"      none.
" returns:
"      string = "<project>.<job>#dd:hh:mm"
"   or string = <not tracking> - when timekeeper is not tracking.
"
function! TimeKeeper_GetCurrentJobString()
	
	if s:TimeKeeperIsTracking == 1
		return s:current_project . '.' . s:current_job . '#' . s:TimeKeeper_GetTimeString(s:project_list[s:current_project].job[s:current_job].total_time)
	else
		return '<not tracking>'
	endif

endfunction
"																			}}}
" FUNCTION: TimeKeeper_GetElapsedTime() 									{{{
"  
" This function will return the time since the time capturing was started.
"
" vars:
"      none.
" returns:
"      string = "<project>.<job>#dd:hh:mm"
"
function! TimeKeeper_GetElapsedTime()
	
	if s:TimeKeeperIsTracking == 1
		return s:current_project . '.' . s:current_job . '#' . s:TimeKeeper_GetTimeString(localtime() - s:start_editor_time)
	else
		return ''
	endif

endfunction
"																			}}}
" FUNCTION: TimeKeeper_GetProjectTimeString() 								{{{
"  
" This function will return the current projects time.
"
" vars:
"      none.
" returns:
"      string = "<project>#dd:hh:mm"
"
function! TimeKeeper_GetProjectTimeString()
	
	if s:TimeKeeperIsTracking == 1
		return s:current_project . '#' . s:TimeKeeper_GetTimeString(s:project_list[s:current_project].total_time)
	else
		return ''
	endif

endfunction
"																			}}}
" FUNCTION: TimeKeeper_GetJobStartTimeString() 								{{{
"  
" This function will return the current projects time.
"
" vars:
"      none.
" returns:
"      string = "<project>#dd:hh:mm"
"
function! TimeKeeper_GetJobStartTimeString()
	
	if s:TimeKeeperIsTracking == 1
		return s:current_project . '.' . s:current_job . '#' . strftime("%Y/%m/%d-%H:%M",s:project_list[s:current_project].job[s:current_job].start_time)
	else
		return ''
	endif

endfunction
"																			}}}
" FUNCTION: TimeKeeper_GetJobSessionTime() 									{{{
"  
" This function will return the time added this session.
"
" vars:
"      none.
" returns:
"      string = "<project>#dd:hh:mm"
"
function! TimeKeeper_GetJobSessionTime()
	
	if s:TimeKeeperIsTracking == 1
		return s:current_project . '.' . s:current_job . '#' . s:TimeKeeper_GetTimeString(s:project_list[s:current_project].job[s:current_job].total_time - s:start_tracking_time)
	else
		return ''
	endif

endfunction
"																			}}}
" FUNCTION: TimeKeeper_GetAllJobStrings() 									{{{
"  
" This function will return a list that is made up all the jobs.
"
" vars:
"      none.
" returns:
"      string = "<project>.<job>#dd:hh:mm"
"
function! TimeKeeper_GetAllJobStrings()
	
	let output = []
	
	if s:TimeKeeperIsTracking == 1
		" Ok, lets build the output List of lists that need to be written to the file.
		for project_name in keys(s:project_list)
			for job_name in keys(s:project_list[project_name].job)
				let el_time_mins  = (s:project_list[project_name].job[job_name].total_time / 60) % 60
				let el_time_hours = ((s:project_list[project_name].job[job_name].total_time / (60*60)) % 24)
				let el_time_days  = (s:project_list[project_name].job[job_name].total_time / (60*60*24))
		
				let line = project_name . '.' . job_name . '#' . el_time_days . ':' . el_time_hours . ':' . el_time_mins

				call add(output,line)
			endfor
		endfor
	endif

	return output
endfunction
"																			}}}
" FUNCTION: TimeKeeper_SaveTimeSheet(timesheet_file)  						{{{
"
" This function will save the timesheet to the given file.
"
" The format of the time sheet is a basic comma separated file that has the following
" format:
" 
"      project, job, start_time, total_time
"
" Not all times are seconds from the start of the unix epoc.
"
" vars:
"	timesheet	The file to open as a timesheet
"
" returns:
"	1 - If the database could be loaded.
"	0 - If the database failed to load.
"
function! TimeKeeper_SaveTimeSheet(create)
	let result = 0

	" Only update the file if we are the server else leave it alone
	if s:current_server == ''
		if !a:create && !filewritable(g:TimeKeeperFileName)
			call s:TimeKeeper_ReportError("time sheet file is not writable: " . g:TimeKeeperFileName)
		else
			" check to make sure the timesheet has not been updated elsewhere (i.e. the githooks)
			if s:file_update_time < getftime(g:TimeKeeperFileName)
				call s:TimeKeeper_LoadTimeSheet()
			endif

			" The list that will become the file
			let output = []

			for saved_section in keys(s:saved_sections)
				if saved_section == s:current_section_number
					" Ok, lets build the output List of lists that need to be written to the file.
					call add(output,'[' . hostname() . ':' . $USER . ']')

					let project_list = sort(keys(s:project_list))

					for project_name in project_list
						let job_list = sort(keys(s:project_list[project_name].job))

						for job_name in job_list
							let line = project_name . ',' . job_name . ',' . 
								\ s:project_list[project_name].job[job_name].start_time . ',' .
								\ s:project_list[project_name].job[job_name].total_time . ',' .
								\ s:project_list[project_name].job[job_name].last_commit_time . ',' .
								\ s:project_list[project_name].job[job_name].status . ',' .
								\ s:project_list[project_name].job[job_name].notes

							call add(output,line)
						endfor
					endfor
				else
					" Output the saved section - unchanged
					call extend(output,s:saved_sections[saved_section])
				endif
			endfor
			
			" write the result to a file
			call writefile(output,g:TimeKeeperFileName)

			" update the times
			let s:last_update_time = localtime()
			let s:file_update_time = getftime(g:TimeKeeperFileName)
		endif
	endif
endfunction
"																			}}}
" FUNCTION: TimeKeeper_IsServer()  											{{{
"
" This function will find the current server.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! TimeKeeper_IsServer()
	if s:current_server == ''
		return 'yes'
	else
		return 'no'
	endif
endfunction
"																			}}}
" FUNCTION: TimeKeeper_AddAdditionalTime()  								{{{
"
" This function will add additional time to the current project.
" The format of the time string that is to be used is one of the following:
" 
"   (time) (units)
"
" 'time' can be specfied as a simple real number, i.e. 1, or 1.5
" 'units' are minutes,hours,days,weeks or m,h,d,w,min,mins,minutes,etc...
"
" vars:
"	none
"
" returns:
"	nothing
"
function! TimeKeeper_AddAdditionalTime(...)
	if a:0 == 2
		let project_name = a:1
		let job_name = a:2
	else
		let project_name = s:current_project
		let job_name = s:current_job
	endif

	let time_string = input("Time to Add: ","")
	echomsg ''

	if !empty(time_string)
		let time = s:TimeKeeper_ConvertTimeStringToSeconds(time_string)
		if time > 0
			call TimeKeeper_UpdateJob(project_name,job_name,time,0)
		endif
	endif
endfunction
"																			}}}
" FUNCTION: TimeKeeper_ToggleTaskWindow()  									{{{
"
" This function will toggle the task window.
" vars:
"	none
"
" returns:
"	nothing
"
function! TimeKeeper_ToggleTaskWindow()

	if !exists("s:gitlog_loaded") || bufwinnr(bufnr("__TimeKeeper_Task__")) == -1
		call s:TimeKeeper_OpenTaskWindow()
		let s:gitlog_loaded = 1
	else
		unlet s:gitlog_loaded
		
		if bufwinnr(bufnr("__TimeKeeper_Notes__")) != -1
			" close the note window - and save the changes
			call s:TimeKeeper_ToggleNoteWindow('','')
		endif

		if bufwinnr(bufnr("__TimeKeeper_Task__")) != -1
			silent exe "bwipeout __TimeKeeper_Task__"
		endif
	endif

endfunction
"																			}}}
" FUNCTION: TimeKeeper_HandleKeypress()  									{{{
"
" This function will toggle the state of the list item for the particular
" item.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! TimeKeeper_HandleKeypress(command)
	" check that the winodw is actually open
	if bufwinnr(bufnr("__TimeKeeper_Task__")) != -1
		let curr_line = line(".")
		let done = 0
		let do_update = 1

		if a:command == 'help'
			if s:tasklist_help == 1
				let s:tasklist_help = 0
			else
				let s:tasklist_help = 1
			endif

			" update the tasklist
			call s:TimeKeeper_UpdateTaskList()

		elseif a:command == 'add_project'
			let new_project_name = input("project name: ","")

			if new_project_name != ""
				let new_job_name = input("job name: ","")

				if new_job_name != ""
					call TimeKeeper_UpdateJob(new_project_name,new_job_name,0,1)
				endif
			endif

			" update the tasklist
			call s:TimeKeeper_UpdateTaskList()

		elseif a:command == 'save_notes'
			" going to use the toggle with no name - will close the note window
			call s:TimeKeeper_ToggleNoteWindow('','')

		elseif a:command == 'close_notes'
			" just close the note window
			if bufwinnr(bufnr("__TimeKeeper_Notes__")) != -1
				silent exe "bwipeout __TimeKeeper_Notes__"
			endif

		elseif curr_line > s:TimeKeeper_TopListLine && curr_line < s:TimeKeeper_BottomListLine
			" Ok, it's in the menu.
			let done = 0
			let prev_project = ''

			for project_name in keys(s:project_list)
	
				if s:TimeKeeper_DoHandleKeypress(a:command,project_name,prev_project,0) == 1
					let done = 1
					break
				endif

				let prev_project = project_name
			endfor

			if done == 0
				call s:TimeKeeper_DoHandleKeypress(a:command,project_name,prev_project,1)
			endif
		endif
	endif
endfunction
"																			}}}
" INTERNAL FUNCTIONS
" FUNCTION: TimeKeeper_UpdateJob(project_name,job_name,time,force)				{{{
"
" NOTE: This job is not script local so it can be called remotely.
"
" This function will update a job with the time that has elapsed.
"
" If there is server running it will send the update to the server. It will
" also call the file update if required.
" 
" vars:
"	project_name	The name of the project.
"	job_name		The name of the job.
"	time			The time that is to be added to the job.
"   force			Update the file now.
"
" returns:
"	nothing
"
function! TimeKeeper_UpdateJob(project_name, job_name, time, force)
	" track the time
	let job = s:TimeKeeper_AddJob(a:project_name,a:job_name)
	
	let job.total_time += a:time
	let s:project_list[a:project_name].total_time += a:time

	" if we are master do the update
	if s:current_server == ''
		" check to see if we need to update the timesheet file
		if a:force == 1 || ((s:last_update_time + g:TimeKeeperUpdateFileTimeSec) < localtime())
			" Ok. we have to update the file now.
			call TimeKeeper_SaveTimeSheet(0)
		endif
	else
		" Ok, we are not the server, we need to update the server
		let job_string = "TimeKeeper_UpdateJob('" . a:project_name . "','" . a:job_name . "'," . a:time . "," . a:force . ")"
		
		try 
			call remote_expr(s:current_server,job_string)
		catch /E449/
			" find the server
			call s:TimeKeeper_FindServer()

			if s:current_server == ''
				" check to see if we need to update the timesheet file - as we are now master
				if a:force == 1 || ((s:last_update_time + g:TimeKeeperUpdateFileTimeSec) < localtime())
					" Ok. we have to update the file now.
					call TimeKeeper_SaveTimeSheet(0)
				endif
			else
				try 
					call remote_expr(s:current_server,job_string)
				catch /E449/
					TimeKeeper_ReportError("can't update the remote server")
				endtry
			endif
		endtry
	endif
endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_DoHandleKeypress()  								{{{
"
" This function will toggle the state of the list item for the particular
" item.
"
" vars:
"	none
"
" returns:
"	0 - if keypress unhandled
"   1 - if keypress handled
"
function! s:TimeKeeper_DoHandleKeypress(command,project_name,prev_project,is_last)
	let curr_line = line(".")
	let done = 0

	if s:project_list[a:project_name].lnum == curr_line
		" The keys for the project timeline

		if a:command == 'toggle'
			" we have the current project
			if !exists("s:project_list[a:project_name].opened") || s:project_list[a:project_name].opened == 0 
				let s:project_list[a:project_name].opened = 1
			else
				let s:project_list[a:project_name].opened = 0
			endif
		elseif a:command == 'add'
			let new_job_name = input("[" . a:project_name . "] job name: ","")
			echomsg ''

			if  new_job_name != ""
				call TimeKeeper_UpdateJob(a:prev_project,new_job_name,0,1)
			endif
		endif
		
		let done = 1
			
		" update the tasklist
		call s:TimeKeeper_UpdateTaskList()

	elseif s:project_list[a:project_name].lnum > curr_line || a:is_last == 1
		" The keys for the indevidual jobs

		if a:command == 'add'
			let new_job_name = input("[" . a:prev_project . "] job name: ","")
			echomsg ''

			if new_job_name != ""
				call TimeKeeper_UpdateJob(a:prev_project,new_job_name,0,1)
			endif
		
			" update the tasklist
			call s:TimeKeeper_UpdateTaskList()

		elseif a:command == 'time'
			for job_name in keys(s:project_list[a:prev_project].job)

				if s:project_list[a:prev_project].job[job_name].lnum == curr_line
					call TimeKeeper_AddAdditionalTime(a:prev_project,job_name)
					break
				endif
			endfor
			
			" update the tasklist
			call s:TimeKeeper_UpdateTaskList()

		elseif a:command == 'notes'
			for job_name in keys(s:project_list[a:prev_project].job)

				if s:project_list[a:prev_project].job[job_name].lnum == curr_line
					call s:TimeKeeper_ToggleNoteWindow(a:prev_project,job_name)
					break
				endif
			endfor

		elseif a:command == 'close'
			let s:project_list[a:prev_project].opened = 0
   			let here = getpos(".")
			let here[1] = s:project_list[a:prev_project].lnum
			call setpos(".",here)
			
			" update the tasklist
			call s:TimeKeeper_UpdateTaskList()

		else
			" Ok, it's in the previous projects list
			for job_name in keys(s:project_list[a:prev_project].job)

				if s:project_list[a:prev_project].job[job_name].lnum == curr_line

					if a:command == 'delete'
						if s:current_project == a:prev_project && s:current_job == job_name
							call s:TimeKeeper_ReportError("Cannot delete the current job")
						else
							let confirm_delete = input("[" . a:prev_project . "." . job_name . "] Type [Y]es to Delete: ","")
							echomsg ''

							if confirm_delete == "Y" || confirm_delete == "Yes" || confirm_delete == "yes" || confirm_delete == 'y'
								unlet s:project_list[a:prev_project].job[job_name]

								" null update to remove the item from the file
								call TimeKeeper_UpdateJob(s:current_project,s:current_job,0,1)
							endif
						endif
					else
						if s:project_list[a:prev_project].job[job_name].status == 'created'
							let s:project_list[a:prev_project].job[job_name].status = 'started'
						
						elseif s:project_list[a:prev_project].job[job_name].status == 'started'
							let s:project_list[a:prev_project].job[job_name].status = 'completed'

						elseif s:project_list[a:prev_project].job[job_name].status == 'completed'
							let s:project_list[a:prev_project].job[job_name].status = 'abandoned'

						else
							let s:project_list[a:prev_project].job[job_name].status = 'created'
						endif
					
						call TimeKeeper_UpdateJob(a:prev_project,job_name,0,1)
					endif

					break
				endif
			endfor
		
			" update the tasklist
			call s:TimeKeeper_UpdateTaskList()
		endif
			
		let done = 1
	endif

	return done
endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_GetTimeString(time) 								{{{
"  
" This function will return the current job string and the time that the current
" job has taken so far.
"
" vars:
"      none.
" returns:
"      string = "<project>.<job>#dd:hh:mm"
"
function! s:TimeKeeper_GetTimeString(time)
	
	let el_time_mins  = (a:time / 60) % 60
	let el_time_hours = (a:time / (60*60)) % 24
	let el_time_days  = (a:time / (60*60*24))

	if (el_time_hours < 10)
		let el_time_hours = '0' . el_time_hours
	endif
	
	if (el_time_mins < 10)
		return el_time_days . ':' . el_time_hours . ':0' . el_time_mins
	else
		return el_time_days . ':' . el_time_hours . ':' . el_time_mins
	endif

endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_FindServer()  										{{{
"
" This function will find the current server.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:TimeKeeper_FindServer()
	let old_server = s:current_server
	let s:current_server = ''

	" only bother checking if have clientserver
	if (has('clientserver'))
		let server_list = split(serverlist())

		for server in server_list
			if server != v:servername
				try
					if remote_expr(server,'TimeKeeper_IsServer()') == 'yes'
						let s:current_server = server
						break
					endif
				catch /E449/
					" do nothing - it is not running the script
				endtry
			endif
		endfor
	endif

	if (s:current_server == '') && (old_server != s:current_server)
		call s:TimeKeeper_UpdateTimeSheet()
	endif
endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_ReportError(error_message)  						{{{
"
" This function will report an error that occurred.
"
" vars:
"	error_message	This is the error/warning to report.
"
function! s:TimeKeeper_ReportError(error_message)
	echohl WarningMsg
	echomsg a:error_message
	echohl Normal
endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_AddJob(project_name,job_name)  						{{{
"
" This function will add a job to the project/job database. If the project
" does not exist it will be created, and if the job does not exist that will
" also be created as well.
"
" vars:
"	project_name	The project that the job should be created in.
" 	job_name		This is the job to create.
"
function! s:TimeKeeper_AddJob(project_name,job_name)
	" check to see if it is a new project
	if !has_key(s:project_list,a:project_name)
		let s:project_list[a:project_name] = {'total_time':0, 'num_jobs': 1, 'job': {} }
	endif

	" check to see if it is a new job that we are dealing with
	if !has_key(s:project_list[a:project_name].job,a:job_name)

		let s:project_list[a:project_name].job[a:job_name] = {	'total_time'		: 0,
															\	'start_time'		: localtime(),
															\	'last_commit_time'	: 0,
															\	'status'			: 'created',
															\	'notes'				: ''}
	endif

	return s:project_list[a:project_name].job[a:job_name]
endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_ImportJob(values)  								{{{
"
" This function will import a job into the timesheet dictionary.
" 
" format:
" 
"      values = [project, job, start_time, total_time]
"
" Not all times are seconds from the start of the unix epoc.
"
" vars:
"	values	The values for the job to be imported.
" returns:
"	nothing
"
function! s:TimeKeeper_ImportJob(values)
	if len(a:values) >= 5
		" set the job values
		let job = s:TimeKeeper_AddJob(a:values[0],a:values[1])
		let job.start_time		 = a:values[2]
		let job.total_time		 = a:values[3]
		let job.last_commit_time = a:values[4]

		if len(a:values) >= 6
			let job.status			 = a:values[5]
		else
			let job.status			 = 'created'
		endif

		if len(a:values) >= 7
			let job.notes			= a:values[6]
		else
			let job.notes			= ''
		endif

		"set the project totals
		let s:project_list[a:values[0]].total_time	+= a:values[3]
		let s:project_list[a:values[0]].num_jobs	+= 1
	endif
endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_UpdateGitNote()									{{{
" 
" This function will read in the git note from the current branch and then
" find the line that matches the current job in the note and then write the
" note back. This will use a temporary file that is used to do the write back
" a this is the only sane way to get a multilined note back in to git. 
"
" This code forces the add so that it will create/update the note. As the 
" order of the lines in the note are preserved and only the current job is
" updated (for the current user) the note should not clash when merged/pushed
" but we will have to see how well this works in the real world.
"
" vars:
"	none
"
" returns:
"	nothing.
"
function! s:TimeKeeper_UpdateGitNote()
	redir => git_note_contents
	silent execute "!git --no-pager notes --ref=timekeeper show"
	redir END
	
	" git quire nicely adds x00 for some reason to outputs - and remove the command line
	let time_notes = split(substitute(git_note_contents,'[\x00]',"","g"),"\x0d")
	call remove(time_notes,0)
	
	"lets get the users email address - leaving the x00 on the end, we can use this as a delimiter
	let email_address = substitute(system("git config --get user.email"),'[\x00]',",","g")

	" check to see if "error:" starts the string as denotes that there is not a note
	if (strpart(time_notes[0],0,6) == "error:")
		let time_notes = []
		let note_index = 0
		let time_notes = [ email_address . TimeKeeper_GetCurrentJobString() ]
	else
		" Ok, had a note, now find the required name in it
		let name_length = strlen(email_address)
		let index = 0

		while index < len(time_notes)
			if strpart(time_notes[index],0,name_length) == email_address
				let time_notes[index] = email_address . TimeKeeper_GetCurrentJobString()
				break
			endif
			let index += 1
		endwhile

		" extend the list if it was not found in the note
		if (index == len(time_notes))
			call add(time_notes,email_address . TimeKeeper_GetCurrentJobString())
		endif
	endif

	" Ok, now write the updated note back to the repository - only use one temp file
	" don't want to DoS myself by using up all the disk with temp files.
	if !exists("s:gitnote_temp_file") || empty(s:gitnote_temp_file)
		let s:gitnote_temp_file = tempname()
	endif

	call writefile(time_notes,s:gitnote_temp_file)
	silent execute "!git --no-pager notes --ref=timekeeper add --force -F " . s:gitnote_temp_file

	let s:last_note_update_time = localtime()
endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_SetJobNameFromGitRepository()						{{{
"
" This function will search the tree UPWARDS to find the git repository that the 
" file belongs to. If it cannot find the repository then it will generate an error
" and then return an empty string.
"
" vars:
"	none
"
" returns:
"	If there is a .git directory in the tree, it returns the directory that the .git
"	repository is in, else it returns the empty string.
"
function! s:TimeKeeper_SetJobNameFromGitRepository()
	let root = finddir(".git",expand('%:h'). "," . expand('%:p:h') . ";" . $HOME)
	let s:current_job = ''
	
	" get the name of the directory will use as the project name
	let s:current_project = substitute(fnamemodify(root,':p:h:h'),fnamemodify(root,':p:h:h:h') . '/','','')
	
	if g:TimeKeeperUseAnnotatedTags == 1
    	let s:current_job = system("git describe --abbrev=0")
		if len(split(s:current_job,"[\x0a\x0d]")) == 1
			" ok, remove any newlines
			let s:current_job = substitute(s:current_job,"[\x0a\x0d]",'','g')

			if g:TimeKeeperTagPrefix != ''
				" remove the prefix - if it is found
				let s:current_job = substitute(s:current_job,'^' . g:TimeKeeperTagPrefix,'','')
			endif
		else
			" if more than on line then it is an error message
			let s:current_job = ''
		endif
	endif

	if s:current_job == ''
		let branch = ''
		let lines = split(system("git branch 2> /dev/null"),"[\x0a\x0d]")

		" find the current branch
		for line in lines
			if line[0] == '*'
				" remove the indicator
				let branch = strpart(line,2)
				break
			endif
		endfor

		if branch != ''
			let s:current_job = substitute(branch, '\n', '', 'g')
		else
			let s:current_job = ''
		endif
	endif
endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_LoadTimeSheet()  									{{{
"
" This function will load the timesheet that is given. If the timesheet file given
" does not exist it will return an error.
"
" The format of the time sheet is a basic comma separated file that has the following
" format:
" 
"      project, job, start_time, total_time
"
" Not all times are seconds from the start of the unix epoc.
"
" vars:
"	none
"
" returns:
"	1 - If the database could be loaded.
"	0 - If the database failed to load.
"
function! s:TimeKeeper_LoadTimeSheet()
	let result = 0
	
	" If the file does not exist
	if empty(glob(g:TimeKeeperFileName))
		call s:TimeKeeper_RequestCreate()
	else
		
		if !filewritable(g:TimeKeeperFileName)
			call s:TimeKeeper_ReportError("Timesheet file cannot be written")
		
		elseif !filereadable(g:TimeKeeperFileName)
			call s:TimeKeeper_ReportError("Timesheet file cannot be read")

		else
			let timesheet_data = readfile(g:TimeKeeperFileName)
			let found_section = 0
			let max_sections = 0
			
			if !empty(timesheet_data)
				let result = 1
				let skip_section = 0
				let s:current_section_number = 0

				for item in timesheet_data
					if item[0] == '['
						let skip_section = 0
						let max_sections = max_sections + 1

						" we have a user marker, is it ours?
						let divider = stridx(item,":")
						let host_name = strpart(item,1,divider - 1)
						let user_name = strpart(item,divider + 1,strlen(item) - 2 - divider)

						if host_name ==# hostname() && user_name ==# $USER
							" Ok, this is our section, so remember the section number
							let s:current_section_number = max_sections
							let s:saved_sections[max_sections] = [ '[' . host_name . ':' . user_name . ']' ]
							let found_section = 1

						else
							" skip this section
							if host_name == '' || user_name == ''
								call s:TimeKeeper_ReportError("Invalid Timesheet format. Ignoring user section. section: " . item)
							endif
							let skip_section = 1
							let s:saved_sections[max_sections] = [ '[' . host_name . ':' . user_name . ']' ]
						endif
					else
						if skip_section == 1
							" store the skipped sections of the timekeeper file
							call add(s:saved_sections[max_sections],item)

						else
							let values = split(item,',',1)

							"Should now have a list of the items in the line
							call s:TimeKeeper_ImportJob(values)
						endif
					endif
				endfor

				let max_sections = max_sections + 1
				let s:user_last_update_time = localtime()
			endif

			if found_section == 0
				" the section that pertains to this session was not found, add
				let max_sections = max_sections + 1
				let s:saved_sections[max_sections] = [ '[' . hostname() . ':' . $USER . ']' ]
				let s:current_section_number = max_sections
				
			elseif len(s:saved_sections) == 0
				" was the file empty/or no sections were found?
				let s:saved_sections[0] = [ '[' . hostname() . ':' . $USER . ']' ]
			endif
		endif

		let s:file_update_time = getftime(g:TimeKeeperFileName)
	endif

	return result
endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_UpdateTimeSheet()  								{{{
"
" This function will reload the timesheet but will keep the current value of
" the current job. 
"
" This is a race condition and we are voting for what we know, and assume
" there is only one editor in the current job, as this case needs more complex
" code to handle keeping the times in order.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:TimeKeeper_UpdateTimeSheet()
	if has_key(s:project_list,s:current_project) && has_key(s:project_list[s:current_project],s:current_job)
		let current_proj_time = s:project_list[s:current_project].total_time
		let current_job_time = s:project_list[s:current_project].job[s:current_job].total_time
	endif

	" blow away the old db, and load a fresh one.
	let s:project_list = {}
	call s:TimeKeeper_LoadTimeSheet()

	if exists('current_job_time')
		let s:project_list[s:current_project].total_time = current_proj_time
		let s:project_list[s:current_project].job[s:current_job].total_time = current_job_time
	endif
endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_RequestCreate()  									{{{
"
" This function will ask the user before creating the timesheet file.
" 
" vars:
"	timesheet	The file to open as a timesheet
" returns:
"	nothing
"
function! s:TimeKeeper_RequestCreate()
	
	let g:TimeKeeperFileName = input("Please supply TimeKeeper timesheet filename: ",g:TimeKeeperFileName)

	if ( g:TimeKeeperFileName != '' )
		" create the default job
		call s:TimeKeeper_AddJob(g:TimeKeeperDefaultProject,g:TimeKeeperDefaultJob)
		
		" create the current job
		call s:TimeKeeper_AddJob(s:current_project,s:current_job)
		call TimeKeeper_SaveTimeSheet(1)
	endif
endfunction
"																				}}}
" FUNCTION: s:TimeKeeper_ConvertTimeStringToSeconds()						{{{
"
" This function will take the string that has been passed in and convert it
" to seconds.
"
" vars:
"	user_string	This is the string that is to be converted to seconds.
"
" returns:
"	0 - if time is invalid
"   x - The number of seconds as specified.
"
let s:regex_short_time = '^\([0-9]*\|[0-9]*\.[0-9]*\)\s*\(m\|h\|d\|w\|min\|mins\|day\|days\|hour\|week\|hours\|weeks\|minute\|minutes\)$'

function! s:TimeKeeper_ConvertTimeStringToSeconds(user_string)
	let time_list = matchlist(a:user_string,s:regex_short_time)
	let seconds = 0

	if (!empty(time_list))
		let seconds = float2nr(s:times[time_list[2]] * str2float(time_list[1]))
	endif

	return seconds
endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_UserStartedTyping()								{{{
"
" This function will be called when the user has started typing again. This
" function will be called when the user moves the cursor or the editor regains
" keyboard focus.
"
" vars:
"	none
"
function! s:TimeKeeper_UserStartedTyping()
	" Do we throw away the time that the user has been away?
	if (localtime() - s:user_stopped_typing) < g:TimeKeeperAwayTimeSec
		" No, add the elapsed time.
		call TimeKeeper_UpdateJob(s:current_project,s:current_job,(localtime() - s:user_started_typing),0)
	else
		"Yes, just add the stop to start time
		call TimeKeeper_UpdateJob(s:current_project,s:current_job,(s:user_stopped_typing - s:user_started_typing),0)
	endif

	" check to see if we need to update the git note
	if g:TimeKeeperUseGitNotes && (s:last_note_update_time + g:TimeKeeperGitNoteUpdateTimeSec) < localtime()
		"Ok, we have to update the git note now
		call s:TimeKeeper_UpdateGitNote()
	endif

	" update the started typing time
	let s:user_started_typing = localtime()
	let s:user_stopped_typing = localtime()

	" remove the events as these slow down the editor
	au! TimeKeeper CursorMovedI
	au! TimeKeeper CursorMoved
	au! TimeKeeper FocusGained
endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_MapTaskListKeys()									{{{
"
" This function maps the keys that the buffer will respond to. All the keys are
" local to the buffer.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:TimeKeeper_MapTaskListKeys()
	" <cr> toggle the status of a Job/ open close a project
	map <buffer> <silent> <cr>	:call TimeKeeper_HandleKeypress('toggle')<cr>
	" A add a new project
	map <buffer> <silent> A		:call TimeKeeper_HandleKeypress('add_project')<cr>
	" a add a new job
	map <buffer> <silent> a		:call TimeKeeper_HandleKeypress('add')<cr>
	" t add additional time to the job
	map <buffer> <silent> t		:call TimeKeeper_HandleKeypress('time')<cr>
	" d Delete a job
	map <buffer> <silent> d		:call TimeKeeper_HandleKeypress('delete')<cr>
	" close an open project from within the job list
	map <buffer> <silent> x		:call TimeKeeper_HandleKeypress('close')<cr>
	" set the help flag
	map <buffer> <silent> ?		:call TimeKeeper_HandleKeypress('help')<cr>
	" Toggle the Note for the current window
	map <buffer> <silent> n		:call TimeKeeper_HandleKeypress('notes')<cr>

endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_UpdateTaskList()  									{{{
"
" This function will fill the task window with the list of tasks.
"
" vars:
"	timesheet	The file to open as a timesheet
"
" returns:
"	1 - If the database could be loaded.
"	0 - If the database failed to load.
"
function! s:TimeKeeper_UpdateTaskList()
	let result = 0

	let curr_line = getpos(".")

	" we need to be able to write to the buffer
	setlocal modifiable
	let temp = @"
	silent exe "% delete"
	let @" = temp

	let padding = "               "
	let len_padding = len(padding)

	" Ok, lets build the output List of lists that need to be written to the file.
	let output = ['Task List','']
	
	if s:tasklist_help == 1
		call extend(output,s:tasklist_helptext)
	endif

	let s:TimeKeeper_TopListLine = len(output)

	for project_name in keys(s:project_list)
		if project_name ==# s:current_project
			let e_marker = ' *'
		else
			let e_marker = '  '
		endif
	
		if len(project_name) < len(padding)
			let pad_length = len_padding - len(project_name)
		else
			let pad_length = 1
		endif

		if !exists("s:project_list[project_name].opened") || s:project_list[project_name].opened == 0
			" The project is closed, just display the header
			let line = s:TimeKeeperClosed . e_marker . project_name . padding[0:pad_length] . s:TimeKeeper_GetTimeString(s:project_list[project_name].total_time)
			call add(output,line)
			let s:project_list[project_name].lnum = len(output)
		else
			" the project is open, display all the jobs in the project
			let line = s:TimeKeeperOpen . e_marker . project_name . padding[0:pad_length] . s:TimeKeeper_GetTimeString(s:project_list[project_name].total_time)
			call add(output,line)
			let s:project_list[project_name].lnum = len(output)
			
			for job_name in keys(s:project_list[project_name].job)

				if s:project_list[project_name].job[job_name].status == 'completed'
					let marker = s:TimeKeeperCompleted

				elseif s:project_list[project_name].job[job_name].status == 'started'
					let marker = s:TimeKeeperStarted

				elseif s:project_list[project_name].job[job_name].status == 'abandoned'
					let marker = s:TimeKeeperAbandoned

				else
					let marker = s:TimeKeeperCreated
				endif

				" does this job have a note?
				if s:project_list[project_name].job[job_name].notes == ''
					let note_marker = ' '
				else
					let note_marker = s:TimeKeeperHasNote
				endif

				" mark the current job
				if project_name ==# s:current_project && job_name ==# s:current_job
					let line = ' ' . marker . ' ' . s:TimeKeeper_GetTimeString(s:project_list[project_name].job[job_name].total_time) . ' *' . job_name
				else
					let line = ' ' . marker . ' ' . s:TimeKeeper_GetTimeString(s:project_list[project_name].job[job_name].total_time) . '  ' . job_name . ' ' . note_marker
				endif

				call add(output,line)

				let s:project_list[project_name].job[job_name].lnum = len(output)

			endfor
			call add(output,'')
		endif
	endfor
		
	call add(output,'')
	
	let s:TimeKeeper_BottomListLine = len(output)

	call setline(1,output)
	
	call setpos(".",curr_line)

	" mark it as non-modifiable
	setlocal nomodifiable

endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_OpenTaskWindow()									{{{
" 
" This function will open the task window if it is not already open. It will
" fill it with the list of tasks.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:TimeKeeper_OpenTaskWindow()
	if bufwinnr(bufnr("__TimeKeeper_Task__")) != -1
		" window already open - just go to it
		silent exe bufwinnr(bufnr("__TimeKeeper_Task__")) . "wincmd w"
	else
		" window not open need to create it
		let s:buf_number = bufnr("__TimeKeeper_Task__",1)
		silent topleft 40 vsplit
		set winfixwidth
		set winwidth=40
		set winminwidth=40
		silent exe "buffer " . s:buf_number
		setlocal syntax=timekeeper
		setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
	endif
	
	"need to change the window
	setlocal modifiable

	"Now display the list of tasks.
	call s:TimeKeeper_UpdateTaskList()

	" set the keys on the Log window
	call s:TimeKeeper_MapTaskListKeys()

	setlocal nomodifiable
endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_MapNoteWindowKeys()								{{{
"
" This function maps the keys that the buffer will respond to. All the keys are
" local to the buffer.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:TimeKeeper_MapNoteWindowKeys()
	" Close and Save the changes to the current note.
	nmap <buffer> <silent> <C-S>	:call TimeKeeper_HandleKeypress('save_notes')<cr>
	" Discard the changes in the note window.
	nmap <buffer> <silent> <C-X>	:call TimeKeeper_HandleKeypress('close_notes')<cr>
	" Goto the List window if it is open.
	nmap <buffer> <silent> <C-L>	:silent exe bufwinnr(bufnr("__TimeKeeper_Task__")) . "wincmd w"<cr>

endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_ToggleNoteWindow()									{{{
" 
" This function will toggle the note window if it is not already open. It will
" fill it with contents of the given jobs not.
"
" If the window has contents that have either changed on close or being loaded
" with new content then the contents will be saved before exit.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:TimeKeeper_ToggleNoteWindow(project_name, job_name)

	if bufwinnr(bufnr("__TimeKeeper_Notes__")) != -1
		" window already open - just go to it
		silent exe bufwinnr(bufnr("__TimeKeeper_Notes__")) . "wincmd w"
	else
		" window not open need to create it
		let s:buf_number = bufnr("__TimeKeeper_Notes__",1)
		bot 10 split
		silent exe "buffer " . s:buf_number
		setlocal syntax=markdown
		setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap

		" we are creating the window, so the current's cant be valid
		let s:current_note_project = ''
		let s:current_note_job = ''
	endif

	" If the note required matches the current note, do nothing
	if  (s:current_note_project != a:project_name || s:current_note_job != a:job_name) && (a:project_name != '')
		if s:current_note_project != ''
			" Ok, need to save the current state of the note.
			let note_contents = getline(1,"$")
			let note_string = join(note_contents,"\x03")

			if s:project_list[s:current_note_project].job[s:current_note_job].notes != note_string
				" Ok, the note changed, write it to the timekeeper file.
				let s:project_list[s:current_note_project].job[s:current_note_job].notes = note_string
				call TimeKeeper_UpdateJob(s:current_note_project,s:current_note_job,0,1)
			endif
		endif
			
		setlocal modifiable
		let temp = @"
		silent exe "% delete"
		let @" = temp

		" using the "EOT" char as this will not cause problems with the shell scripts.
		" should really use the "BELL" for extra lose. :)
		let window_contents = split(s:project_list[a:project_name].job[a:job_name].notes,"\x03")
		call setline(1,window_contents)

		let s:current_note_project = a:project_name
		let s:current_note_job = a:job_name

		" Now map the keys that are required
		call s:TimeKeeper_MapNoteWindowKeys()
	else
		" The current job is in the window, check the state and close the window.
		let note_contents = getline(1,"$")
		let note_string = join(note_contents,"\x03")

		if s:project_list[s:current_note_project].job[s:current_note_job].notes != note_string
			" Ok, the note changed, write it to the timekeeper file.
			let s:project_list[s:current_note_project].job[s:current_note_job].notes = note_string
			call TimeKeeper_UpdateJob(s:current_note_project,s:current_note_job,0,1)
		endif

		" now close the window
		if bufwinnr(bufnr("__TimeKeeper_Notes__")) != -1
			exe "bwipeout __TimeKeeper_Notes__"
		endif
	endif

endfunction
"																			}}}
" AUTOCMD FUNCTIONS
" FUNCTION: s:TimeKeeper_UserStartedTyping()								{{{
"
" This function will be called when the user has started typing again. This
" function will be called when the user moves the cursor or the editor regains
" keyboard focus.
"
" vars:
"	none
"
function! s:TimeKeeper_UserStartedTyping()
	" Do we throw away the time that the user has been away?
	if (localtime() - s:user_stopped_typing) < g:TimeKeeperAwayTimeSec
		" No, add the elapsed time.
		call TimeKeeper_UpdateJob(s:current_project,s:current_job,(localtime() - s:user_started_typing),0)
	else
		"Yes, just add the stop to start time
		call TimeKeeper_UpdateJob(s:current_project,s:current_job,(s:user_stopped_typing - s:user_started_typing),0)
	endif

	" check to see if we need to update the git note
	if g:TimeKeeperUseGitNotes && (s:last_note_update_time + g:TimeKeeperGitNoteUpdateTimeSec) < localtime()
		"Ok, we have to update the git note now
		call s:TimeKeeper_UpdateGitNote()
	endif

	" update the started typing time
	let s:user_started_typing = localtime()
	let s:user_stopped_typing = localtime()

	" remove the events as these slow down the editor
	au! TimeKeeper CursorMovedI
	au! TimeKeeper CursorMoved
	au! TimeKeeper FocusGained
endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_UserStoppedTyping()								{{{
"
" This function will be called when the user has stopped typing for the time
" that is specified in the updatetime system variable.
"
" vars:
"	none
"
function! s:TimeKeeper_UserStoppedTyping()
	let s:user_stopped_typing = localtime()

	" check to see if we need to update the timesheet file
	if (s:last_update_time + g:TimeKeeperUpdateFileTimeSec) < s:user_stopped_typing
		" Ok. we have to update the file now.
		call TimeKeeper_SaveTimeSheet(0)
	endif

	" we need to wait for the Cursor to move as this is the user doing work again.
	au TimeKeeper CursorMovedI * nested call s:TimeKeeper_UserStartedTyping()
	au TimeKeeper CursorMoved  * nested call s:TimeKeeper_UserStartedTyping()
	au TimeKeeper FocusGained  * nested call s:TimeKeeper_UserStartedTyping()
	  
endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_CheckForCWDChange()								{{{
"
" This function will check that after the user has exited the ':' command if
" the current directory has changed. If so if it is set to use local timesheets
" rather than global ones, it will check to see if the timesheet will have
" changed and will have to reload.
"
" vars:
"	none
"
function! s:TimeKeeper_CheckForCWDChange()
	" has the directory changed? 	
	if s:current_dir != getcwd()
		call s:TimeKeeper_SaveTimeSheet(0)
		call s:TimeKeeper_LoadTimeSheet()
	
		" This should stop it failing over if there is a problem
		call s:TimeKeeper_AddJob(s:current_project,s:current_job)
	endif
endfunction
"																			}}}
" Start tracking if the user wants us to.
if g:TimeKeeperStartOnLoad
	call TimeKeeper_StartTracking()
endif

