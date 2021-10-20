#!/bin/bash -e

#
# Entering Chroot and Building Additional Temporary Tools
#

function ch07_00 () {
    check_running_in_jail
    echo "I am user $(whoami)"
    umask
    echo "LFS=${LFS}"
    echo "LC_ALL=${LC_ALL}"
    echo "LFS_TGT=${LFS_TGT}"
    echo "PATH=${PATH}"
    echo "CONFIG_SITE=${CONFIG_SITE}"
    ls -l /
}

function check_running_in_jail () {
    if [ ! -f /LFS_SYSTEM_ROOT ] ; then
        echo '*** ERROR: this section is expecting to be run inside the chroot jail; aborting'
        exit 1
    fi
}

function clean_source_package () {
    local srcpkg_pfx=${1}
    local srcpkg_class=${2:-}
    cd /sources
    local srcpkg_tar=${srcpkg_pfx}*${srcpkg_class}.tar.*
    if [ -z "${srcpkg_tar}" ] ; then
        echo "Unable to locate tar archive for package '${srcpkg_pfx}'"
        return 1
    fi
    local srcpkg_dir=$(tar tf ${srcpkg_tar} | head -n1 | grep -E --only-matching '^(.*?/)')
    if [ -d "./${srcpkg_dir}" ] ; then
        rm -rf ./${srcpkg_dir}
    fi
}

function extract_source_package () {
    local srcpkg_pfx=${1}
    local srcpkg_class=${2:-}
    cd /sources
    local srcpkg_tar=${srcpkg_pfx}*${srcpkg_class}.tar.*
    if [ -z "${srcpkg_tar}" ] ; then
        echo "Unable to locate tar archive for package '${srcpkg_pfx}'"
        return 1
    fi
    local srcpkg_dir=$(tar tf ${srcpkg_tar} | head -n1 | grep -E --only-matching '^(.*?/)')
    tar xf ${srcpkg_tar}
    if [ ! -d "./${srcpkg_dir}" ] ; then
        echo "Unable to identify the root directory for package '${srcpkg_pfx}'; reading root as '${srcpkg_dir}'"
        return 1
    fi
    cd ${srcpkg_dir}
}

function ch07_02 () {
    echo "changing ownership"
    chown -R root:root ${LFS}/{usr,lib,var,etc,bin,sbin,tools}
    case $(uname -m) in
        x86_64)
            chown -R root:root ${LFS}/lib64
            ;;
    esac
}

function ch07_03 () {
    echo "preparing virtual kernel file systems"
    mkdir -pv ${LFS}/{dev,proc,sys,run}
    mknod -m 600 ${LFS}/dev/console c 5 1
    mknod -m 666 ${LFS}/dev/null c 1 3
}

function ch07_05 () {
    # Directory tree based on FHS (https://refspecs.linuxfoundation.org/fhs.shtml)
    echo "(jail) creating directories"
    check_running_in_jail
    mkdir -pv /{boot,home,mnt,opt,srv}
    mkdir -pv /etc/{opt,sysconfig}
    mkdir -pv /lib/firmware
    mkdir -pv /media/{floppy,cdrom}
    mkdir -pv /usr/{,local/}{include,src}
    mkdir -pv /usr/local/{bin,lib,sbin}
    mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
    mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
    mkdir -pv /usr/{,local/}share/man/man{1..8}
    mkdir -pv /var/{cache,local,log,mail,opt,spool}
    mkdir -pv /var/lib/{color,misc,locate}
    ln -sfv /run /var/run
    ln -sfv /run/lock /var/lock
    install -dv -m 0750 /root
    install -dv -m 1777 /tmp /var/tmp
}

function ch07_06 () {
    echo "(jail) creating essential files and symlinks"
    check_running_in_jail
    # --
    ln -sv /proc/self/mounts /etc/mtab
    # --
    cat > /etc/hosts <<EOF
127.0.0.1   localhost   $(hostname)
::1         localhost
EOF
    # --
    cat > /etc/passwd <<"EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF
    # --
    cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
wheel:x:97:
nogroup:x:99:
users:x:999:
EOF
    # --
    echo "tester:x:101:101::/home/tester:/bin/bash" >> /etc/passwd
    echo "tester:x:101:" >> /etc/group
    install -o tester -d /home/tester
    # --
    touch /var/log/{btmp,lastlog,faillog,wtmp}
    chgrp -v utmp /var/log/lastlog
    chmod -v 664  /var/log/lastlog
    chmod -v 600  /var/log/btmp
}

function ch07_07 () {
    echo "(jail) libstdc++ from gcc-11.2.0, pass 2"
    check_running_in_jail
    extract_source_package gcc
    ln -s gthr-posix.h libgcc/gthr-default.h
    mkdir -v build
    cd build
    (
        ../libstdc++-v3/configure               \
            CXXFLAGS="-g -O2 -D_GNU_SOURCE"     \
            --prefix=/usr                       \
            --disable-multilib                  \
            --disable-nls                       \
            --host=$(uname -m)-lfs-linux-gnu    \
            --disable-libstdcxx-pch
        make
        make install
    ) || exit 1
    clean_source_package gcc
}

function ch07_08 () {
    echo "(jail) gettext-0.21"
    check_running_in_jail
    extract_source_package gettext
    (
        ./configure --disable-shared
        make
        cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
    ) || exit 1
    clean_source_package gettext
}

function ch07_09 () {
    echo "(jail) bison-3.7.6"
    check_running_in_jail
    extract_source_package bison
    (
        ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.7.6 ;
        make ;
        make install
    ) || exit 1
    clean_source_package bison
}

function ch07_10 () {
    echo "(jail) perl-5.34.0"
    check_running_in_jail
    extract_source_package perl
    (
        sh Configure -des                                  \
            -Dprefix=/usr                                  \
            -Dvendorprefix=/usr                            \
            -Dprivlib=/usr/lib/perl5/5.34/core_perl        \
            -Darchlib=/usr/lib/perl5/5.34/core_perl        \
            -Dsitelib=/usr/lib/perl5/5.34/site_perl        \
            -Dsitearch=/usr/lib/perl5/5.34/site_perl       \
            -Dvendorlib=/usr/lib/perl5/5.34/vendor_perl    \
            -Dvendorarch=/usr/lib/perl5/5.34/vendor_perl
        make
        make install
    ) || exit 1
    clean_source_package perl
}

function ch07_11 () {
    echo "(jail) python-3.9.6"
    check_running_in_jail
    extract_source_package Python
    (
        ./configure --prefix=/usr --enable-shared --without-ensurepip
        ### ============================================================================================
        ### Some Python 3 modules can't be built now because the dependencies are not installed yet.
        ### The building system still attempts to build them however, so the compilation of some files
        ### will fail and the compiler message may seem to indicate “fatal error”. The message should
        ### be ignored. Just make sure the toplevel make command has not failed. The optional modules
        ### are not needed now and they will be built in Chapter 8.
        ### ============================================================================================
        make
        make install
    ) || exit 1
    clean_source_package Python
}

function ch07_12 () {
    echo "(jail) texinfo-6.8"
    check_running_in_jail
    extract_source_package texinfo
    (
        sed -e 's/__attribute_nonnull__/__nonnull/' -i gnulib/lib/malloc/dynarray-skeleton.c
        ./configure --prefix=/usr
        make
        make install
    ) || exit 1
    clean_source_package texinfo
}

function ch07_13 () {
    echo "(jail) util-linux-2.37.2"
    check_running_in_jail
    extract_source_package util-linux
    (
        mkdir -pv /var/lib/hwclock
        ./configure ADJTIME_PATH=/var/lib/hwclock/adjtime   \
            --libdir=/usr/lib                               \
            --docdir=/usr/share/doc/util-linux-2.37.2       \
            --disable-chfn-chsh                             \
            --disable-login                                 \
            --disable-nologin                               \
            --disable-su                                    \
            --disable-setpriv                               \
            --disable-runuser                               \
            --disable-pylibmount                            \
            --disable-static                                \
            --without-python                                \
            runstatedir=/run
        make
        make install
    ) || exit 1
    clean_source_package util-linux
}

function ch07_14 () {
    echo "(jail) cleaning up and saving the temporary system"
    check_running_in_jail
    rm -rf /usr/share/{info,man,doc}/*
    find /usr/{lib,libexec} -name \*.la -delete
    rm -rf /tools
}

# function enter_chroot_jail () {
#     chroot "${LFS}" /usr/bin/env -i                                                     \
#         HOME=/root TERM="${TERM}" PS1='(lfs chroot) \u:\w \$ ' PATH=/usr/bin:/usr/sbin  \
#         /bin/bash --login +h
# }
