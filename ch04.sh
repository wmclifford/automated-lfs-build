#!/bin/bash -e

# 4.2 Creating a limited directory layout in LFS filesystem
function ch04_02 () {
    mkdir -pv ${LFS}/{etc,var} ${LFS}/usr/{bin,lib,sbin}
    for i in bin lib sbin ; do
        ln -sv usr/$i ${LFS}/$i
    done
    case $(uname -m) in
        x86_64) mkdir -pv ${LFS}/lib64 ;;
    esac
    mkdir -pv ${LFS}/tools
}

# 4.3 Adding the LFS User
function ch04_03 () {
    create_lfs_group
    create_lfs_user
    # passwd lfs
    chown -v lfs ${LFS}/{usr{,/*},lib,var,etc,bin,sbin,tools}
    case $(uname -m) in
        x86_64) chown -v lfs ${LFS}/lib64 ;;
    esac
    chown -v lfs ${LFS}/sources
    [ ! -e /etc/bash.bashrc ] || mv -v /etc/bash.bashrc /etc/bash.bashrc.NOUSE
}

# 4.4 Setting up the environment
function ch04_04 () {
    # If for some reason the home directory was created and the generic
    # profile file exists, remove it so that it does not get picked up
    # when logged in as the LFS user.
    if [ -f ~/.profile ] ; then
        rm -f ~/.profile
    fi

    cat > ~/.bash_profile << "EOF"
exec env -i HOME=${HOME} TERM=${TERM} PS1='\u:\w \$ ' /bin/bash
EOF

    cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
if [ -h /bin/grep -o -f /bin/busybox ]; then PATH=/usr/local/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
EOF
    #source ~/.bash_profile
}

function create_lfs_group() {
    # Determine which utility to use when creating the group.
    # We prefer groupadd over addgroup. If neither are available,
    # then we should exit with an error immediately.
    local _which_cmd=$(which groupadd)
    if [ -z "${_which_cmd}" ] ; then
        # Not found. Try addgroup.
        _which_cmd=$(which addgroup)
    fi
    if [ -z "${_which_cmd}" ] ; then
        # That's not there either. We cannot continue.
        echo "Unable to locate either groupadd or addgroup; aborting."
        exit 1
    fi
    # Ok, so if we got this far, one of the two commands are available.
    # The call signature is the same for both, so we use the command
    # we located using which.
    ${_which_cmd} lfs
}

function create_lfs_user() {
    # Determine which utility to use when creating the user.
    # We prefer useradd over adduser. If neither are available,
    # then we should exit with an error immediately.
    if [ -n "$(which useradd)" ] ; then
        # Found useradd.
        useradd -s /bin/bash -g lfs -m -k /dev/null lfs
    elif [ -n "$(which adduser)" ] ; then
        # Found adduser.
        # Remember that this command may report an error about creating the
        # home directory, saying that it already exists. The error may safely
        # be ignored. In the off chance that some other error occurred, we
        # do not send the STDERR contents to /dev/null. Also, even if this
        # message is reported, the exit code will still be zero.
        adduser -s /bin/bash -G lfs -k /dev/null -D lfs
    else
        # Did not find either utility; abort the process.
        echo "Unable to locate either useradd or adduser; aborting."
        exit 1
    fi
}
