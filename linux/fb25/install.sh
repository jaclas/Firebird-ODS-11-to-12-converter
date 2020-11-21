#!/bin/sh

# posixLibrary.sh
#!/bin/sh
#
#  The contents of this file are subject to the Initial
#  Developer's Public License Version 1.0 (the "License");
#  you may not use this file except in compliance with the
#  License. You may obtain a copy of the License at
#  http://www.ibphoenix.com/main.nfs?a=ibphoenix&page=ibp_idpl.
#
#  Software distributed under the License is distributed AS IS,
#  WITHOUT WARRANTY OF ANY KIND, either express or implied.
#  See the License for the specific language governing rights
#  and limitations under the License.
#
#  The Original Code was created by Mark O'Donohue
#  for the Firebird Open Source RDBMS project.
#
#  Copyright (c) Mark O'Donohue <mark.odonohue@ludwig.edu.au>
#  and all contributors signed below.
#
#  All Rights Reserved.
#  Contributor(s): ______________________________________.
#		Alex Peshkoff
#


#------------------------------------------------------------------------
# Adds parameter to $PATH if it's missing in it

Add2Path() {
	Dir=${1}
	x=`echo :${PATH}: | grep :$Dir:`
	if [ -z "$x" ]
	then
		PATH=$PATH:$Dir
		export PATH
	fi
}

#------------------------------------------------------------------------
# Global stuff init

Answer=""
OrigPasswd=""
TmpFile=""
SecurityDatabase=security2.fdb
UninstallScript=FirebirdUninstall.sh
ArchiveDateTag=`date +"%Y%m%d_%H%M"`
export ArchiveDateTag
ArchiveMainFile="/opt/firebird_${ArchiveDateTag}"
export ArchiveMainFile
#this solves a problem with sudo env missing sbin
Add2Path /usr/sbin
Add2Path /sbin

#------------------------------------------------------------------------
# Create temporary file. In case mktemp failed, do something...

MakeTemp() {
	TmpFile=`mktemp $mktOptions /tmp/firebird_install.XXXXXX`
	if [ $? -ne 0 ]
	then
		TmpFile=/tmp/firebird_install
		touch $TmpFile
	fi
}

#------------------------------------------------------------------------
# Prompt for response, store result in Answer

AskQuestion() {
    Test=$1
    DefaultAns=$2
    echo -n "${1}"
    Answer="$DefaultAns"
    read Answer

    if [ -z "$Answer" ]
    then
        Answer="$DefaultAns"
    fi
}


#------------------------------------------------------------------------
# Prompt for yes or no answer - returns non-zero for no

AskYNQuestion() {
    while echo -n "${*} (y/n): "
    do
        read answer rest
        case $answer in
        [yY]*)
            return 0
            ;;
        [nN]*)
            return 1
            ;;
        *)
            echo "Please answer y or n"
            ;;
        esac
    done
}


#------------------------------------------------------------------------
# Run $1. If exit status is not zero, show output to user.

runSilent() {
	MakeTemp
	$1 >$TmpFile 2>&1
	if [ $? -ne 0 ]
	then
		cat $TmpFile
		echo ""
		rm -f $TmpFile
		return 1
	fi
	rm -f $TmpFile
	return 0
}


#------------------------------------------------------------------------
# Check for a user, running install, to be root

checkRootUser() {

    if [ "`whoami`" != "root" ];
      then
        echo ""
        echo "--- Stop ----------------------------------------------"
        echo ""
        echo "    You need to be 'root' user to do this change"
        echo ""
        exit 1
    fi
}

#alias
checkInstallUser() {
	checkRootUser
}


#------------------------------------------------------------------------
#  resetInetdServer
#  Works for both inetd and xinetd

resetInetdServer() {
	pid=`ps $psOptions | grep inetd | grep -v grep | awk '{print $2}'`
    if [ "$pid" ]
    then
        kill -HUP $pid
    fi
}


#------------------------------------------------------------------------
# remove the xinetd config file(s)
# take into account possible pre-firebird xinetd services

removeXinetdEntry() {
	for i in `grep -l "service gds_db" /etc/xinetd.d/*`
	do
        rm -f $i
    done
}


#------------------------------------------------------------------------
# remove the line from inetd file

removeInetdEntry() {
    FileName=/etc/inetd.conf
    oldLine=`grep "^gds_db" $FileName`
    removeLineFromFile "$FileName" "$oldLine"
}


#------------------------------------------------------------------------
#  Remove (x)inetd service entry and restart the service.
#  Check to see if we have xinetd installed or plain inetd.  
#  Install differs for each of them.

removeInetdServiceEntry() {
    if [ -d /etc/xinetd.d ] 
    then
        removeXinetdEntry
    elif [ -f /etc/inetd.conf ]
	then
        removeInetdEntry
    fi

    # make [x]inetd reload configuration
	resetInetdServer
}


#------------------------------------------------------------------------
#  check if it is running

checkIfServerRunning() {

	checkString=`ps $psOptions | egrep "\b(fbserver|fbguard|fb_smp_server)\b" |grep -v grep`
    if [ ! -z "$checkString" ]
	then
		serverMode=super
	fi

# have to be root to stop the server
	if [ "$1" != "install-embedded" ]
    then
    	stopSuperServerIfRunning
    fi


# Check is server is being actively used.

    checkString=`ps $psOptions | egrep "\b(fb_smp_server)\b" |grep -v grep`
    if [ ! -z "$checkString" ]
    then
        echo "An instance of the Firebird SuperClassic server seems to be running."
        echo "Please quit all Firebird applications and then proceed."
        exit 1
    fi

    checkString=`ps $psOptions | egrep "\b(fbserver|fbguard)\b" |grep -v grep`
    if [ ! -z "$checkString" ]
    then
        echo "An instance of the Firebird Super server seems to be running."
        echo "Please quit all Firebird applications and then proceed."
        exit 1
    fi

    checkString=`ps $psOptions | egrep "\b(fb_inet_server|fb_smp_server|gds_pipe)\b" |grep -v grep`
    if [ ! -z "$checkString" ]
    then
        echo "An instance of the Firebird Classic server seems to be running."
        echo "Please quit all Firebird applications and then proceed."
        exit 1
    fi


# The following check for running interbase or firebird 1.0 servers.

    checkString=`ps $psOptions | egrep "\b(ibserver|ibguard)\b" |grep -v grep`
    if [ ! -z "$checkString" ] 
    then
        echo "An instance of the Firebird/InterBase Super server seems to be running." 
        echo "(the ibserver or ibguard process was detected running on your system)"
        echo "Please quit all Firebird applications and then proceed."
        exit 1 
    fi

    checkString=`ps $psOptions | egrep "\b(gds_inet_server|gds_pipe)\b" |grep -v grep`
    if [ ! -z "$checkString" ] 
    then
        echo "An instance of the Firebird/InterBase Classic server seems to be running." 
        echo "(the gds_inet_server or gds_pipe process was detected running on your system)"
        echo "Please quit all Firebird applications and then proceed." 
        exit 1 
    fi

# have to be root to modify (x)inetd
	if [ "$1" != "install-embedded" ]
	then
		removeInetdServiceEntry
	fi
}


#------------------------------------------------------------------------
#  ask user to enter CORRECT original DBA password

askForOrigDBAPassword() {
    OrigPasswd=""
    while [ -z "$OrigPasswd" ]
    do
        AskQuestion "Please enter current password for SYSDBA user: "
        OrigPasswd=$Answer
        if ! runSilent "/opt/firebird/bin/gsec -user sysdba -password $OrigPasswd -di"
		then
			OrigPasswd=""
		fi
	done
}


#------------------------------------------------------------------------
#  Modify DBA password to value, asked from user. 
#  $1 may be set to original DBA password
#  !! This routine is interactive !!

askUserForNewDBAPassword() {

	if [ -z $1 ]
	then
		askForOrigDBAPassword
	else
		OrigPasswd=$1
	fi

    NewPasswd=""
    while [ -z "$NewPasswd" ]
    do
        AskQuestion "Please enter new password for SYSDBA user: "
        NewPasswd=$Answer
        if [ ! -z "$NewPasswd" ]
        then
            if ! runSilent "/opt/firebird/bin/gsec -user sysdba -password $OrigPasswd -modify sysdba -pw $NewPasswd"
            then
				NewPasswd=""
			fi
		fi
	done
}


#------------------------------------------------------------------------
# add a line in the (usually) /etc/services or /etc/inetd.conf file
# Here there are three cases, not found         => add
#                             found & different => replace
#                             found & same      => do nothing
#                             

replaceLineInFile() {
    FileName="$1"
    newLine="$2"
    oldLine=`grep "$3" $FileName`

    if [ -z "$oldLine" ] 
      then
        echo "$newLine" >> "$FileName"
    elif [ "$oldLine" != "$newLine"  ]
      then
		MakeTemp
        grep -v "$oldLine" "$FileName" > "$TmpFile"
        echo "$newLine" >> $TmpFile
        cp $TmpFile $FileName && rm -f $TmpFile
        echo "Updated $1"
    fi
}


#------------------------------------------------------------------------
# "edit" file $1 - replace line starting from $2 with $3
# This should stop ed/ex/vim/"what else editor" battle.
# I hope awk is present in any posix system? AP.

editFile() {
    FileName=$1
    Starting=$2
    NewLine=$3
	
	AwkProgram="(/^$Starting.*/ || \$1 == \"$Starting\") {\$0=\"$NewLine\"} {print \$0}"
	MakeTemp
	awk "$AwkProgram" <$FileName >$TmpFile && mv $TmpFile $FileName || rm -f $TmpFile
}


#------------------------------------------------------------------------
# remove line from config file if it exists in it.

removeLineFromFile() {
    FileName=$1
    oldLine=$2

    if [ ! -z "$oldLine" ] 
    then
        cat $FileName | grep -v "$oldLine" > ${FileName}.tmp
        cp ${FileName}.tmp $FileName && rm -f ${FileName}.tmp
    fi
}


#------------------------------------------------------------------------
# Write new password to the /opt/firebird/SYSDBA.password file

writeNewPassword() {
    NewPasswd=$1
	DBAPasswordFile=/opt/firebird/SYSDBA.password

	cat <<EOT >$DBAPasswordFile
# Firebird generated password for user SYSDBA is:

ISC_USER=sysdba
ISC_PASSWD=$NewPasswd

EOT

    if [ $NewPasswd = "masterkey" ]
    then
        echo "# for install on `hostname` at time `date`" >> $DBAPasswordFile
        echo "# You should change this password at the earliest oportunity" >> $DBAPasswordFile
    else 
        echo "# generated on `hostname` at time `date`" >> $DBAPasswordFile
    fi
	
	cat <<EOT >>$DBAPasswordFile

# Your password can be changed to a more suitable one using the
# /opt/firebird/bin/gsec utility.
EOT

    chmod u=r,go= $DBAPasswordFile


    # Only if we have changed the password from the default do we need
    # to update the entry in the database

    if [ $NewPasswd != "masterkey" ]
    then
        runSilent "/opt/firebird/bin/gsec -user sysdba -password masterkey -modify sysdba -pw $NewPasswd"
    fi
}

#------------------------------------------------------------------------
#  Change sysdba password.

changeDBAPassword() {
    if [ -z "$InteractiveInstall" ]
      then
        generateNewDBAPassword
      else
        askUserForNewDBAPassword masterkey
    fi
}


#------------------------------------------------------------------------
#  buildUninstallFile
#  This will work only for the .tar.gz install and it builds an
#  uninstall shell script.  The RPM system, if present, takes care of it's own.

buildUninstallFile() {
    cd "$origDir"

    if [ ! -f manifest.txt ]  # Only exists if we are a .tar.gz install
    then
        return
    fi

	cp manifest.txt /opt/firebird/misc

	cp -r scripts /opt/firebird/misc
	[ -f scripts/tarMainUninstall.sh ] && cp scripts/tarMainUninstall.sh /opt/firebird/bin/$UninstallScript
	[ -f scripts/tarmainUninstall.sh ] && cp scripts/tarmainUninstall.sh /opt/firebird/bin/$UninstallScript
	[ -f /opt/firebird/bin/$UninstallScript ] && chmod u=rx,go= /opt/firebird/bin/$UninstallScript
}


#------------------------------------------------------------------------
# Remove if only a link

removeIfOnlyAlink() {
	Target=$1

    if [ -L $Target ]
    then
        rm -f $Target
    fi
}


#------------------------------------------------------------------------
# re-link new file only if target is a link or missing

safeLink() {
	Source=$1
	Target=$2
	
	removeIfOnlyAlink $Target
    if [ ! -e $Target ]
    then
        ln -s $Source $Target
    fi
}


#------------------------------------------------------------------------
#  createLinksForBackCompatibility
#  Create links for back compatibility to InterBase and Firebird1.0 
#  linked systems.

createLinksForBackCompatibility() {

    # These two links are required for compatibility with existing ib programs
    # If the program had been linked with libgds.so then this link is required
    # to ensure it loads the fb equivalent.  Eventually these should be 
    # optional and in a seperate rpm install.  MOD 7-Nov-2002.

	if [ "$1" ]
	then
		# Use library name from parameter
		newLibrary=/opt/firebird/lib/$1
	else
	    # Use DefaultLibrary, set by appropriate install library
    	newLibrary=/opt/firebird/lib/$DefaultLibrary.so
	fi

	safeLink $newLibrary /usr/lib/libgds.so
	safeLink $newLibrary /usr/lib/libgds.so.0
}


#------------------------------------------------------------------------
#  removeLinksForBackCompatibility
#  Remove links for back compatibility to InterBase and Firebird1.0 
#  linked systems.

removeLinksForBackCompatibility() {
    removeIfOnlyAlink /usr/lib/libgds.so
    removeIfOnlyAlink /usr/lib/libgds.so.0
}


#------------------------------------------------------------------------
# Run process and check status

runAndCheckExit() {
    Cmd=$*

    $Cmd
    ExitCode=$?

    if [ $ExitCode -ne 0 ]
    then
        echo "Install aborted: The command $Cmd "
        echo "                 failed with error code $ExitCode"
        exit $ExitCode
    fi
}


#------------------------------------------------------------------------
#  Display message if this is being run interactively.

displayMessage() {
    msgText=$1

    if [ ! -z "$InteractiveInstall" ]
    then
        echo $msgText
    fi
}


#------------------------------------------------------------------------
#  Archive any existing prior installed files.
#  The 'cd' stuff is to avoid the "leading '/' removed message from tar.
#  for the same reason the DestFile is specified without the leading "/"

archivePriorInstallSystemFiles() {
	if [ -z ${ArchiveMainFile} ]
	then
		echo "Variable ArchiveMainFile not set - exiting"
		exit 1
	fi

	tarArc=${ArchiveMainFile}.$tarExt

    oldPWD=`pwd`
    archiveFileList=""

    cd /

	if [ -f ${oldPWD}/manifest.txt ]; then
		manifest=`cat ${oldPWD}/manifest.txt`
		for i in $manifest; do
			if [ -f $i ]; then
				i=${i#/}	# strip off leading /
				archiveFileList="$archiveFileList $i"
			fi
		done
	fi

    DestFile=/opt/firebird
    if [ -e "$DestFile" ]
    then
        echo ""
        echo ""
        echo ""
        echo "--- Warning ----------------------------------------------"
        echo "    The installation target directory $DestFile already exists."
        echo "    This and other related files found will be"
        echo "    archived in the file : ${tarArc}"
        echo "" 

        if [ ! -z "$InteractiveInstall" ]
        then
            AskQuestion "Press return to continue or ^C to abort"
        fi

        if [ -e $DestFile ]
        then
            archiveFileList="$archiveFileList $DestFile"
        fi
    fi


    for i in ibase.h ib_util.h
    do
        DestFile=usr/include/$i
        if [ -e $DestFile ]; then
			if [ ! "`echo $archiveFileList | grep $DestFile`" ]; then
            	archiveFileList="$archiveFileList $DestFile"
			fi
        fi
    done

    for i in libib_util.so libfbclient.so*
	do
		for DestFile in usr/lib/$i
	    do
        	if [ -e $DestFile ]; then
				if [ ! "`echo $archiveFileList | grep $DestFile`" ]; then
    	        	archiveFileList="$archiveFileList $DestFile"
				fi
        	fi
		done
    done

    for i in usr/sbin/rcfirebird etc/init.d/firebird etc/rc.d/init.d/firebird
    do
        DestFile=./$i
        if [ -e $DestFile ]; then
			if [ ! "`echo $archiveFileList | grep $DestFile`" ]; then
            	archiveFileList="$archiveFileList $DestFile"
			fi
        fi
    done
	
    if [ ! -z "$archiveFileList" ]
    then
        displayMessage "Archiving..."
        runAndCheckExit "tar -cv${tarOptions}f $tarArc $archiveFileList"
        displayMessage "Done."

        displayMessage "Deleting..."
        for i in $archiveFileList
        do
            rm -rf $i
        done
        displayMessage "Done."
    fi

    cd $oldPWD
}


#------------------------------------------------------------------------
# removeInstalledFiles
# 
removeInstalledFiles() {

    manifestFile=/opt/firebird/misc/manifest.txt

    if [ ! -f "$manifestFile" ]
      then
        return
    fi

    origDir=`pwd`
    
    cd /

    for i in `cat $manifestFile`
      do
        if [ -f $i -o -L $i ]
          then
            rm -f $i
            #echo $i
        fi
    done

    cd "$origDir"
}


#------------------------------------------------------------------------
# removeUninstallFiles
# Under the install directory remove all the empty directories 
# If some files remain then 

removeUninstallFiles() {
    # remove the uninstall scripts files.
    rm -rf /opt/firebird/misc/scripts
    rm -f /opt/firebird/misc/manifest.txt
    rm -f /opt/firebird/bin/$UninstallScript
}


#------------------------------------------------------------------------
# removeEmptyDirs
# Under the install directory remove all the empty directories 
# If some files remain then 
# This routine loops, since deleting a directory possibly makes
# the parent empty as well

removeEmptyDirs() {

    dirContentChanged='yes'
    while [ "$dirContentChanged" ]; do
        dirContentChanged=''

		for rootDir in /opt/firebird/bin /opt/firebird/bin /opt/firebird/lib /opt/firebird/include /opt/firebird/doc /opt/firebird/UDF /opt/firebird/examples /opt/firebird/examples/empbuild \
					   /opt/firebird/help /opt/firebird/intl /opt/firebird/misc /opt/firebird /opt/firebird /opt/firebird /opt/firebird /opt/firebird/plugins \
					   /opt/firebird; do

			if [ -d $rootDir ]; then	
		        for i in `find $rootDir -type d -print`; do
		            ls $i/* >/dev/null 2>&1
	    	        if [ $? -ne 0 ]; then
	        	        rmdir $i && dirContentChanged=$i
	    	        fi
		        done
			fi

		done
	done
}


#------------------------------------------------------------------------
#  fixFilePermissions
#  Change the permissions to restrict access to server programs to 
#  firebird group only.  This is MUCH better from a safety point of 
#  view than installing as root user, even if it requires a little 
#  more work.

fixFilePermissions() {
    # Lock files
    cd /opt/firebird
    for FileName in fb_guard
    do
        touch $FileName
        MakeFileFirebirdWritable $FileName
    done

	# Log file
	cd /opt/firebird
    touch firebird.log
    MakeFileFirebirdWritable firebird.log

    # Security database
	cd /opt/firebird
    MakeFileFirebirdWritable $SecurityDatabase

    # make examples DB(s) writable
    for i in `find /opt/firebird/examples/empbuild -name '*.fdb' -print`
    do
		MakeFileFirebirdWritable $i
    done

	# Architecture (CS/SS) specific permissions
	fixArcSpecificPermissions
}


#------------------------------------------------------------------------
#  parseArgs
#  Parse passed arguments.
#  Set appropriate global flags.

parseArgs() {
	flSilent=0

	while [ -n "$1" ]; do
		case $1 in
			-silent)
				flSilent=1
				;;
			*)
				echo "Invalid option: $1. Known option is '-silent'."
				exit 1
				;;
		esac
		shift
	done

	if [ $flSilent -eq 0 ]; then
		InteractiveInstall=1
		export InteractiveInstall
	fi
}


# classicLibrary.sh
#!/bin/sh
#
#  The contents of this file are subject to the Initial
#  Developer's Public License Version 1.0 (the "License");
#  you may not use this file except in compliance with the
#  License. You may obtain a copy of the License at
#  http://www.ibphoenix.com/main.nfs?a=ibphoenix&page=ibp_idpl.
#
#  Software distributed under the License is distributed AS IS,
#  WITHOUT WARRANTY OF ANY KIND, either express or implied.
#  See the License for the specific language governing rights
#  and limitations under the License.
#
#  The Original Code was created by Mark O'Donohue
#  for the Firebird Open Source RDBMS project.
#
#  Copyright (c) Mark O'Donohue <mark.odonohue@ludwig.edu.au>
#  and all contributors signed below.
#
#  All Rights Reserved.
#  Contributor(s): ______________________________________.
#		Alex Peshkoff
#

#------------------------------------------------------------------------
# init defaults
DefaultLibrary=libfbembed


#------------------------------------------------------------------------
#  For security reasons most files in firebird installation are
#  root-owned and world-readable(executable) only (including firebird).

#  For some files RunUser and RunGroup (firebird)
#  must have write access - lock and log for example.

MakeFileFirebirdWritable() {
    FileName=$1
    chown $RunUser:$RunGroup $FileName

	if [ "$RunUser" = "root" ]
	# In that case we must open databases, locks, etc. to the world...
	# That's a pity, but required if root RunUser choosen.
	then
    	chmod a=rw $FileName
	else
		# This is good secure setting
	    chmod ug=rw,o= $FileName
	fi
}


#------------------------------------------------------------------------
#  fixArcSpecificPermissions
#  Change the permissions specific for CS

fixArcSpecificPermissions() {
    # Fix QLI help
	cd /opt/firebird/help
    chmod a=r help.fdb
}


#------------------------------------------------------------------------
#  changeXinetdServiceUser
#  Change the run user of the xinetd service

changeXinetdServiceUser() {
    InitFile=/etc/xinetd.d/firebird
    if [ -f $InitFile ] 
    then
        editFile $InitFile user "\tuser\t\t\t= $RunUser"
    fi
}


#------------------------------------------------------------------------
#  Update inetd service entry
#  This just adds/replaces the service entry line

updateInetdEntry() {
    newLine="gds_db  stream  tcp     nowait.30000      $RunUser /opt/firebird/bin/fb_inet_server fb_inet_server # Firebird Database Remote Server"
    replaceLineInFile /etc/inetd.conf "$newLine" "^gds_db"
}


#------------------------------------------------------------------------
#  Update xinetd service entry

updateXinetdEntry() {
    cp /opt/firebird/misc/firebird.xinetd /etc/xinetd.d/firebird
    changeXinetdServiceUser
}


#------------------------------------------------------------------------
#  Update inetd service entry 
#  Check to see if we have xinetd installed or plain inetd.  
#  Install differs for each of them.

updateInetdServiceEntry() {
    if [ -d /etc/xinetd.d ] 
    then
        updateXinetdEntry
    else
        updateInetdEntry
    fi
}

# linuxLibrary.sh
#!/bin/sh
#
#  The contents of this file are subject to the Initial
#  Developer's Public License Version 1.0 (the "License");
#  you may not use this file except in compliance with the
#  License. You may obtain a copy of the License at
#  http://www.ibphoenix.com/main.nfs?a=ibphoenix&page=ibp_idpl.
#
#  Software distributed under the License is distributed AS IS,
#  WITHOUT WARRANTY OF ANY KIND, either express or implied.
#  See the License for the specific language governing rights
#  and limitations under the License.
#
#  The Original Code was created by Mark O'Donohue
#  for the Firebird Open Source RDBMS project.
#
#  Copyright (c) Mark O'Donohue <mark.odonohue@ludwig.edu.au>
#  and all contributors signed below.
#
#  All Rights Reserved.
#  Contributor(s): ______________________________________.
#		Alex Peshkoff
#

RunUser=firebird
export RunUser
RunGroup=firebird
export RunGroup
PidDir=/var/run/firebird
export PidDir

#------------------------------------------------------------------------
# Get correct options & misc.

psOptions=-efaww
export psOptions
mktOptions=-q
export mktOptions
tarOptions=z
export tarOptions
tarExt=tar.gz
export tarExt

#------------------------------------------------------------------------
#  Add new user and group

TryAddGroup() {

	AdditionalParameter=$1
	testStr=`grep firebird /etc/group`
	
    if [ -z "$testStr" ]
      then
        groupadd $AdditionalParameter firebird
    fi
	
}


TryAddUser() {

	AdditionalParameter=$1
	testStr=`grep firebird /etc/passwd`
	
    if [ -z "$testStr" ]
      then
        useradd $AdditionalParameter -d /opt/firebird -s /bin/false \
            -c "Firebird Database Owner" -g firebird firebird 
    fi

}


addFirebirdUser() {

	TryAddGroup "-g 84 -r" >/dev/null 2>&1
	TryAddGroup "-g 84" >/dev/null 2>&1
	TryAddGroup "-r" >/dev/null 2>&1
	TryAddGroup " "
	
	TryAddUser "-u 84 -r -M" >/dev/null 2>&1
	TryAddUser "-u 84 -M" >/dev/null 2>&1
	TryAddUser "-r -M" >/dev/null 2>&1
	TryAddUser "-M" >/dev/null 2>&1
	TryAddUser "-u 84 -r" >/dev/null 2>&1
	TryAddUser "-u 84" >/dev/null 2>&1
	TryAddUser "-r" >/dev/null 2>&1
	TryAddUser " "

}


#------------------------------------------------------------------------
#  Detect Distribution.
#	AP: very beautiful, but unused. Let's keep alive for a while. (2005)

detectDistro() {

    # it's not provided...
    if [ -z "$linuxDistro"  ]
    then
	if [ -e /etc/SuSE-release  ]
	then
	    # SuSE
	    linuxDistro="SuSE"
	elif [ -e /etc/mandrake-release ]
	then
	    # Mandrake
	    linuxDistro="MDK"
	elif [ -e /etc/debian_version ]
	then
	    # Debian
	    linuxDistro="Debian"
	elif [ -e /etc/gentoo-release ]
	then
	    # Debian
	    linuxDistro="Gentoo"
	elif [ -e /etc/rc.d/init.d/functions ]
	then
	    # very likely Red Hat
	    linuxDistro="RH"
	elif [ -d /etc/rc.d/init.d ]
	then
	    # generic Red Hat
	    linuxDistro="G-RH"
	elif [ -d /etc/init.d ]
	then
	    # generic SuSE
	    linuxDistro="G-SuSE"
	fi
    fi
}


#------------------------------------------------------------------------
#  print location of init script

getInitScriptLocation() {
    if [ -f /etc/rc.d/init.d/firebird ]
	then
		echo -n /etc/rc.d/init.d/firebird
    elif [ -f /etc/rc.d/rc.firebird ]
	then
		echo -n /etc/rc.d/rc.firebird
    elif [ -f /etc/init.d/firebird ]
	then
		echo -n /etc/init.d/firebird
    fi
}


#------------------------------------------------------------------------
#  stop super server if it is running

stopSuperServerIfRunning() {
	checkString=`ps -eaf | egrep "\b(fbserver|fbguard|fb_smp_server)\b" |grep -v grep`

    if [ ! -z "$checkString" ]
    then
		init_d=`getInitScriptLocation`

        if [ -x "$init_d" ]
		then
			i=1
			while [ $i -le 20 ]
			do
       	    	$init_d stop
				sleep 1
				checkString=`ps -eaf | egrep "\b(fbserver|fbguard|fb_smp_server)\b" |grep -v grep`
				if [ -z "$checkString" ]
				then
					return
				fi
				i=$((i+1))
			done
		fi
    fi
}

#------------------------------------------------------------------------
#  Generate new sysdba password - this routine is used only in the 
#  rpm file not in the install script.

generateNewDBAPassword() {
    # openssl generates random data.
    openssl </dev/null >/dev/null 2>/dev/null
    if [ $? -eq 0 ]
    then
        # We generate 20 random chars, strip any '/''s and get the first 8
        NewPasswd=`openssl rand -base64 20 | tr -d '/' | cut -c1-8`
    fi

    # mkpasswd is a bit of a hassle, but check to see if it's there
    if [ -z "$NewPasswd" ]
    then
        if [ -f /usr/bin/mkpasswd ]
        then
            NewPasswd=`/usr/bin/mkpasswd -l 8`
        fi
    fi

	# On some systems the mkpasswd program doesn't appear and on others
	# there is another mkpasswd which does a different operation.  So if
	# the specific one isn't available then keep the original password.
    if [ -z "$NewPasswd" ]
    then
        NewPasswd="masterkey"
    fi

    writeNewPassword $NewPasswd
}

#------------------------------------------------------------------------
#  change init.d RunUser

changeInitRunUser() {
    NewUser=$1

    InitFile=`getInitScriptLocation`
    if [ -f "$InitFile" ]
    then
        editFile "$InitFile" FBRunUser "FBRunUser=$NewUser"
	    chmod u=rwx,g=rx,o= "$InitFile"
    fi
}


#------------------------------------------------------------------------
# installInitdScript
# Everbody stores this one in a seperate location, so there is a bit of
# running around to actually get it for each packager.
# Update rcX.d with Firebird initd entries
# initd script for SuSE >= 7.2 is a part of RPM package

installInitdScript() {
	Arch=$1
	if [ "$Arch" != super ]; then
		return 0
	fi

	srcScript=""
	initScript=

# This is for RH and MDK specific

    if [ -e /etc/rc.d/init.d/functions ]
    then
        srcScript=firebird.init.d.mandrake
        initScript=/etc/rc.d/init.d/firebird

# SuSE specific

    elif [ -r /etc/SuSE-release ]
    then
        srcScript=firebird.init.d.suse
        initScript=/etc/init.d/firebird
        rm -f /usr/sbin/rcfirebird
        ln -s ../../etc/init.d/firebird /usr/sbin/rcfirebird

# Debian specific

    elif [ -r /etc/debian_version ]
    then
        srcScript=firebird.init.d.debian
        initScript=/etc/init.d/firebird
        rm -f /usr/sbin/rcfirebird
        ln -s ../../etc/init.d/firebird /usr/sbin/rcfirebird

# Slackware specific

    elif [ -r /etc/slackware-version ]
    then
        srcScript=firebird.init.d.slackware
        initScript=/etc/rc.d/rc.firebird
		rclocal=/etc/rc.d/rc.local
		if ! grep -q "$initScript" $rclocal
		then
			cat >>$rclocal <<EOF
if [ -x $initScript ] ; then
	$initScript start
fi
EOF
		fi

# Gentoo specific

    elif [ -r /etc/gentoo-release ]
    then
        srcScript=firebird.init.d.gentoo
        initScript=/etc/init.d/firebird

# Generic...

    elif [ -d /etc/rc.d/init.d ]
    then
        srcScript=firebird.init.d.generic
        initScript=/etc/rc.d/init.d/firebird
    fi

	
	if [ "$initScript" ]
	then
	    # Install the firebird init.d script
    	cp /opt/firebird/misc/$srcScript $initScript
	    chown root:root $initScript
    	chmod ug=rx,o=r $initScript


	    # RedHat and Mandrake specific 
    	if [ -x /sbin/chkconfig ]
	    then
    	    /sbin/chkconfig --add firebird

	    # Gentoo specific 
    	elif [ -x /sbin/rc-update ]
	    then
			/sbin/rc-update add firebird default

	    # Suse (& Debian ?) specific 
    	elif [ -x /sbin/insserv ]
	    then
    	    /sbin/insserv /etc/init.d/firebird
	
		# One more way to register service - used in Knoppix (& Debian ?)
    	elif [ -x /usr/sbin/update-rc.d ]
	    then
			/usr/sbin/update-rc.d firebird start 14 2 3 5 . stop 20 0 1 6 .
	    fi
	
    	# More SuSE - rc.config fillup
	    if [ -f /etc/rc.config ]
    	then
      		if [ -x /bin/fillup ]
	        then
    	      /bin/fillup -q -d = /etc/rc.config /opt/firebird/misc/rc.config.firebird
        	fi
	    elif [ -d /etc/sysconfig ]
    	then
        	cp /opt/firebird/misc/rc.config.firebird /etc/sysconfig/firebird
	    fi
	
	else
		echo "Couldn't autodetect linux type. You must select"
		echo "the most appropriate startup script in /opt/firebird/misc"
		echo "and manually register it in your OS."
	fi

    # Create directory to store pidfile
	if [ ! -d $PidDir ] 
	then
		[ -e $PidDir ] && rm -rf $PidDir
		mkdir $PidDir
	fi
    chown $RunUser:$RunGroup $PidDir
}


#------------------------------------------------------------------------
#  start init.d service

startService() {
	Arch=$1
	if [ "$Arch" != super ]; then
		return 0
	fi

    InitFile=`getInitScriptLocation`
    if [ -f "$InitFile" ]
    then
		"$InitFile" start

		checkString=`ps -eaf | egrep "\b(fbserver|fb_smp_server)\b" |grep -v grep`
		if [ -z "$checkString" ]
		then
			# server didn't start - possible reason bad shell /bin/false for user "firebird"
			echo
			echo Fixing firebird\'s shell to /bin/sh
			echo
			usermod -s /bin/sh firebird
			"$InitFile" start
		fi
	fi
}

#------------------------------------------------------------------------
# If we have right systems remove the service autostart stuff.

removeServiceAutostart() {
	InitFile=`getInitScriptLocation`
	if [ -f "$InitFile" ]; then

		# Unregister using OS command
		if [ -x /sbin/insserv ]; then
			/sbin/insserv /etc/init.d/
		fi
     
		if [ -x /sbin/chkconfig ]; then
			/sbin/chkconfig --del firebird
		fi

		if [ -x /sbin/rc-update ]; then
			/sbin/rc-update del firebird
		fi

		# Remove /usr/sbin/rcfirebird symlink
		if [ -e /usr/sbin/rcfirebird ]
		then
			rm -f /usr/sbin/rcfirebird
		fi
        
		# Remove initd script
		if [ -e /etc/init.d/firebird ]; then
			rm -f /etc/init.d/firebird
		fi

		if [ -e /etc/rc.d/init.d/firebird ]; then
			rm -f /etc/rc.d/init.d/firebird
		fi
	fi
}


#!/bin/sh
#
#  The contents of this file are subject to the Initial
#  Developer's Public License Version 1.0 (the "License");
#  you may not use this file except in compliance with the
#  License. You may obtain a copy of the License at
#  http://www.ibphoenix.com/main.nfs?a=ibphoenix&page=ibp_idpl.
#
#  Software distributed under the License is distributed AS IS,
#  WITHOUT WARRANTY OF ANY KIND, either express or implied.
#  See the License for the specific language governing rights
#  and limitations under the License.
#
#  The Original Code was created by Mark O'Donohue
#  for the Firebird Open Source RDBMS project.
#
#  Copyright (c) Mark O'Donohue <mark.odonohue@ludwig.edu.au>
#  and all contributors signed below.
#
#  All Rights Reserved.
#  Contributor(s): ______________________________________.
#		Alex Peshkoff
#

#  Install script for FirebirdSQL database engine
#  http://www.firebirdsql.org

parseArgs ${*}

checkInstallUser

BuildVersion=2.5.9.27139
PackageVersion=0
CpuType=i686

Version="$BuildVersion-$PackageVersion.$CpuType"

if [ ! -z "$InteractiveInstall" ]
then
    cat <<EOF

Firebird classic $Version Installation

EOF

    AskQuestion "Press Enter to start installation or ^C to abort"
fi

# Here we are installing from a install tar.gz file

if [ -e scripts ]; then
    displayMessage "Extracting install data"
    runAndCheckExit "./scripts/preinstall.sh"
    runAndCheckExit "./scripts/tarinstall.sh"
    runAndCheckExit "./scripts/postinstall.sh"
fi

displayMessage "Install completed"
