TimeKeeper
==========

Version 1.0.0

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

Configuration
-------------

          config variable                  description
          ---------------                  ---------------------------------------
          g:TimeKeeperAwayTimeSec	       If the user does not type for this 
                                           amount of time it is assumed that they
                                           were away from the keyboard and the 
                                           time is not registered. [360]

          g:TimeKeeperDefaultProject       The default project to add time to ['default']

          g:TimeKeeperDefaultJob           The default job to add time to ['default']

          g:TimeKeeperUseGitProjectBranch  If vim is in a git repository use the 
                                           directory name as the project name and the
                                           branch name as the job name. [1]

          g:TimeKeeperUpdateFileTimeSec    The frequency that the timesheet file
                                           will be updated. [60 * 15 - 15 mins]

          g:TimeKeeperUseLocal             If this flag is set then the timekeeper
                                           will create a file at the cwd of the
                                           editor. [0]

          g:TimeKeeperFileName             The filename that the timesheet will be
                                           saved to. [(.)timekeeper.tmk] 

          g:TimeKeeperUseGitNotes          If this flag is set then timekeeper will
                                           create a git note in the current branch
                                           if the editor is in a git repository. It
                                           will create a note with the ref of you
                                           guessed it "timekeeper". It will try and
                                           keep the entries separate as it will use
                                           the user.email as the key for the entries.

          g:TimeKeeperGitNoteUpdateTimeSec The time that the git notes will be updated
                                           this is not that important as it re-writes
                                           the note, but will cause you git history
                                           to get quite large if you update the notes
                                           too requently.

Installation
------------

Simply copy the contents of the plugin directory to the plugin directory in your git installation.

You can leave the configuration variables alone as these have sensible defaults and if you
put the following line in your .vimrc the timekeeper will start when you start typing:

  call TimeKeeper_StartTracking()

And the should be it.

TODO
----

Nothing, well except write the ruby plugin for Redmine to handle the other end of this.

Licence and Copyright
---------------------
                      Copyright (c) 2012 Peter Antoine
                             All rights Reserved.
                     Released Under the Artistic Licence
