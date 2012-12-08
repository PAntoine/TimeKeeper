TimeKeeper
==========

Version 1.1.0

A timekeeper plugin for vim to track you using automatically.

Introduction
------------

This is a git plugin that will track the time you spend working on a project.

This plugin will keep track of the time spent in the editor. Will
try and workout how much time is being spent on the current activity,
and it will track this data by project and the specific job within that project.

The times that are collected from the editor are stored in a simple comma separated timesheet.
This should make it easy to use and import into different tools. It will stored
by default in the $(HOME)/timesheet.tmk. This is obviously configurable.

This plugin will also allow for the timesheet data to be added as a
git note. This will allow for the time to be read by software that
can read the contents of these notes.

The git notes are only added to the current branch for the current 
job, hopefully this will reduce the problems that git-notes have with
push/branching and merging.

The plugin will find other instances of vim with the plugin loaded, and the first one to load
will become the master server. All other instances will send there updates to the server. If the
current server disappears then the first to notice will become the new server. This will reduce
the chance of two instances losing time updates from other servers.

If you set up the git hooks that are provided, the timekeeper will also amend you commits to
allow for the timetracking information to be added to the end of your commits. This is in the
format that Redmine time tracking can read.

Updating
--------

IMPORTANT!!!!!

If you are updating from 1.0.0 -> 1.1.0 you will need to edit the .timekeeper.tmk file as this
has added a new column.

You will need to run the following vim command on it:

    :%s/$/,0/

This will add the new column. If you do not do this it will lose the time on other jobs, but will
keep the local time without problem.

Also, the default for g:TimeKeeperUseGitNotes is not 0, as the commit method is easier to integrate
with Redmine.

Installation
------------

Simply copy the contents of the plugin directory to the plugin directory in your git installation.

You can leave the configuration variables alone as these have sensible defaults and if you
put the following line in your .vimrc the timekeeper will start when you start typing:

  call TimeKeeper_StartTracking()

And the should be it. Once you have done that once then you can set g:TimeKeeperStartOnLoad to
1 and then TimeKeeper will start every time vim loads.

Git Hooks
---------

To set up the Git hooks you will need to do the following in the root directory of the git repository.

    ln -s ~/.vim/githooks/prepare-commit-msg .git/hooks/prepare-commit-msg
    ln -s ~/.vim/githooks/post-commit .git/hooks/post-commit

On Windows (not tested) you will need to copy them into hooks directory.

The above assumes you have these plugins installed locally, else you will need to amend the source of
the plugin, also it assumes that you don't already have these hooks, if you do then you will need
to integrate these with your current hooks. I assume just adding:

   .sh ~/.vim/githooks/prepare-commit-msg $1 $2 $3 

to the end of your current prepare-commit-msg (and do similar for post) will do the job you need.

Licence and Copyright
---------------------
                      Copyright (c) 2012 Peter Antoine
                             All rights Reserved.
                     Released Under the Artistic Licence
