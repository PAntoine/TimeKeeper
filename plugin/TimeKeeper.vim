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

	if !exists("g:TimeKeeperUpdateFileTime")
		let g:TimeKeeperUpdateFileTime = 60 * 2			" time before the timesheet is written to the file
	endif

	if !exists("g:TimeKeeperUseLocal")
		let g:TimeKeeperUseLocal = 0					" Use the file local to where the browser was started or use the user default
	endif

	if !exists("g:TimeKeeperFileName")					" What file should the TimeKeeper store the timesheet in
		if (g:TimeKeeperUseLocal)
			let g:TimeKeeperFileName = 'timekeeper.tmk'
		else
			let g:TimeKeeperFileName = $HOME . '/' . '.timekeeper.tmk'
		endif
	endif

	" internal data structures for holding the projects
	let s:current_job = g:TimeKeeperDefaultJob
	let s:project_list = {}

	" script level functions to start time capture
	let s:list_time_called = 0
	let s:user_stopped_typing = 0
	let s:user_started_typing = localtime()
	let s:last_update_time = localtime()

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

	au TimeKeeper CursorHoldI * nested call s:TimeKeeper_UserStoppedTyping()
	au TimeKeeper CursorHold  * nested call s:TimeKeeper_UserStoppedTyping()
	au TimeKeeper FocusLost   * nested call s:TimeKeeper_UserStoppedTyping()

	if g:TimeKeeperUseLocal
		au TimeKeeper CmdwinLeave : call TimeKeeper_CheckForCWDChange()
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
"      string = "job:<project>.<job>#hhh:mm"
"
function! TimeKeeper_GetCurrentJobString()
	
	let el_time_min = s:project_list[s:current_project].job[s:current_job].total_time / 60

	" in days?
	if el_time_min > 1440
		let time_str = '' . (el_time_min / 1440) . "days"
	
	" in hours
	elseif el_time_min > 60
		let time_str = '' . (el_time_min / 60) . ':' . (el_time_min % 60) . "hrs"
	
	else
		let time_str = '' . el_time_min . 'mins'
	endif
	
	return "job:" . s:current_project . '.' . s:current_job . '#' . time_str

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

	if !a:create && !filewritable(g:TimeKeeperFileName)
		echomsg "timesheet file is not writable"
	else
		echomsg "in the write"
		let output = []

		" Ok, lets build the output List of lists that need to be written to the file.
		for project_name in keys(s:project_list)
			echomsg "project " . project_name

			for job_name in keys(s:project_list[project_name].job)
				let line = project_name . ',' . job_name . ',' . 
					\ s:project_list[project_name].job[job_name].start_time . ',' . s:project_list[project_name].job[job_name].total_time
				call add(output,line)
			endfor
		endfor
		
		" write the result to a file
		call writefile(output,g:TimeKeeperFileName)

		let s:last_update_time = localtime()
	endif
endfunction
"																			}}}
" INTERNAL FUNCTIONS
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
	let job = s:TimeKeeper_AddJob(a:project_name,a:job_name)
	
	let job.total_time += a:time
	let s:project_list[a:project_name].total_time += a:time

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
		call s:TimeKeeper_AddJob(s:current_project,s:current_job)
		call TimeKeeper_SaveTimeSheet(1)
	endif

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

	if len(a:values) == 4
		" set the job values
		let job = s:TimeKeeper_AddJob(a:values[0],a:values[1])
		let job.start_time = a:values[2]
		let job.total_time = a:values[3]

		"set the project totals
		let s:project_list[a:values[0]].total_time	+= a:values[3]
		let s:project_list[a:values[0]].num_jobs	+= 1
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
function! s:TimeKeeper_LoadTimeSheet()
	let result = 0
	
	" If the file does not exist
	if empty(glob(g:TimeKeeperFileName))
		call s:TimeKeeper_RequestCreate()
	else
		
		if !filewritable(g:TimeKeeperFileName)
			echomsg "Timesheet file cannot be written"
		
		elseif !filereadable(g:TimeKeeperFileName)
			echomsg "Timesheet file cannot be read"

		else
			let timesheet_data = readfile(g:TimeKeeperFileName)
			
			if empty(timesheet_data)
				echomsg "timesheet file empty"
			else
				let result = 1

				for item in timesheet_data
					let values = split(item,',',1)

					"Should now have a list of the items in the line
					call s:TimeKeeper_ImportJob(values)
				endfor

				let s:user_last_update_time = localtime()
			endif
		endif
	endif

	return result
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

		let s:project_list[a:project_name].job[a:job_name] = {'total_time':0, 'start_time': localtime() }
	endif

	return s:project_list[a:project_name].job[a:job_name]
endfunction
"																			}}}
" AUTOCMD FUNCTIONS
" FUNCTION: s:TimeKeeper_UserStartedTyping()									{{{
"
" This function will be called when the user has started typing again. This
" function will be called when the user moves the cursor or the editor regains
" keyboard focus.
"
" vars:
"	none
"
function! s:TimeKeeper_UserStartedTyping()
	" Do we need to update the time that the user stopped typing?
	if (localtime() - s:user_stopped_typing) > 10
		" update the job with the last elapsed time.
		call s:TimeKeeper_UpdateJob(s:current_project,s:current_job,(s:user_stopped_typing - s:user_started_typing))

		" check to see if we need to update the timesheet file
		if (s:last_update_time + g:TimeKeeperUpdateFileTime) < s:user_stopped_typing
			" Ok. we have to update the file now.
			call TimeKeeper_SaveTimeSheet(0)
		endif

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
	if (s:last_update_time + g:TimeKeeperUpdateFileTime) < s:user_stopped_typing
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

	echomsg	"after : "

endfunction
"																			}}}
endif
