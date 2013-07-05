#!/bin/bash
#---------------------------------------------------------------------------------
#
#  ,--------.,--.                 ,--. ,--.                                   
#  '--.  .--'`--',--,--,--. ,---. |  .'   / ,---.  ,---.  ,---.  ,---. ,--.--.
#     |  |   ,--.|        || .-. :|  .   ' | .-. :| .-. :| .-. || .-. :|  .--'
#     |  |   |  ||  |  |  |\   --.|  |\   \\   --.\   --.| '-' '\   --.|  |   
#     `--'   `--'`--`--`--' `----'`--' '--' `----' `----'|  |-'  `----'`--'   
#
#  @file        convert_to_dir
#  @group       convert_to_dir
#  @description 
#   This file holds a conversion script that will convert a flatfile to a set
#   of files in the newer directory format.
#
#  @ignore
#
#  author Peter Antoine
#    date 05/07/2013
#---------------------------------------------------------------------------------
#                     Copyright (c) 2013 Peter Antoine
#                           All rights Reserved.
#                      Released Under the MIT Licence
#---------------------------------------------------------------------------------
if [ "$TIMEKEEPER_TIMESHEET" == "" ];
then
	# check for local file first
	if [[ -w ".timekeeper.tmk" && -r ".timekeeper.tmk" ]];
	then
		TIMEKEEPER_TIMESHEET=".timekeeper.tmk"
	else
		# if local not found the search for global 
		if [[ -w "$HOME/.timekeeper.tmk" && -r "$HOME/.timekeeper.tmk" ]];
		then
			TIMEKEEPER_TIMESHEET="$HOME/.timekeeper.tmk"
		fi
	fi
fi

# default to global
if [ "$TIMEKEEPER_TIMESHEET" == "" ];
then
	TIMEKEEPER_TIMESHEET="$HOME/.timekeeper.tmk"
fi

TIMEKEEPER_DIRECTORY="test_this"

if [[ -d $TIMEKEEPER_DIRECTORY ]];
then
	echo "Directory $TIMEKEEPER_DIRECTORY exists. Exiting script."

# if it's readable - carry on
elif [[  -r "$TIMEKEEPER_TIMESHEET" ]];
then
	mkdir -p $TIMEKEEPER_DIRECTORY

	if [[ $? -ne 0 ]]
	then
		echo "Failed to create $TIMEKEEPER_DIRECTORY. exiting the script."
		exit 1
	fi

	index=0

	# read the file
	while IFS=, read -r project job start time last_commit status note;
	do
		string=$project,$job,$start,$time,$last_commit,$status,$note

		# find a section
		if [ "${project:0:1}" == "[" ] && [ "${project:0-1}" == "]" ]
		then
			if [ "$current_filename" != "" ]
			then
				# write the new file
				index=0
				for i in "${timekeeper_file[@]}"
				do
					if [ $index == 0 ];
					then
						echo "$i" > "$current_filename"
					else
						echo "$i" >> "$current_filename"
					fi

					index=1
				done

				timekeeper_file=""
				index=0
			fi

			line=${project:1:${#project}-2}

			current_filename="$TIMEKEEPER_DIRECTORY/${line%:*}:${line#*:}.tmk"
		else
			timekeeper_file[$index]="$string"
			index=$(($index+1))
		fi
	done < "$TIMEKEEPER_TIMESHEET"

	if [ "$current_filename" != "" ]
	then
		# write the new file
		index=0
		for i in "${timekeeper_file[@]}"
		do
			if [ $index == 0 ];
			then
				echo "$i" > "$current_filename"
			else
				echo "$i" >> "$current_filename"
			fi

			index=1
		done
	fi

	echo ""
	echo ""
	echo "Please check that the number of sections matches the number of files"
	echo "If this is correct then it would be a good idea to delete the $TIMEKEEPER_TIMESHEET file."
	echo ""
	echo "Directory listing:"
	echo ""
	ls -l $TIMEKEEPER_DIRECTORY

else
	echo "Cannot read the TimeKeeper file. Exiting."
fi
