#!/bin/bash
#Wes Dillingham
#wes_dillingham@harvard.edu

echo "The following dependencies are required for the source compilation / rpm building: rpm-build libcurl-devel libxml2-devel xmlrpc-c-devel mysql-devel sqlite-devel scons java-1.7.0-openjdk-devel log4cpp log4cpp-devel"
echo "Should this script attempt to install them? [y/n]"
read INSTALLPACKAGES
if [[ $INSTALLPACKAGES == "y" || $INSTALLPACKAGES == "Y" ]]
then
        yum install libcurl-devel libxml2-devel xmlrpc-c-devel mysql-devel sqlite-devel scons java-1.7.0-openjdk-devel rpm-build ruby scons gcc-c++ gcc make git rsync wget scons
        yum install -y http://mirror-proxy.rc.fas.harvard.edu/centos/6/os/x86_64/Packages/log4cpp-1.0-13.el6_5.1.x86_64.rpm
        yum install -y http://mirror-proxy.rc.fas.harvard.edu/centos/6/os/x86_64/Packages/log4cpp-devel-1.0-13.el6_5.1.x86_64.rpm
fi


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
#TODO Need to validate that it is is a legit branch
echo "Attempting to checkout branch: $REMOTEBRANCH"
sleep 3
git checkout $REMOTEBRANCH
sleep 2

####Get release sub-version####
RELEASESUBVERSION=`grep -A 3 "static string code_version()" /tmp/one/include/Nebula.h | grep -i return | awk -F "\"" '{print $2}'`
echo "Please add a site specific version: example: house01"
echo "This will cause the rpms to roll out with version $RELEASESUBVERSION-house01"
read HOUSEVERSION
echo "Will roll RPMS with version $RELEASESUBVERSION-$HOUSEVERSION"

##Download the most recent sourcepackage subversion
#############
echo "We are going to now roll the changes present in the git working repo that you selected into the latest source package"
echo "release from downloads.opennebula.org. We will swap the source code from the git repo into the package skeleton provided"
echo "by the bundled package. The result will be a new set of compiled RPMs with the latest feature commits"
#Determine the BASE VERSION of open nebula we want to roll the git changes into
GITBASEVERSION=`echo "$REMOTEBRANCH" | awk -F '-' '{print $2}'`
RELEASEURL=`curl -s http://downloads.opennebula.org/packages/ | grep -i "opennebula\-$GITBASEVERSION" | tail -n 1 | awk -F 'href' '{print $2}' | awk -F '"' '{print $2}' | sed s/.$//`

RELEASEVERSION=`echo "$RELEASEURL" | awk -F '-' '{print $2}'`
echo -e "\nGit Target Version       = $GITBASEVERSION"
echo -e "Packaged Release Version = $RELEASEVERSION \n"
echo -e "Resulting RPM Version    = $RELEASESUBVERSION-$HOUSEVERSION"
echo -e "The above two numbers should be reasonably similar if not CTRL-C"
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
echo "Now we will build the file structure for an RPM build."
mkdir -p /tmp/opennebula-$RELEASESUBVERSION-$HOUSEVERSION/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
#echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros
echo "%_topdir /tmp/opennebula-$RELEASESUBVERSION-$HOUSEVERSION" > ~/.rpmmacros
sleep 2
echo "need to make the source tar.gz from git branch and stick it in SOURCES"
mkdir /tmp/one_source_scratch
mkdir /tmp/one_source_scratch/$RELEASEURL
rsync -a /tmp/one/* /tmp/one_source_scratch/$RELEASEURL
echo "making /tmp/$RELEASEURL-fasrc/SOURCES/$RELEASEURL$TARGZ from stuff here: /tmp/one_source_scratch/$RELEASEURL" 
cd /tmp/one_source_scratch
tar -cvzf /tmp/opennebula-$RELEASESUBVERSION-$HOUSEVERSION/SOURCES/$RELEASEURL$TARGZ $RELEASEURL
echo "Now we will rsync the source rpm contents (build requirements) into our RPM build file structure"
rsync -a --exclude 'opennebula*.tar.gz' /tmp/$EXTRACTEDSOURCEDIR /tmp/opennebula-$RELEASESUBVERSION-$HOUSEVERSION/SOURCES
echo "rsync complete"
sleep 2
echo "Now copying the spec file from the downloaded tarball into the build directory"
cp /tmp/$EXTRACTEDSOURCEDIR/centos7.spec /tmp/opennebula-$RELEASESUBVERSION-$HOUSEVERSION/SPECS
# sed -i 's/^.*Version\:.*$/Version: 4.12.3-fasrc01/g'
echo "Applying $RELEASESUBVERSION-$HOUSEVERSION to spec file"
sed -i "s/^.*Version\:.*$/Version: $RELEASESUBVERSION-$HOUSEVERSION/g" /tmp/opennebula-$RELEASESUBVERSION-$HOUSEVERSION/SPECS/centos7.spec 
echo "spec file copy complete"
sleep 2
echo "Will now build the RPMs"
rpmbuild /tmp/opennebula-$RELEASESUBVERSION-$HOUSEVERSION/SPECS/centos7.spec -bb

