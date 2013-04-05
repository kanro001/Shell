#!/bin/sh
# 
# ec2-backup    Renjie Weng     <rweng@stevens.edu>     March 2013
#
# ERROR CODE
# 1 -- environment variables , 2 -- local variables , 3 -- execution error

old=$@

# *Required environment variables
flags_ssh='' # export EC2_BACKUP_FLAGS_SSH="-i sk"
# Optional environment variables
flags_aws='' # export EC2_BACKUP_FLAGS_AWS="[-k, --key] keypair [-t, --instance-type] instance_type [-z, --availability-zone] zone"
flags_zone='-z us-east-1b'

# *Required parameters
instance=''
directory=''
# Optinal parameters
method='dd'
verbose='false'
help() {
	echo "    Name
        ec2-backup -- backup a directory into Elastic Block Storage (EBS)
	
    Synopsis
        \`basement \"$0\"\` [-hv] [-i instance] [-t tag] -d dir
        
    Description
        The ec2-backup tool performs a backup of the given directory into Amazon
        Elastic Block Storage (EBS).  This is achieved by creating a volume of
        the appropriate size, attaching it to an EC2 instance and finally copying
        the files from the given directory into this volume.
    
    Options
        ec2-backup accepts the following command-line flags:
        
        -h           Print a usage statement and exit.
        
        -i instance  Attach the volume in question to the given instance.
        
        -m method    Use the given method to perform the backup.  Valid methos
                     are \`dd\' and \`rsync\'; default is \`dd\'.
        
        -v           Be verbose.  If not specified, ec2-backup will not generate
                     any output at all (unless an error is encountered).
    
    Details
        ec2-backup will perform a backup of the given directory to an ESB volume.
        The backup is done in one of two ways: via direct write to the volume
        (utilizing tar(1) on the local host and dd(1) on the remote instance), or
        via a (possibly incremental) filesystem sync (utilizing rsync(1)).
        
		ec2-backup will create a new volume, the size of which will be
        at least two times the size of the directory to be backed up.
        
        Unless an instance is given using the -i flag, ec2-backup will create an
        instance suitable to perform the backup, attach the volume in question
        and then back up the data from the given directory using the specified
        method and then shut down the instance it created.
    
    Output
        Unless the -v flag is given, ec2-backup will not generate any output
        unless any errors are encountered.  Otherwise, it may print out some use-
        ful information about what steps it is currently performing.
        
        Any errors encountered cause a meaningful error message to be printed to
        STDERR.
    
    Environment
        ec2-backup assumes that the user has set up their environment for general
        use with the EC2 tools.  That is, it will not set or modify the variables
        AWS_CONFIG_FILE, EC2_CERT, EC2_HOME or EC2_PRIVATE_KEY.
        
        ec2-backup allows the user to add custom flags to the EC2 related com-
        mands it invokes EC2_BACKUP_FLAGS_AWS environment variable.
        
        ec2-backup also assumes that the user has set up their ~/.ssh/config file
        to access instances in EC2 via ssh(1) without any additional settings.
        It does allow the user to add custom flags to the ssh(1) commands it
        invokes via the EC2_BACKUP_FLAGS_SSH environment variable.
    
    Exit Status
        The ec2-backup will exit with a return status of 0 under normal circum-
        stances.  If an error occurred, ec2-backup will exit with a value >0.
	
    Erroe return number
        1 -- environment variables , 2 -- local variables , 3 -- execution error

    Examples
        The following examples illustrate common usage of this tool.

    To back up the entire filesystem to a volume tagged as \`backup\' (which,
    it should be noted, must hence also contain a filesystem) using rsync(1):

        ec2-backup -m rsync -d /

    To create a complete backup of the current working directory using
    defaults (and thus not requiring a filesystem to exist on the volume):

        ec2-backup -d .

    Suppose a user has their ~/.ssh/config set up to use the private key
    ~/.ec2/stevens but wishes to use the key ~/.ssh/ec2-key instead:

        export EC2_BACKUP_FLAGS_SSH=\"-i ~/.ssh/ec2-key\"
        ec2-backup -d .

    To force creation of an instance type of t1.micro instead of whatever
    defaults might apply

        export EC2_BACKUP_FLAGS_AWS=\"--instance-type t1.micro\"
        ec2-backup -d .

    See Also
        dd(1), ec2-start-instance(1), tar(1), rsync(1)

    History
        created by Renjie Weng <rweng@stevens.edu>, homeword4 of class
        \"Aspects of System Administration\" in the Spring of 2013.
        ec2-backup was originally assigned by Jan Schaumann
        <jschauma@cs.stevens.edu> as a homework assignment for the class
        at Stevens Institute of Technology in the Spring of 2011.

"
	exit 0;
}

#
# Set parameters
#

usage() {
		echo `basename $0`: ERROR: $* 1>&2 
		# & indicates that what follows is a file descriptor and not a filename
		# >& is the syntax to redirect a stream to another file descriptor - 0 is stdin. 1 is stdout. 2 is stderr.
		echo usage: `basename $0` '[-hv] [-i instance] -d dir' 1>&2
		exit 2 
}

method() {
	echo `basename $0`: ERROR $* 1>&2
	echo '-m method    Use the given method to perform the backup.  Valid methos
             are `dd` and `rsync`; default is `dd`.'
	exit 2
}

while [ $# -gt 0 ] 
do
	case $1 in
		-h) help;;
		-v) if [ `expr "$2" : "^.*$"` -eq 0 ] 
			then
				shift
			elif [  `expr "$2" : "[^-].*"` -gt 0 ]
			then
				usage "bad argument $1 $2";
			else
				verbose='true';
				shift;
			fi
			;;
		-i) [ `expr "$2" : "^-.*$"` -gt 0 ] && usage "bad argument $1 $2"; 
			[ `expr "$2" : "^.*$"` -eq 0 ] && usage "bad argument $1";
			shift; instance="$1"; shift;;
		-m) if [ "$2" != "dd" ] && [ "$2" != "rsync" ]
			then method "bad argument $1 $2"
			fi; 
			shift; method="$1"; shift;;
		-d) [ `expr "$2" : "^-.*$"` -gt 0 ] && usage "bad argument $1 $2";
			[ `expr "$2" : "^.*$"` -eq 0 ] && usage "bad argument $1";
			shift; directory="$1";shift;;
		-*) usage "bad argument $1";;
		*) usage "bad argument $1";;
	esac
done

	# Exam the directory
	if [ "$directory" = "" ]
	then
		usage "require argument -d dir"
	fi
	if [ `ls -l $directory | wc -l` -eq 0 ] 
	then
		exit 2
	fi

if [ $verbose = "true" ]
then
	echo "ec2-backup -v -i $instance -m $method -d $directory"
fi


#
# Set environment variables
#

if [ -z "$EC2_BACKUP_FLAGS_SSH" ] # exam empty string
then 
	echo environment variable required: '$EC2_BACKUP_FLAGS_SSH' 
	exit 1
else
	# Check whether the sshFile is existed
	sshFile=`expr "$EC2_BACKUP_FLAGS_SSH" : "^-i \(.*\)$"`
	if [ `ls -l $sshFile | wc -l` -eq 0 ] 
	then
		echo 'Environment variable $EC2_BACKUP_FLAGS_SSH should be set as "-i [directory to ssh file]"' 1>&2
		exit 1 
	else
		flags_ssh="$EC2_BACKUP_FLAGS_SSH"
	fi
fi

if [ ! -z "$EC2_BACKUP_FLAGS_AWS" ] 
then
	flags_aws="$EC2_BACKUP_FLAGS_AWS"
	if [ "`expr "$EC2_BACKUP_FLAGS_AWS" : "^.*\(\(-z\|--availability-zone\) [^ ]*\) \?.*$"`" != ""  ]
	then
		flags_zone=`expr "$EC2_BACKUP_FLAGS_AWS" : "^.*\(\(-z\|--availability-zone\) [^ ]*\) \?.*$"` 2>/dev/null
	fi
fi

#
# Verbose environment variables
#
if [ $verbose = "true" ]
then
	echo 'EC2_BACKUP_FLAGS_SSH  = '$flags_ssh
	echo 'EC2_BACKUP_FLAGS_ZONE = '$flags_zone
	echo 'EC2_BACKUP_FLAGS_AWS  = '$flags_aws
fi

#
# Set backup volume
#
	# TODO
	# Verify whether the specify volume has enough space to store the backup directory? If not, alarm.

	# create a new volume (unless the -t flag was specified and
	# a volume matching the given tag already exists).  The new volume will be
	# at least two times the size of the directory to be backed up.

	# Create a new volume
	tag=`date +%Y%m%d_%H:%M:%S`
	size=`du -shBM $directory | cut -f1 | sed s/M//` # unit MegaBytes
	size=`expr $size + $size`
	if [ `expr $size % 1024` -eq 0 ]
	then
		size=`expr $size / 1024` #unit GigaBytes
	else
		size=`expr $size / 1024` #unit GigaBytes
		size=`expr $size + 1`
	fi
	backupVolume=`$EC2_HOME/bin/ec2-create-volume -s $size $flags_zone | grep VOLUME | cut -f2`
	$EC2_HOME/bin/ec2-create-tags $backupVolume --tag "Name=$tag" 1>>/dev/null

if [ $backupVolume = "" ]
then
	echo "Cannot create new volume for backup" 1>&2
	echo "Please check the environment variable: EC2_BACKUP_FLAGS_AWS for zone fields" 1>&2
	exit 1
fi

[ $verbose = "true" ] && echo "backup volume=$backupVolume"


#
# Set backup instance
#

	# Unless an instance is given using the -i flag, 
	# ec2-backup will create an instance suitable to perform the backup

	Create_Instance(){
		if [ `uname -v | grep -c Ubuntu` -eq 1 ]
		then
			currentKernel="Ubuntu";
		elif [ `uname -v | grep -c Fedora` -eq 1 ]
		then
			currentKernel="Fedora";
		elif [ `uname -v | grep -c OmniOS` -eq 1 ]
		then
			currentKernel="OmniOS";
		elif [ `uname -v | grep -c FreeBSD` -eq 1 ]
		then
			currentKernel="FreeBSD";
		elif [ `uname -v | grep -c NetBSD` -eq 1 ]
		then
			currentKernel="NetBSD";
		else
			currentKernel="Ubuntu";
		fi
		
		currentMachine=`uname -m`
		amiID="ami-1fb63576"

		if [ "$currentKernel" = "Ubuntu" ]
		then
			if [ "$currentMachine" = "i386" ]
			then
				amiID="ami-fab92b93"; # /dev/xvdf
			else # $currentMachine = "x86_64"
				amiID="ami-1fb63576"; # /dev/xvdf
			fi
		elif [ "$currentKernel" = "Fedora" ]
		then
			if [ "$currentMachine" = "i386" ]
			then
				amiID="ami-0d44cd64"; # /dev/sdf1
		    else
		        amiID="ami-6145cc08"; # /dev/sdf1
			fi
		elif [ "$currentKernel" = "OmniOS" ]
		then
			if [ "$currentMachine" = "i386" ]
			then
				amiID="ami-4e2c9727"; # /dev/sdf
		    else
		        amiID="ami-505ce739"; # /dev/sdf
			fi
		elif [ "$currentKernel" = "FreeBSD" ]
		then
			if [ "$currentMachine" = "i386" ]
			then
				amiID="ami-9d38baf4"; # /dev/sdf
		    else
		        amiID="ami-d6f44ebf"; # /dev/sdf
			fi
		elif [ "$currentKernel" = "NetBSD" ]
		then
			if [ "$currentMachine" = "i386" ]
			then
				amiID="ami-5d0f8034"; # /dev/sdf1
		    else
		        amiID="ami-98904bf1"; # /dev/sdf1
			fi
		fi
		instance=`ec2-run-instances $amiID $flags_aws | grep INSTANCE | cut -f2`
		tempInstance="true";
		[ $verbose = "true" ] && echo "instance=$instance"
	}

	# Check whether the instance is existed? If NOT, exit 2
if [ "$instance" = "" ] # there are 2 scenarios here: no argument [-i], argument -i ""
then
	Create_Instance;
else
	hasInstance=`$EC2_HOME/bin/ec2-describe-instances $instance | grep -c INSTANCE`
	if [ $hasInstance -eq 0 ]
	then
		$EC2_HOME/bin/ec2-delete-volume $backupVolume
		echo usage:`basename $0` instance number '"'$instance'"' not found  1>&2
		exit 2
	else
		[ $verbose = "true" ] && echo "instance $instance" existed
	fi
fi

#
# Run backup instance
#

	# Ask what the status of -i instance? 
	# if running -- do nothing, pending -- wait, stopped -- start, terminated or shutting-down -- exit 2.
done="false"
originalStatus=`$EC2_HOME/bin/ec2-describe-instances $instance | grep INSTANCE | cut -f6`
while [ "$done" = "false" ]
do
	status=`$EC2_HOME/bin/ec2-describe-instances $instance | grep INSTANCE | cut -f6`

	if [ "$status" = "running" ]
	then
		done="true"
		sleep 10 # waiting for checking
	elif [ "$status" = "pending" ]
	then
		[ $verbose = "true" ] && echo Waiting for running...
		sleep 10
	elif [ "$status" = "stopped" ]
	then
		# Run the instance
		$EC2_HOME/bin/ec2-start-instances $instance > /dev/null # save ouput without showing on terminal
		sleep 30
	elif [ "$status" = "stopping" ]
	then
		[ $verbose = "true" ] && echo Waiting for stopping...
		sleep 10
	elif [ "$status" = "terminated" ] || [ "$status" = "shutting-down" ]
	then
		echo "The instance $instancer is $status,"
		echo "Please specify a new instance id," 1>&2
		echo "or remove arguments [-i instance] to create a new one." 1>&2
		exit 2
	fi
done

#
# Attach volume to the instance
#

device="/dev/xvdf"	
	# Linux Devices: /dev/sdf through /dev/sdp
	# Note: Newer linux kernels may rename your devices to /dev/xvdf through /dev/xvdp internally, 
	# even when the device name entered here (and shown in the details) is /dev/sdf through /dev/sdp.

   # Attach volume to instance
$EC2_HOME/bin/ec2-attach-volume $backupVolume -i $instance -d $device 1>/dev/null
sleep 15
	
	# Loop until the volume status changes
done="false"
while [ "$done" = "false" ]
do
	status=`$EC2_HOME/bin/ec2-describe-volumes $backupVolume | grep ATTACHMENT | grep $instance | cut -f5`
	if [ "$status" = "attached" ]
	then
		done="true"
	else
		[ $verbose = "true" ] && echo Waiting...
		sleep 10
	fi
done

[ $verbose = "true" ] && echo Volume $tag is attached

EC2_HOST=`$EC2_HOME/bin/ec2-describe-instances $instance | grep amazonaws.com | cut -f4`

[ $verbose = "true" ] && echo "$EC2_HOST"

#
# Mount backup volume to the instance
#
mountDir='/mnt/ec2-backup'
ssh $flags_ssh -o StrictHostKeyChecking=no ubuntu@$EC2_HOST sudo mkdir $mountDir 2>/dev/null

[ $verbose = "true" ] && echo 'backup device= '$device

ssh $flags_ssh ubuntu@$EC2_HOST sudo mkfs.ext3 $device 1>/dev/null 2>/dev/null
sleep 15
ssh $flags_ssh ubuntu@$EC2_HOST sudo mount $device $mountDir
exitCode=$?
if [ "$exitCode" -eq "32" ] # unable to mount caused by unformatted error
then
	$EC2_HOME/bin/ec2-detach-volume $backupVolume -i $instance 1>/dev/null
	$EC2_HOME/bin/ec2-delete-volume $backupVolume 1>/dev/null
	if [ "$tempInstance" = "true" ]
	then
		# Terminate
		$EC2_HOME/bin/ec2-terminate-instances $instance 1>/dev/null
	else
		if [ "$originalStatus" != "running" ] && [ "$originalStatus" != "pending" ]
		then
			# Stop
			$EC2_HOME/bin/ec2-stop-instances $instance 1>/dev/null
		fi  
	fi
	echo "Volume $backupVolume is unable to be formatted on instance $instance" 1>&2
	exit 3
fi
	# Change owner of mount Dir to ubuntu
ssh $flags_ssh ubuntu@$EC2_HOST sudo chown ubuntu:ubuntu $mountDir

#
# Ececute backup
#
	# Use the given method to perform the backup.  
	# Valid methods are `dd' and `rsync'; default is `dd'.

[ $verbose = "true" ] && echo "directory=" $directory

	# dd
if [ "$method" = "dd" ]
then
	# Create tar on local host
	date=`date +%s`
	tarName="backup_$date.tar"
	if [ $verbose = "true" ] 
	then
		tar -czf $tarName $directory
		echo $tarName
	else
		tar -czf $tarName $directory 1>/dev/null 2>/dev/null
	fi

	# `dd` to instance
	if [ $verbose = "true" ]
	then
		dd if=$tarName | ssh $flags_ssh ubuntu@$EC2_HOST dd of=$mountDir/$tarName obs=512k
	else
		dd if=$tarName 2>/dev/null | ssh $flags_ssh ubuntu@$EC2_HOST dd of=$mountDir/$tarName obs=512k >/dev/null 2>&1
	fi

	# Uncompress tar on remote host
	ssh $flags_ssh ubuntu@$EC2_HOST tar -xf $mountDir/$tarName -C $mountDir
	ssh $flags_ssh ubuntu@$EC2_HOST rm $mountDir/$tarName

	# Remove tar on local host
	rm $tarName # Why no such file or directory? throwed by dd if ?
	
	# synrc
elif [ "$method" = "rsync" ]
then
	if [ $verbose = "true" ]
	then
		rsync -e "ssh $flags_ssh" -avRz $directory ubuntu@$EC2_HOST:$mountDir
	else
		rsync -e "ssh $flags_ssh" -avRz $directory ubuntu@$EC2_HOST:$mountDir >/dev/null 2>&1
	fi
fi

#
# Unmount backup volume
#
ssh $flags_ssh ubuntu@$EC2_HOST sudo umount $mountDir

#
# Detach backup volume
#
$EC2_HOME/bin/ec2-detach-volume $backupVolume -i $instance 1>/dev/null

#
# Leave it running or Stop or Terminate the backup instance
#
	# Terminate if -i instance is not given, but Created during the process
if [ "$tempInstance" = "true" ]
then
	# Terminate
	if [ $verbose = "true" ]
	then
		$EC2_HOME/bin/ec2-terminate-instances $instance
	else
		$EC2_HOME/bin/ec2-terminate-instances $instance 1>/dev/null
	fi
else
	if [ "$originalStatus" != "running" ] && [ "$originalStatus" != "pending" ]
	then
		# Stop
		if [ $verbose = "true" ]
		then
			$EC2_HOME/bin/ec2-stop-instances $instance
		else
			$EC2_HOME/bin/ec2-stop-instances $instance 1>/dev/null
		fi
	fi
fi

exit 0
