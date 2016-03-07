#!/bin/bash

SOURCE=/opt/git			# Where the git sources are
DEST=/usr/local			# Where to install the binaries
BRANCHPRE=v			# Git branches are vVERSION eg v2.7.2
PROGNAME=$(basename $0)		# Name of this script
GITURL="http://git-scm.com/"	# URL of git sources
GITHTML=/tmp/$PROGNAME\_$$.html # tmp file to store git page HTML
PUP=/usr/share/gocode/bin/pup	# pup - used to parse HTML
LOGFILE=/tmp/$PROGNAME\_$$.log  # Where we log

touch $LOGFILE

# Download the git page
function dl_page() {
	$(wget --quiet -O $GITHTML $GITURL)
	STATUS=$?
}

# Get the version on the downloaded page
function get_dl_version() {
	GITHTML=/tmp/make-git_32519.html
	VERSION=$($PUP 'span[class=version]' < $GITHTML | grep "[0-9.]\+" | sed 's/ //g')
}

# Get the version of the currently installed git
function current_version() {
	CURRENT_VERSION=$(git --version | sed 's/^.*version //')
	STATUS=$?
}

# Pull from the git repo & checkout the passed branch
function get_git() {
	bran=$1
	cd $SOURCE
	if git pull > $LOGFILE 2>&1; then
		git checkout $bran > $LOGFILE 2>&1
	fi
	STATUS=$?
}

# Make & install git
function make_git() {
	cd $SOURCE
	sudo make prefix=$DEST install > $LOGFILE 2>&1
}

# Output an error messgae
function err_msg() {
	msg=$1
	if [ ! -z "$2" ];then
		msg="$msg: $2"
	fi
	echo $msg
}

if [ -z "$1" ]; then
	get_dl_version
else
	VERSION=$1
fi

BRANCH=$BRANCHPRE$VERSION
current_version

if [ $CURRENT_VERSION = $VERSION ]; then
	echo "Installed version is up to date ( $CURRENT_VERSION )."
	exit
fi
OLD_VERSION=$CURRENT_VERISON

# Download git front page to get current version number
dl_page
if [ $STATUS -ne 0 -o ! -s $GITHTML ]; then
	echo Failed to download: $GITURL: $STATUS
	exit $STATUS
fi

# Get the latest changes
get_git $BRANCH
if [ $STATUS -ne 0 ]; then
	echo Failed to update git: $STATUS
	exit $STATUS
fi

# Make it
make_git
STATUS=1
if [ $STATUS -eq 0 ]; then
	echo Updated git from $OLD_VERSION to $VERSION
else
	err_msg "Git update: FAILED (see $LOGFILE)" $STATUS
	exit $STATUS
fi
