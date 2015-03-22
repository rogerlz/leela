#!/bin/sh

set -e

srcroot=${srcroot:-$(dirname $(readlink -f "$0"))}

. "$srcroot/bootstrap-lib.sh"

# fixing bug https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=732255
deb_add_repo wheezy "deb http://http.debian.net/debian wheezy main"
deb_add_repo wheezy-security "deb http://security.debian.org/ wheezy/updates main"
# endfix

deb_add_repo wheezy-backports "deb http://http.debian.net/debian wheezy-backports main"

deb_install apt-utils adduser wget cmake git devscripts pkg-config

adduser --shell /bin/sh --disabled-password --home /home/leela --system leela
