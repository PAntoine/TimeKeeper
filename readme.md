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

The plugin will find other instances of vim with the plugin loaded, and the first one to load
will become the master server. All other instances will send there updates to the server. If the
current server disappears then the first to notice will become the new server. This will reduce
the chance of two instances losing time updates from other servers.

Installation
------------

Simply copy the contents of the plugin directory to the plugin directory in your git installation.

You can leave the configuration variables alone as these have sensible defaults and if you
put the following line in your .vimrc the timekeeper will start when you start typing:

  call TimeKeeper_StartTracking()

And the should be it. Once you have done that once then you can set g:TimeKeeperStartOnLoad to
1 and then TimeKeeper will start every time vim loads.

TODO
----

1.	Write the ruby plugin for Redmine to handle the other end of this.
2.	Multi-editor. If more than one editor is tracking time to the same timesheet it will mess-up
    the time being stored. It does not sink or lock the timesheet file.

Licence and Copyright
---------------------
                      Copyright (c) 2012 Peter Antoine
                             All rights Reserved.
                     Released Under the Artistic Licence
