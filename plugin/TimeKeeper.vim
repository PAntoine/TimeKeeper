" vim: ts=4 tw=4 fdm=marker :
" ---------------------------------------------------------------------------------
"     file: TimeKeeper
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
if g:developing || !exists("s:TimeKeeperPlugin")
" Script Initialisation block												{{{
	let s:TimeKeeperPlugin = 1

	" global settings
	if !exists("g:TimeKeeperAwayTime")
		let s:TimeKeeperAwayTime = 360    				" 5ive minutes and then assume that the time was not working time.
	endif

	if !exists("g:TimeKeeperDefaultProject")
		let g:TimeKeeperDefaultProject = 'default'		" the name of the default/current project
	endif

	if !exists("g:TimeKeeperDefaultJob")
		let g:TimeKeeperDefaultJob = 'default'			" the name of the default/current job
	endif

	if !exists("g:TimeKeeperUseGitProjectBranch")
		let g:TimeKeeperUseGitProjectBranch = true		" use the Git repository as the project name, and the branch as the job
	endif

	" internal data structures for holding the projects
	let s:current_project = g:TimeKeeperDefaultProject
	let s:current_job = g:TimeKeeperDefaultJob
	let s:project_list = {}

	" script level functions to start time capture
	let s:list_time_called = 0
	let s:user_stopped_typing = 0
	let s:user_started_typing = localtime()

	augroup TimeKeepr						" Create the group to hold all the events.

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

	"TODO: This needs to load/create the timesheet here

	call s:TimeKeeper_AddJob(s:current_project,s:current_job)

	au TimeKeeper CursorHoldI * nested call s:TimeKeeper_UserStoppedTyping()
	au TimeKeeper CursorHold  * nested call s:TimeKeeper_UserStoppedTyping()
	au TimeKeeper FocusLost   * nested call s:TimeKeeper_UserStoppedTyping()
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
"      string = "job:<project>.<job>#hhh:mm"
"
function! TimeKeeper_GetCurrentJobString()
	
	let el_time_min = s:project_list[s:current_project].job[s:current_job].total_time

	" in days?
	if el_time_min > 1440
		let time_str = '' . (el_time_min / 1440) . "days"
	
	" in hours
	elseif el_time_min > 60
		let time_str = '' . (el_time_min / 60) . ':' (el_time_min % 60) . "hrs"
	
	else
		let time_str = '' . el_time_min . 'mins'
	endif
	
	return "job:" . g:TimeKeeperDefaultProject . '.' . g:TimeKeeperDefaultJob . '#' . time_str

endfunction
"																			}}}
" INTERNAL FUNCTIONS
" FUNCTION: s:TimeKeeper_LoadTimeSheet(timesheet_file)  					{{{
"
" This function will load the timesheet that is given. If the timesheet file given
" does not exist it will return an error.
"
" The format of the time sheet is a basic comma separated file that has the following
" format:
" 
"      project, job, start_time, total_time, time_last_session 
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
function! s:TimeKeeper_LoadTimeSheet(timesheet)
	let result = 0

	if filewritable(a:timesheet)
		let timesheet_data = readfile(a:timesheet)
		
		if timesheet_data == []
			echomsg "timesheet file empty"
		else
			let result = 1
			let index = 0
			while index < len(timesheet_data)
				let line_str = timesheet_data[index]
				let values = split(line_str,',',1)
			endwhile
		endif
	endif

	return result
endfunction
"																			}}}
" FUNCTION: TimeKeeper_AddJob(project_name,job_name)  						{{{
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

		let s:project_list[a:project_name].job[a:job_name] = {'total_time':0, 'job_start': localtime(), 'time_last_session': 0}
		echomsg "new exists" . localtime() . " the time in job start " . s:project_list[a:project_name].job['default'].total_time

	else
		" Ok, we have an existing project and job, now update the two values
		echomsg "exists" . localtime() . " the time in job start " . s:project_list[a:project_name].job['default'].job_start
		echomsg "exists" . localtime() . " the time in job start " . s:project_list[a:project_name].job['default'].total_time
	endif
endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_FindTimeSheet()			 						{{{
"
" This function will find and load the timesheet that is given. If the timesheet
" can not be found then the function will return 0.
" 
" If g:TimeKeeperUseLocal is true then it will look for the file in the current
" directory. This will allow for local timesheets that can be added to the 
" current repository. Or, but default it will use the file in the $HOME directory.
"
" The filename used is defined in the g:TimeKeeperFileName.
"
" vars:
"	none.
"
" returns:
"	1 - If the database could be loaded.
"	0 - If the database failed to load.
"
function! s:TimeKeeper_FindTimeSheet()
	let loaded = false

	if (g:TimeKeeperUseLocal)
		let loaded = s:TimeKeeperLoadFile(g:TimeKeeperFileName)
	else
		let loaded = s:TimeKeeperLoadFile(g:TimeKeeperFileName)
	endif
		
	if (!loaded)
		let loaded = s:TimeKeeperRequestCreate(g:TimeKeeperFileName)
	endif

	return loaded
endfunction
"																			}}}
" AUTOCMD FUNCTIONS
" FUNCTION: TimeKeeper_UserStartedTyping()									{{{
"
" This function will be called when the user has started typing again. This
" function will be called when the user moves the cursor or the editor regains
" keyboard focus.
"
" vars:
"	none
"
function! s:TimeKeeper_UserStartedTyping()
	" Is this the first time since the user stopped typing?
	" Assume if old_time - current time is greater than one updatetime period that the user has typed something 
	" since then, so reset the count down clock till then.
	if (localtime() - s:user_stopped_typing) > 10
		" add the time to the current job
		let s:project_list[s:current_project].job[s:current_job].total_time += (s:user_stopped_typing - s:user_started_typing)

		echomsg "running total" . s:project_list[s:current_project].job[s:current_job].total_time . "dur " . (s:user_stopped_typing - s:user_started_typing)

		" update the started typing time
		let s:user_started_typing = localtime()
		let s:user_stopped_typing = localtime()
	else
		echomsg "current running time: " . s:project_list[s:current_project].job[s:current_job].total_time . " not added: " . (s:user_stopped_typing - s:user_started_typing)
	endif

	" remove the events as these slow down the editor
	au! TimeKeeper CursorMovedI
	au! TimeKeeper CursorMoved
	au! TimeKeeper FocusGained
endfunction
"																			}}}
" FUNCTION: TimeKeeper_UserStoppedTyping()									{{{
"
" This function will be called when the user has stopped typing for the time
" that is specified in the updatetime system variable.
"
" vars:
"	none
"
function! s:TimeKeeper_UserStoppedTyping()
	let s:user_stopped_typing = localtime()

	" we need to wait for the Cursor to move as this is the user doing work again.
	au TimeKeeper CursorMovedI * nested call s:TimeKeeper_UserStartedTyping()
	au TimeKeeper CursorMoved  * nested call s:TimeKeeper_UserStartedTyping()
	au TimeKeeper FocusGained  * nested call s:TimeKeeper_UserStartedTyping()
	  
endfunction
"																			}}}
"																			}}}
endif
