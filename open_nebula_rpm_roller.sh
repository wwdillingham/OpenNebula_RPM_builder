#!/bin/bash
set -e
#Wes Dillingham
#wes_dillingham@harvard.edu

SCRIPTLOC=`pwd`

#This script is run non-interactively and expects environemnt variables to be set:
#ONE_GIT_HTTPS_URL: The https url to a git repository (if unset defaults to https://github.com/OpenNebula/one.git)
#ONE_GIT_BRANCH : The branch of the Repository you would like to use as the source for RPM building
#ONE_INTERNAL_VERSION : The string you would like to append to "Version" in the the spec file. Prefix is extracted from the codebase. 
			#so for instance 4.12 is extracted from codebase and ONE_INTERNAL_VERSION is set at 1, this would result in version 4.12.1
#ONE_OUTPUT_DIRECTORY : [OPTIONAL] Directory location for RPMS to be copied to (will be created if non-existant)


: ${ONE_GIT_HTTPS_URL:?"Need to set ONE_GIT_HTTPS_URL environment variable"}
: ${ONE_GIT_BRANCH:?"Need to set ONE_GIT_BRANCH environment variable"}
: ${ONE_INTERNAL_VERSION:?"Need to set ONE_INTERNAL_VERSION environment variable"}
: ${ONE_OUTPUT_DIRECTORY?"ONE_OUTPUT_DIRECTORY is unset and the default will be used, location will be supplied when script is complete"}

echo "The script has detected the following settings from your envrionment"
echo "ONE_GIT_HTTPS_URL is $ONE_GIT_HTTPS_URL this is the repo we will clone"
echo "ONE_GIT_BRANCH is $ONE_GIT_BRANCH this is the branch we will use to make RPMS"
echo "ONE_INTERNAL_VERSION is $ONE_INTERNAL_VERSION this is the internal release ID appended to the official release"
if [[ ! -z "$ONE_OUTPUT_DIRECTORY" ]] #if not empty
then
	echo "ONE_OUTPUT_DIRECTORY is $ONE_OUTPUT_DIRECTORY this is the directory where RPMS files will be placed"
else
	echo "ONE_OUTPUT_DIRECTORY is not set, location will be provided at the end of the script"
fi 

#Clone the repo in /tmp

####Verify that the remote repository exists
if [[ `echo $ONE_GIT_HTTPS_URL | rev | cut -d"." -f2- | rev | xargs curl --silent | wc -l` == 0 ]]
then
	echo "Invalid remote git repository (probably doesnt exist): $ONE_GIT_HTTPS_URL"
	exit
fi

echo "Update local copy of OpenNebula with remote: $ONE_GIT_HTTPS_URL"
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
        git clone $ONE_GIT_HTTPS_URL
fi

cd /tmp/one
echo "Attempting to checkout branch: $ONE_GIT_BRANCH"
git checkout $ONE_GIT_BRANCH

####Get release sub-version####
RELEASESUBVERSION=`grep -A 3 "static string code_version()" /tmp/one/include/Nebula.h | grep -i return | awk -F "\"" '{print $2}'`


echo "Will roll RPMS with version $RELEASESUBVERSION.$ONE_INTERNAL_VERSION"

##Download the most recent sourcepackage subversion
#############
echo "We are going to now roll the changes present in the git working repo that you selected into the latest source package"
echo "release from downloads.opennebula.org. We will swap the source code from the git repo into the package skeleton provided"
echo "by the bundled package. The result will be a new set of compiled RPMs with the latest feature commits"
#Determine the BASE VERSION of open nebula we want to roll the git changes into
GITBASEVERSION=`echo "$ONE_GIT_BRANCH" | awk -F '-' '{print $2}'`
RELEASEURL=`curl -s http://downloads.opennebula.org/packages/ | grep -i "opennebula\-$GITBASEVERSION" | tail -n 1 | awk -F 'href' '{print $2}' | awk -F '"' '{print $2}' | sed s/.$//`

RELEASEVERSION=`echo "$RELEASEURL" | awk -F '-' '{print $2}'`
echo -e "\nGit Target Version       = $GITBASEVERSION"
echo -e "Packaged Release Version = $RELEASEVERSION"
echo -e "Resulting RPM Version    = $RELEASESUBVERSION.$ONE_INTERNAL_VERSION\n"
echo -e "The above numbers should be reasonably similar if not CTRL-C"
sleep 4

TARGZ=".tar.gz"
REMOTETARGZ=`curl -s http://downloads.opennebula.org/packages/$RELEASEURL/CentOS-7/ | grep -i "tar.gz" | awk -F 'href' '{print $2}' | awk -F '"' '{print $2}'`
FULLURL="http://downloads.opennebula.org/packages/$RELEASEURL/CentOS-7/$REMOTETARGZ"
#TODO: Check if file already exists
if [ -f /tmp/$REMOTETARGZ ] 
then
	echo "ERROR: File already exists, please remove or move it from /tmp/$REMOTETARGZ this script will not generate RPMS from a file it did not download"
	exit
else
	echo "Now Downloading the packaged release version from  $FULLURL"
	echo "Downloaded filename is $REMOTETARGZ"
	wget --directory-prefix=/tmp $FULLURL
fi
#Now we have the file so we should extract it. 
sleep 2
echo "Now extracting the archive we downloaded: /tmp/$REMOTETARGZ"
sleep 2
tar xf /tmp/$REMOTETARGZ -C /tmp 
EXTRACTEDSOURCEDIR=`tar -tf  /tmp/$REMOTETARGZ  | grep -v ".rpm" | grep -i src`
echo "EXTRACTEDSOURCEDIR is $EXTRACTEDSOURCEDIR"

#####We now need to swap in the version to the SPEC file. 
if [ -d /tmp/$EXTRACTEDSOURCEDIR ]
then
	echo "Source directory found at /tmp/$EXTRACTEDSOURCEDIR"
        echo "Now Extracting the source RPM to grab the spec file"
	cd /tmp/$EXTRACTEDSOURCEDIR
        rpm2cpio /tmp/$EXTRACTEDSOURCEDIR/*.src.rpm | cpio -idmv 
	cd /tmp
else 
	echo "ERROR: Cant find source directory in downloaded tarball, expected to find it here: /tmp/$EXTRACTEDSOURCEDIR"
fi

sleep 3

#BUILD rpmbuild file strcuture
mkdir -p /tmp/opennebula-$RELEASESUBVERSION.$ONE_INTERNAL_VERSION/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

#Create rpmacros to tell rpmbuild where to look
echo "%_topdir /tmp/opennebula-$RELEASESUBVERSION.$ONE_INTERNAL_VERSION" > ~/.rpmmacros
sleep 2

#Create a scratch space to unpack the source code from the git release branch
mkdir /tmp/one_source_scratch
mkdir /tmp/one_source_scratch/opennebula-$RELEASESUBVERSION.$ONE_INTERNAL_VERSION
rsync -a /tmp/one/* /tmp/one_source_scratch/opennebula-$RELEASESUBVERSION.$ONE_INTERNAL_VERSION #copy git branch source

#Making .tar.gz (of the source code above and placing it in the rpm build folder
cd /tmp/one_source_scratch
tar -cvzf /tmp/opennebula-$RELEASESUBVERSION.$ONE_INTERNAL_VERSION/SOURCES/opennebula-$RELEASESUBVERSION.$ONE_INTERNAL_VERSION$TARGZ opennebula-$RELEASESUBVERSION.$ONE_INTERNAL_VERSION

#Now placing the source rom into the rpmbuld folder
echo "Now we will rsync the source rpm contents (build requirements) into our RPM build file structure"
rsync -a --exclude 'opennebula*.tar.gz' /tmp/$EXTRACTEDSOURCEDIR /tmp/opennebula-$RELEASESUBVERSION.$ONE_INTERNAL_VERSION/SOURCES

#Copy the spec file into the rpmbuild folder
echo "Now copying the spec file from the downloaded tarball into the build directory"
cp /tmp/$EXTRACTEDSOURCEDIR/centos7.spec /tmp/opennebula-$RELEASESUBVERSION.$ONE_INTERNAL_VERSION/SPECS

#Applying a swap in the spec file - the spec file needs to incorporate the internal release code as specified by the user
echo "Applying $RELEASESUBVERSION.$ONE_INTERNAL_VERSION to spec file"
sed -i "s/^.*Version\:.*$/Version: $RELEASESUBVERSION.$ONE_INTERNAL_VERSION/g" /tmp/opennebula-$RELEASESUBVERSION.$ONE_INTERNAL_VERSION/SPECS/centos7.spec 

#need to verify it has the dependencies required to build the RPM
yum-builddep -y /tmp/opennebula-$RELEASESUBVERSION.$ONE_INTERNAL_VERSION/SPECS/centos7.spec

#Build dependencies are done at this point, install the software that is bundled in the repo: scons and log4cpp

#LOG4CPP
tar -xvzf $SCRIPTLOC/log4cpp-1.1.1.tar.gz -C $SCRIPTLOC
cd $SCRIPTLOC/log4cpp
./configure
make
make install
rm -f /usr/local/lib/*.so*

#it all comes down to this
rpmbuild /tmp/opennebula-$RELEASESUBVERSION.$ONE_INTERNAL_VERSION/SPECS/centos7.spec -bb 

#Copy contents out of the rpm-build buildir 
if [[ ! -z "$ONE_OUTPUT_DIRECTORY" ]] #if not empty string / user specified a location
then
	mkdir -p $ONE_OUTPUT_DIRECTORY
	rsync -a /tmp/opennebula-$RELEASESUBVERSION.$ONE_INTERNAL_VERSION/RPMS/* $ONE_OUTPUT_DIRECTORY
else #empty string / user did not specify a location
	ONE_OUTPUT_DIRECTORY="/tmp/opennebula-$RELEASESUBVERSION.$ONE_INTERNAL_VERSION/RPMS"
fi

echo "RPM build script is complete: if successful, RPM files located in $ONE_OUTPUT_DIRECTORY"
