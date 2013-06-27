#!/bin/sh
#
# Release a new Jasper_{date}.apk to http://new.bomoda.com/android/release/
# 
# Renjie Weng <renjie.weng@bomoda.com>
# Jun 26th, 2013

if [ $# -eq 1 ] 
then
    user=$1
else
    echo `basename $0`: must have one parameter username.
    exit 1
fi

date=`date +%Y%m%d`
filename='Jasper.apk'
filenameToday="Jasper_$date.apk"

wwwServer='bastion-12.bomoda.com'
lanServer='10.0.1.55'
releaseAddr='http://new.bomoda.com/android/release/'

wwwDir="/home/$user/temp/"
lanDir='/opt/projects/android/release/'

# copy apk file from localhost to bastionWWWServer
scp $filename $user@$wwwServer:$wwwDir 1>/dev/null

# copy apk file from bastion to remoteLANServer
ssh $user@$wwwServer scp $wwwDir$filename $lanServer:$lanDir$filenameToday

# check file uploaded
response=`curl $releaseAddr --silent`
if [ `expr "$response" : "^.*$filenameToday.*$"` -gt 0 ]
then
    echo 'Uploaded!'
    exit 0
else
    echo 'Upload failed!'
    exit 1
fi
