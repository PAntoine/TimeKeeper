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
		let g:TimeKeeperUseGitProjectBranch = 1			" use the Git repository as the project name, and the branch as the job
	endif

	" internal data structures for holding the projects
	let s:current_project = g:TimeKeeperDefaultProject
	let s:current_job = g:TimeKeeperDefaultJob
	let s:project_list = {}

	" script level functions to start time capture
	let s:list_time_called = 0
	let s:user_stopped_typing = 0
	let s:user_started_typing = localtime()

	augroup TimeKeeper						" Create the group to hold all the events.

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
function! TimeKeeper_SaveTimeSheet(timesheet)
	let result = 0

	if g:developing || filewritable(a:timesheet)
		echomsg "in the write"
		let output = []

		" Ok, lets build the output List of lists that need to be written to the file.
		for project_name in keys(s:project_list)
			echomsg "project " . project_name

			for job_name in keys(s:project_list[project_name].job)
				let line = project_name . ',' . job_name . ',' . 
					\ s:project_list[project_name].job[job_name].start_time . ',' . s:project_list[project_name].job[job_name].total_time
				add(output,line)
			endfor
		endfor
		
		" write the result to a file
		writefile(outout,timesheet)
	endif
endfunction
"																			}}}
" INTERNAL FUNCTIONS
" FUNCTION: s:TimeKeeper_UpdateJob(project_name,job_name,time)				{{{
"
" This function will update a job with the time that has elapsed.
" 
" vars:
"	project_name	The name of the project.
"	job_name		The name of the job.
"	time			The name of the time.
"
" returns:
"	nothing
"
function! s:TimeKeeper_UpdateJob(project_name, job_name, time)
	let job = TimeKeeper_AddJob(project_name,job_name)
	
	let job.total_time += time
	let s:project_list[project_name].total_time += time

endfunction
" FUNCTION: s:TimeKeeper_ImportTimesheet(values)  					{{{
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
function! s:TimeKeeper_ImportTimeSheet(values)
	if len(values) == 4
		" set the job values
		let job = TimeKeeper_AddJob(values[0],values[1]);
		let job.start_time = values[2]
		let job.total_time = values[3]

		"set the project totals
		let s:project_list[values[0]].total_time += values[3]
		let s:project_list[values[1]].num_jobs	 += 1
	endif
endfunction
"																			}}}
" FUNCTION: s:TimeKeeper_LoadTimeSheet(timesheet_file)  					{{{
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

				"Should now have a list of the items in the line
				call TimeKeeper_ImportJob(values)
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

		let s:project_list[a:project_name].job[a:job_name] = {'total_time':0, 'start_time': localtime() }
		echomsg "new exists" . localtime() . " the time in job start " . s:project_list[a:project_name].job['default'].total_time

	else
		" Ok, we have an existing project and job, now update the two values
		echomsg "exists" . localtime() . " the time in job start " . s:project_list[a:project_name].job['default'].start_time
		echomsg "exists" . localtime() . " the time in job start " . s:project_list[a:project_name].job['default'].total_time
	endif

	return s:project_list[a:project_name].job[a:job_name]
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
