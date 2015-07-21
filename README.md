# OpenNebula_RPM_builder
This is a utility for building new RPM files out of a git branch.

The utility is desgined to use an OpenNebula cluster to do the actual compilation of the RPMS.

Files
-----
userdata.sh: desgined to be uploaded into OpenNebula's Files & Kernels section. This script prepares the build instance to be able to run open_nebula_rpm_roller.sh and then invokes it.
open_nebula_rpm_roller.sh: This script is fed information about where to find a git branch of OpenNebula, then compiles it into an RPM using a .spec file which is extracted out of source archives at downloads.openenbula.org. This script either requires contextual variables be set in the OpenNebula template or can be run with the environmental variables. 


Usage
-----
- Upload the userdata.sh script into the files section of OpenNebula. Choose a name (for example userdata.sh) and choose type: "Context"
- Create a template, which is comprised of a Centos7 image, and the contextual custom Variables (see below).
- Under the templates "Context" section and the "files" tab select the file uploaded in the previous step. In the Init scripts field include "init.sh userdata.sh" substituting userdata.sh to whatever you named the file in OpenNebula, not necessarily what the filename was before you uploaded it.  

Contextualization Variables
---------------------------
These Variables need to either be set using the Custom Vars component of templates in OpenNebula or needs to be set as enrironmental variables manually on a build system.
- ONE_GIT_HTTPS_URL Required, https url of the git repo, Example: https://github.com/fasrc/one.git
- ONE_GIT_BRANCH Required, branch of the above repo. Example "feature-412"
- ONE_INTERNAL_VERSION Required, version to be appended to the version inferred from the git branch, example: "1" If the version sit in the branch is 4.12.3 for example, this would append the 1 to make it 4.12.3.1 and apply that to the spec file.
- ONE_OUTPUT_DIRECTORY This is an optional parameter, and specifies where on the build host you would like the Resultant RPMS copied. If not specified they will be placed in /tmp/opennebula-$VERSION.ONE_INTERNAL_VERSION/RPMS

Debugging
---------
The userdata.sh script logs to /tmp/build.log
You can verify that the userdata script is being run by checking /tmp/i_ran (this will also provide the environment) at the time that the script is kicked off.

Limitations
-----------
- Currently only supports Centos7
- See issues section.

