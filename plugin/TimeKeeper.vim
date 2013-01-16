" vim: ts=4 tw=4 fdm=marker :
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
"           g:TimeKeeperStartOnLoad          Start the TimeKeeper on vim load, this 
"                                            should not be done before the default file
"                                            has been created by running the start.
"
"   author: Peter Antoine
"     date: 16/11/2012 18:05:21
" ---------------------------------------------------------------------------------
"                      Copyright (c) 2012 Peter Antoine
"                             All rights Reserved.
"                     Released Under the Artistic Licence
" ---------------------------------------------------------------------------------
"
" This plugin has a global dictionary so the plugin should only be loaded ones.
"
if !exists("s:TimeKeeperPlugin")
" Script Initialisation block												{{{
	let s:TimeKeeperPlugin = 1

	" global settings
	if !exists("g:TimeKeeperAwayTimeSec")
		let g:TimeKeeperAwayTimeSec = 360    				" 5ive minutes and then assume that the time was not working time.
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

	if !exists("g:TimeKeeperUseLocal")
		if (has('clientserver'))
			let g:TimeKeeperUseLocal = 0					" Use the file local to where the browser was started or use the user default
		else
			let g:TimeKeeperUseLocal = 1					" Default to local, as without clientserver there will be race conditions.
		endif
	endif

	if !exists("g:TimeKeeperFileName")					" What file should the TimeKeeper store the timesheet in
		if (g:TimeKeeperUseLocal)
			let g:TimeKeeperFileName = 'timekeeper.tmk'
		else
			let g:TimeKeeperFileName = $HOME . '/' . '.timekeeper.tmk'
		endif
	endif

	if !exists("g:TimeKeeperUseGitNotes")				" If vim is in a git repository add git notes with the time periodically
		let g:TimeKeeperUseGitNotes = 0
	endif

	if !exists("g:TimeKeeperGitNoteUpdateTimeSec")
		let g:TimeKeeperGitNoteUpdateTimeSec = 60 * 60		" Update the git note once an hour - This will only be updated when the timesheet is updates.
	endif

	" Set the flag start on Load
	if !exists("g:TimeKeeperStartOnLoad")
		let g:TimeKeeperStartOnLoad = 0
	endif

	" internal data structures for holding the projects
	let s:current_job = g:TimeKeeperDefaultJob
	let s:project_list = {}

	" script level functions to start time capture
	let s:list_time_called = 0
	let s:user_stopped_typing = localtime()
	let s:user_started_typing = localtime()
	let s:last_update_time = localtime()
	let s:last_note_update_time = 0							" use zero to forced the update on start
	let s:current_job = g:TimeKeeperDefaultJob
	let s:current_project = g:TimeKeeperDefaultProject
	let s:current_server = ''
	let s:file_update_time = localtime()
	let s:start_editor_time = localtime()
	let s:start_tracking_time = 0

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
	call TimeKeeper_UpdateJob(s:current_project,s:current_job,(s:user_stopped_typing - s:user_started_typing))
	call TimeKeeper_SaveTimeSheet(0)
	
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
"
function! TimeKeeper_GetCurrentJobString()
	
	return s:current_project . '.' . s:current_job . '#' . s:TimeKeeper_GetTimeString(s:project_list[s:current_project].job[s:current_job].total_time)

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
	
	return s:current_project . '.' . s:current_job . '#' . s:TimeKeeper_GetTimeString(localtime() - s:start_editor_time)

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
	
	return s:current_project . '#' . s:TimeKeeper_GetTimeString(s:project_list[s:current_project].total_time)

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
	
	return s:current_project . '.' . s:current_job . '#' . strftime("%Y/%m/%d-%H:%M",s:project_list[s:current_project].job[s:current_job].start_time)

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
	
	return s:current_project . '.' . s:current_job . '#' . s:TimeKeeper_GetTimeString(s:project_list[s:current_project].job[s:current_job].total_time - s:start_tracking_time)

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
			call s:TimeKeeper_ReportError("timesheet file is not writable")
		else
			" check to make sure the timesheet has not been updated elsewhere (i.e. the githooks)
			if s:file_update_time < getftime(g:TimeKeeperFileName)
				call s:TimeKeeper_LoadTimeSheet()
			endif

			" Ok, lets build the output List of lists that need to be written to the file.
			let output = []

			for project_name in keys(s:project_list)
				for job_name in keys(s:project_list[project_name].job)
					let line = project_name . ',' . job_name . ',' . 
						\ s:project_list[project_name].job[job_name].start_time . ',' .
						\ s:project_list[project_name].job[job_name].total_time . ',' .
						\ s:project_list[project_name].job[job_name].last_commit_time
					call add(output,line)
				endfor
			endfor
			
			" write the result to a file
			call writefile(output,g:TimeKeeperFileName)

			let s:file_update_time = localtime()
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
" INTERNAL FUNCTIONS
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
	
	if (el_time_mins < 10)
		return el_time_days . ':' . el_time_hours . ':0' . el_time_mins
	else
		return el_time_days . ':' . el_time_hours . ':' . el_time_mins

endfunction
"																			}}}
" FUNCTION: TimeKeeper_UpdateJob(project_name,job_name,time)				{{{
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
"
" returns:
"	nothing
"
function! TimeKeeper_UpdateJob(project_name, job_name, time)
	" track the time
	let job = s:TimeKeeper_AddJob(a:project_name,a:job_name)
	
	let job.total_time += a:time
	let s:project_list[a:project_name].total_time += a:time

	" if we are master do the update
	if s:current_server == ''
		" check to see if we need to update the timesheet file
		if (s:last_update_time + g:TimeKeeperUpdateFileTimeSec) < localtime()
			" Ok. we have to update the file now.
			call TimeKeeper_SaveTimeSheet(0)
		endif
	else
		" Ok, we are not the server, we need to update the server
		let job_string = "TimeKeeper_UpdateJob('" . a:project_name . "','" . a:job_name . "'," . a:time . ")"
		
		try 
			call remote_expr(s:current_server,job_string)
		catch /E449/
			" find the server
			call TimeKeeper_FindServer()

			if s:current_server == ''
				" check to see if we need to update the timesheet file - as we are now master
				if (s:last_update_time + g:TimeKeeperUpdateFileTimeSec) < localtime()
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

		let s:project_list[a:project_name].job[a:job_name] = {'total_time':0, 'start_time': localtime(), 'last_commit_time': 0 }
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
"	timesheet	The file to open as a timesheet
" returns:
"	nothing
"
function! s:TimeKeeper_ImportJob(values)
	if len(a:values) == 5
		" set the job values
		let job = s:TimeKeeper_AddJob(a:values[0],a:values[1])
		let job.start_time		 = a:values[2]
		let job.total_time		 = a:values[3]
		let job.last_commit_time = a:values[4]

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
	
	" get the name of the directory will use as the project name
	let s:current_project = substitute(fnamemodify(root,':p:h:h'),fnamemodify(root,':p:h:h:h') . '/','','')
	
    let branch = system("git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* //'")

	if branch != ''
        let s:current_job = substitute(branch, '\n', '', 'g')
	else
	    let s:current_job = ''
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
			
			if !empty(timesheet_data)
				let result = 1

				for item in timesheet_data
					let values = split(item,',',1)

					"Should now have a list of the items in the line
					call s:TimeKeeper_ImportJob(values)
				endfor

				let s:user_last_update_time = localtime()
			endif
		endif

		let s:file_update_time = localtime()
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
		call TimeKeeper_UpdateJob(s:current_project,s:current_job,(localtime() - s:user_started_typing))
	else
		"Yes, just add the stop to start time
		call TimeKeeper_UpdateJob(s:current_project,s:current_job,(s:user_stopped_typing - s:user_started_typing))
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
" FUNCTION: s:TimeKeeper_UserStoppedTyping()									{{{
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
	if g:TimeKeeperUseLocal && s:current_dir != getcwd()
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

endif
