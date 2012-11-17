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
"           by default in the $(HOME)/timesheet.tst.
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

	if !exists("g:TimeKeeperAwayTime")
		let s:TimeKeeperAwayTime = 360    	" 5ive minutes and then assume that the time was not working time.
	endif

	if !exists("g:TimeKeeper_default_project")
		let g:TimeKeeper_default_project = 'default'
	endif

	if !exists("g:TimeKeeper_default_job")
		let g:TimeKeeper_default_job = 'default'
	endif

	let s:current_project = g:TimeKeeper_default_project
	let s:current_job = g:TimeKeeper_default_job

	let s:TimeKeeper_project_list = {}

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
" INTERNAL FUNCTIONS
" FUNCTION: s:TimeKeeper_LoadTimeSheet(database_file)  						{{{
"
" This function will load the timesheet that is given. If the database file given
" does not exist it will return an error.
" 
"
" vars:
"	project_name	The project that the job should be created in.
" 	job_name		This is the job to create.
"
" returns:
"	1 - If the database could be loaded.
"	0 - If the database failed to load.
"
function! s:TimeKeeper_LoadTimeSheet(timesheet)

	return 1
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
	if !has_key(s:TimeKeeper_project_list,a:project_name)
		let s:TimeKeeper_project_list[a:project_name] = {'total_time':0, 'num_jobs': 1, 'job': {} }
	endif

	" check to see if it is a new job that we are dealing with
	if !has_key(s:TimeKeeper_project_list[a:project_name].job,a:job_name)

		let s:TimeKeeper_project_list[a:project_name].job[a:job_name] = {'total_time':0, 'job_start': localtime(), 'time_last_session': 0}
		echomsg "new"

	else
		" Ok, we have an existing project and job, now update the two values
		echomsg "exists" . localtime() . " the time in job start " . s:TimeKeeper_project_list[a:project_name].job['default'].job_start
	endif
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
	if (localtime() - s:user_stopped_typing) > s:TimeKeeperAwayTime
		" add the time to the current job
		let s:TimeKeeper_project_list[s:current_project].job[s:current_job].total_time += (s:user_stopped_typing - s:user_started_typing)

		echomsg "running total" . s:TimeKeeper_project_list[s:current_project].job[s:current_job].total_time

		" update the started typing time
		let s:user_started_typing = localtime()
	else
		echomsg "current running time: " . s:TimeKeeper_project_list[s:current_project].job[s:current_job].total_time . "not added: " . (s:user_stopped_typing - s:user_started_typing)
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
