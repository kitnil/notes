Backporting
===========

Install Debian packaging tools

    sudo apt-get install packaging-dev debian-keyring devscripts equivs
	
Find which version is available in the debian archive

	rmadison mame --architecture amd64
	
Download the .dsc file from the sid release

    dget -x http://ftp.de.debian.org/debian/pool/non-free/m/mame/mame_0.148-1.dsc
	
Find and Install missing build dependencies as found in debian/control

    cd mame-0.14
	sudo mk-build-deps --install --remove
	
Build a package properly , without GPG signing the package

    dpkg-buildpackage -us -uc
	
Install and enjoy !

    sudo dpkg -i ../mame_0.148-1_amd64.deb

Articles
========

torkve
------

[Стать мэинтейнером Debian/Ubuntu](https://habrahabr.ru/users/torkve/topics/page3/)
