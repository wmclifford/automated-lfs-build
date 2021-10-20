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
    groupadd lfs
    useradd -s /bin/bash -g lfs -m -k /dev/null lfs
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
