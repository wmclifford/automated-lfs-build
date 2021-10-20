#!/bin/bash
# Simple script to check version numbers of critical development tools
export LC_ALL=C

function die() {
    echo "$@"
    exit 1
}

function version_greater_equal() {
    printf '%s\n%s\n' "$2" "$1" | sort --check=quiet --version-sort
}

version_greater_equal $(bash --version | head -n1 | cut -d' ' -f4) 3.2 || die 'need bash>=3.2'

# /bin/sh should be a symlink to bash
MYSH=$(readlink -f /bin/sh)
echo "/bin/sh -> ${MYSH}"
echo ${MYSH} | grep -q bash || die '/bin/sh does not point to bash'
unset MYSH

version_greater_equal $(ld --version | head -n1 | cut -d' ' -f3-) 2.25 || die 'need binutils>=2.25,<=2.37'
version_greater_equal $(bison --version | head -n1 | cut -d' ' -f4) 2.7 || die 'need bison>=2.7'
