#!/bin/bash
#Wes Dillingham
#wes_dillingham@harvard.edu


echo "This script required git, scons, wget and, yum-builddep (from yum-utils) to run sucessfully, should we ensure they are installed? [y/n]"
if [[ $INSTALLPACKAGES == "y" || $INSTALLPACKAGES == "Y" ]]
then
	#to be handled by userdata script ******
	yum install  wget yum-utils wget git
	yum install -y http://mirror-proxy.rc.fas.harvard.edu/epel/7/x86_64/s/scons-2.3.0-1.el7.noarch.rpm
        yum install -y http://mirror-proxy.rc.fas.harvard.edu/centos/6/os/x86_64/Packages/log4cpp-1.0-13.el6_5.1.x86_64.rpm
        yum install -y http://mirror-proxy.rc.fas.harvard.edu/centos/6/os/x86_64/Packages/log4cpp-devel-1.0-13.el6_5.1.x86_64.rpm
	#to be handled by userdata script *******
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
echo "Attempting to checkout branch: $REMOTEBRANCH"
sleep 3
git checkout $REMOTEBRANCH
sleep 2

####Get release sub-version####
RELEASESUBVERSION=`grep -A 3 "static string code_version()" /tmp/one/include/Nebula.h | grep -i return | awk -F "\"" '{print $2}'`
echo "Please add a site specific version: example: house01"
echo "This will cause the rpms to roll out with version $RELEASESUBVERSION-house01"
read HOUSEVERSION
echo "Will roll RPMS with version $RELEASESUBVERSION.$HOUSEVERSION"

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
echo -e "Packaged Release Version = $RELEASEVERSION"
echo -e "Resulting RPM Version    = $RELEASESUBVERSION.$HOUSEVERSION\n"
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
mkdir -p /tmp/opennebula-$RELEASESUBVERSION.$HOUSEVERSION/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

#Create rpmacros to tell rpmbuild where to look
echo "%_topdir /tmp/opennebula-$RELEASESUBVERSION.$HOUSEVERSION" > ~/.rpmmacros
sleep 2

#Create a scratch space to unpack the source code from the git release branch
mkdir /tmp/one_source_scratch
mkdir /tmp/one_source_scratch/opennebula-$RELEASESUBVERSION.$HOUSEVERSION
rsync -a /tmp/one/* /tmp/one_source_scratch/opennebula-$RELEASESUBVERSION.$HOUSEVERSION #copy git branch source

#Making .tar.gz (of the source code above and placing it in the rpm build folder
cd /tmp/one_source_scratch
tar -cvzf /tmp/opennebula-$RELEASESUBVERSION.$HOUSEVERSION/SOURCES/opennebula-$RELEASESUBVERSION.$HOUSEVERSION$TARGZ opennebula-$RELEASESUBVERSION.$HOUSEVERSION

#Now placing the source rom into the rpmbuld folder
echo "Now we will rsync the source rpm contents (build requirements) into our RPM build file structure"
rsync -a --exclude 'opennebula*.tar.gz' /tmp/$EXTRACTEDSOURCEDIR /tmp/opennebula-$RELEASESUBVERSION.$HOUSEVERSION/SOURCES

#Copy the spec file into the rpmbuild folder
echo "Now copying the spec file from the downloaded tarball into the build directory"
cp /tmp/$EXTRACTEDSOURCEDIR/centos7.spec /tmp/opennebula-$RELEASESUBVERSION.$HOUSEVERSION/SPECS

#Applying a swap in the spec file - the spec file needs to incorporate the internal release code as specified by the user
echo "Applying $RELEASESUBVERSION.$HOUSEVERSION to spec file"
sed -i "s/^.*Version\:.*$/Version: $RELEASESUBVERSION.$HOUSEVERSION/g" /tmp/opennebula-$RELEASESUBVERSION.$HOUSEVERSION/SPECS/centos7.spec 

#need to verify it has the dependencies required to build the RPM
yum-builddep /tmp/opennebula-$RELEASESUBVERSION.$HOUSEVERSION/SPECS/centos7.spec


#it all comes down to this
rpmbuild /tmp/opennebula-$RELEASESUBVERSION.$HOUSEVERSION/SPECS/centos7.spec -bb

