#!/bin/bash

declare -r gitbin=/usr/local/bin/git                 # Location of the git binary
declare -r git="sudo $gitbin"                        # Command used to run git.
                                                     # (sudo is only required if you don't
                                                     # have permissions to write to $source)
declare -r make="sudo make"                          # Command used to run make. Same
                                                     # rules for sudo as for git.
declare -r source=/opt/git                           # Where the git sources are
declare -r dest=/usr/local                           # Where to install the binaries
declare -r tagprefix=v                               # Tag prefix. Git tags are:
                                                     #   v$VERSION eg v2.7.2
declare -r progname=$(basename $0 | sed 's/\.sh$//') # Name of this script
declare -r giturl="https://git-scm.com/"             # URL of git page
declare -r githtml="/tmp/$progname$$.html"           # tmp file to store git page HTML
declare -r cpgithtml="/tmp/cp$progname$$.html"       # copy of tmp file to store git page HTML
declare -r gitversionclass='class="version"'         # HTML selector to find the version
declare -r remotename=origin                         # Name of the git repository. Can be
                                                     # a URL: https://github.com/git/git.git
declare -r logfile="/tmp/$progname_$$.log"           # Where we log to
declare installed_version=""                         # Which version is currently installed

touch $logfile

# May want to install a version which isn't the current version, so allow a
# version number be passed.

if [ ! -z "$1" ]; then
    declare -r get_version=$1
fi

# Check the passed version is valid
# Valid versions are like 1.0 1.0.1 1.0.1.0
# Passed variable:
#     $1 - version to check.
function valid_version() {
    passed=$1
    if [ -z "$passed" ]; then
        return 1
    fi
    version=$(echo $passed | egrep "^[0-9]+\.[0-9]+(.[0-9]+){0,2}$")
    if [ "$version" = "$passed" ]; then
        return 0
    fi
    return 1
}

# Download the git page - used to find latest version
# Requires:
#     $giturl  - URL of the Git website.
#     $githtml - tmp file to write the HTML of the site to which is then parsed.
# Sets the variable:
#     $status - return status of the download
function dl_page() {
    wget --quiet -O $githtml $giturl >> $logfile 2>&1
    status=$?
    # If the download was successful but has a zero sized file, it actually failed.
    if [ ${status} -eq 0 -a ! -s $githtml ]; then
        status=1
    elif ! trim_linefeeds $githtml $cpgithtml
    then
        status=1
    fi
    return $status
}

function trim_linefeeds() {
    src=$1
    dst=$2
    tr -d '\r\n' < $src > $dst
    return $?
}

function get_current_verison() {
    if sed "s/^.*$gitversionclass> \+\([0-9]\+\.[0-9]\+\(.[0-9]\+\)\).*$/\1/" $githtml;
    then
        return 0
    fi
    return 1
}

# Get the version on the downloaded page
# Requires:
#     $pup      - path to pup HTML parser
#     $githtml  - path to HTML of the Git website
#     $gitclass - HTML selector to get the version from the page
# Sets:
#     $version  - Version of Git found on the page
function get_dl_version() {
    version="$($pup $gitclass < $githtml | grep "[0-9.]\+" | sed 's/ //g')"
    echo $version
    return $(valid_version $version)
}

# Checks a passed tag exists in the repo.
#
function check_tag_exists() {
    tag=$1
    cd $source
    retVal=$($git ls-remote $remotename $tag 2>> $logfile)
    if [ ! -z "$retVal" ]; then
        return 0
    fi
    return 1
}

# Get the version of the currently installed git
# Sets:
#     $installed_version - installed version of Git
function installed_version() {
    if installed_version=$($git --version | sed 's/^.*version //')
    then
        echo $installed_version
        return 0
    fi
    return $?
}

# Pull from the git repo & checkout the passed tag
function get_git() {
    tag=$1
    cd $source
    $git checkout master >> $logfile 2>&1
    if $git pull >> $logfile 2>&1; then
        $git checkout $tag >> $logfile 2>&1
    fi
    return $?
}

# Make & install git
function make_git() {
    cd $source
    $make clean >> $logfile 2>&1
    $make prefix=$dest install >> $logfile 2>&1
    return $?
}

# Output an error message
# Passed arguments:
#     $1 - message to output
#     $2 - status code to output (if any)
function err_msg() {
    msg=$1
    if [ ! -z "$2" ];then
        msg="$msg: $2"
    fi
    echo $msg
}

# If a version wasn't passed need to download git front page to get current
# version number

if [ -z "$get_version" ]; then
    if ! dl_page
    then
        err_msg "Failed to download Git front page: $githtml"
        exit 1
    fi
    cp $cpgithtml $githtml
    if current=$(get_current_verison)
    then
        version=$current
    fi
    #date=$(get_current_date)
else
    version=$get_version
fi

# Check we've got a valid version number
if ! valid_version $version
then
    err_msg "Invalid version number: $version"
    exit 1
fi
installed_version=$(installed_version)
if [ $installed_version = $version ]; then
    echo "Installed version is up to date ( $version )."
    exit
fi
old_version=$installed_version
tag=$tagprefix$version

if ! check_tag_exists $tag
then
    err_msg "No such tag: $tag"
    exit 1
fi

# Get the latest changes
if ! get_git $tag
then
    err_msg "Failed to get Git repo"
    exit 1
fi

# Make it
if make_git
then
    echo "Updated git from $old_version to $version" # $date"
else
    err_msg "Git update: FAILED (see $logfile)"
    exit 1
fi
