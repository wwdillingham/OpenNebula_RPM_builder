#!/bin/bash
#Wes Dillingham
#wes_dillingham@harvard.edu

#Clone the repo in /tmp
echo "Update local copy of OpenNebula with remote...."
sleep 3
if [ -d /tmp/one ]
then
        cd /tmp/one
        echo "OpenNebula Repository already exists, going to do a git pull to ensure we are up to date with remote"
        sleep 3
        git checkout master --quiet
        git pull
else
        echo "Looks like we dont have any repository so going to clone a fresh copy"
        sleep 3
        cd /tmp
        git clone https://github.com/OpenNebula/one.git
fi


echo "****** Remote Update Complete **********"
git branch
echo "Generating list of remote branches:.... "
sleep 3
cd /tmp/one
git branch -a | grep -i remote | awk -F '/' '{print $3}'
echo "Please select a branch that we want to roll into an RPM (example: one-1.0 )"
read REMOTEBRANCH
echo "Attempting to checkout branch: $REMOTEBRANCH"
sleep 3
git checkout $REMOTEBRANCH
sleep 2

##Download the most recent sourcepackage subversion
#############
echo "We are going to now roll the changes present in the git working repo that you selected into the latest source package"
echo "release from downloads.opennebula.org. We will swap the source code from the git repo into the package skeleton provided"
echo "by the bundled package. The result will be a new set of compiled RPMs with the latest feature commits"
#Determine the BASE VERSION of open nebula we want to roll the git changes into
GITBASEVERSION=`echo "$REMOTEBRANCH" | awk -F '-' '{print $2}'`
RELEASEURL=`curl -s http://downloads.opennebula.org/packages/ | grep -i "opennebula\-$GITBASEVERSION" | tail -n 1 | awk -F 'href' '{print $2}' | awk -F '"' '{print $2}' | sed s/.$//`

RELEASEVERSION=`echo "$RELEASEURL" | awk -F '-' '{print $2}'`

echo "GITBASEVERSION IS $GITBASEVERSION"
echo "RELEASEURL IS $RELEASEURL"
echo "RELEASEVERSION IS $RELEASEVERSION"


echo -e "\nGit Target Version       = $GITBASEVERSION"
echo -e "Packaged Release Version = $RELEASEVERSION \n"
echo -e "The above two numbers should be reasonably similar if not CTRL-C"
sleep 4

#wget http://downloads.opennebula.org/packages/opennebula-4.12.1/CentOS-7/CentOS-7-opennebula-4.12.1-1.tar.gz
#URLSTUB="http://downloads.opennebula.org/packages/$RELEASEURL/CentOS-7/CentOS-7-$RELEASEURL"
#TARGZ=".tar.gz"
#FULLURL=$FULLURL$TARGZ


REMOTETARGZ=`curl -s http://downloads.opennebula.org/packages/$RELEASEURL/CentOS-7/ | grep -i "tar.gz" | awk -F 'href' '{print $2}' | awk -F '"' '{print $2}'`
FULLURL="http://downloads.opennebula.org/packages/$RELEASEURL/CentOS-7/$REMOTETARGZ"
echo "Now Downloading the packaged release version from  $FULLURL"
#TODO: Check if file already exists
if [ -f /tmp/$REMOTETARGZ ] 
then
	echo "ERROR: File already exists, please remove or move it from /tmp/$REMOTETARGZ this script will not generate RPMS from a file it did not download"
else
	wget --directory-prefix=/tmp $FULLURL
fi

