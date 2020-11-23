#!/bin/sh

showUsage() {
	if [ "$1" ]; then
		echo 'error!'
		echo "$1"
		echo
	fi
	echo '--------------------------------------'
	echo '|    FIREBIRD ODS 11/12 CONVERTER    |'
	echo '|             by JL (@2020)          |'
	echo '--------------------------------------'
	echo
	echo 'The syntax for converting the database from ODS11 to ODS12 is as follows:'
	echo
	echo 'sudo ./ODS11to12.sh dbfile_ODS11.fdb dbfile_ODS12.fdb'
	echo
	echo 'where:'
	echo
	echo 'dbfile_ODS11.fdb - is the name of the database file to be converted, compatible with ODS11 format'
	echo
	echo 'dbfile_ODS12.fdb - is the name of the new file, where the database will be saved in ODS12 format'
	echo
	echo 'administrator rights are required for the Firebird low level operations'
	}

removeOldLogs() {
	if ls *.log 1> /dev/null 2>&1; then
		echo "I removed old logs..."  
		rm *.log
	fi
	}

convertODS() {
	LD_LIBRARY_PATH25="fb25"
	TEMP_PATH="temp"
	LD_LIBRARY_PATH30="fb30"

    echo 
	echo I start converting the database structure...
	echo
	echo "$1 (ODS11) => $2 (ODS12)"
	echo
	echo -n "Please wait, depending on the size of the input database, in some cases, this may take several minutes..."
	
	
	mkdir -p "$TEMP_PATH"
	fb25gbak='LD_LIBRARY_PATH="'"$LD_LIBRARY_PATH25"'" FIREBIRD="'"$LD_LIBRARY_PATH25"'" FIREBIRD_TMP="'"$TEMP_PATH"'" FIREBIRD_LOCK="'"$TEMP_PATH"'" fb25/gbak -z -b -g -v -t -st t -y backup_25.log '$1' stdout'
	fb30gbak='LD_LIBRARY_PATH="'"$LD_LIBRARY_PATH30"'" FIREBIRD="'"$LD_LIBRARY_PATH30"'" FIREBIRD_TMP="'"$TEMP_PATH"'" FIREBIRD_LOCK="'"$TEMP_PATH"'" fb30/gbak -rep -v -y restore_30.log stdin '$2

	eval "$fb25gbak | $fb30gbak"
	if [ $? = 0 ]; then
		echo 
		echo "Successful conversion of the Firebird database structure!"
		echo "New database file is: $2"
	else
		echo '[ERROR]'
		echo "Something went wrong during the database conversion! See to logs: backup_25.log and/or restore_30.log"
	fi
	}

	if [ "$1" ]; then
		if [ -f "$1" ]; then
			if [ "$2" ]; then
				if [ "$1" != "$2" ]; then
					if [ ! -f "$2" ]; then
						#ISC_USER=SYSDBA
						removeOldLogs
						convertODS "$1" "$2"
					else
						showUsage "File "$2" exists on the disk, give the name of a non-existent file"
					fi
				else
					showUsage "Both parameters indicate the same file!"
				fi
			else
				showUsage "The file name of the RESULTING database file is not provided"
			fi
		else
			showUsage "File "$1" has not been found!"
		fi
	else
		showUsage
	fi

