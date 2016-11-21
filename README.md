# Downloads & Makes Latest Version of Git

The Linux distro I use on my laptop, [Fedora](https://getfedora.org/), is significantly behind the current version of Git (2.7.4 versus 2.10.2). To solve this, I installed the current version into /usr/local but then wanted to automate the process to update whenever there's a new version so hence this script.

It checks the Git website & if the installed version is different from the one on the website, pulls, makes & installs that version.

Prerequisites:
	- git needs to be already installed
	- everything necessary to build Git:
		- make
		- c compiler
		etc - see [Git INSTALL](https://github.com/git/git/blob/master/INSTALL) for details.
