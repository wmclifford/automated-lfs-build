#!/bin/bash -e

#
# Cross-Compiling Temporary Tools
# All functions here should be executed as the `lfs` user
#

function check_running_as_lfs () {
    if [ "$(whoami)" == "lfs" ] ; then
        return 0
    fi
    echo '*** ERROR: this section is expecting to be run as the "lfs" user; aborting'
    exit 1
}

function clean_source_package () {
    local srcpkg_pfx=${1}
    cd ${LFS}/sources
    local srcpkg_tar=${srcpkg_pfx}-*.tar.*
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
    cd ${LFS}/sources
    local srcpkg_tar=${srcpkg_pfx}-*.tar.*
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

function ch06_02 () {
    echo "m4-1.4.19"
    check_running_as_lfs
    extract_source_package m4
    (
        ./configure --prefix=/usr --host=${LFS_TGT} --build=$(build-aux/config.guess)
        make
        make DESTDIR=${LFS} install
    ) || exit 1
    clean_source_package m4
}

function ch06_03 () {
    echo "ncurses-6.2"
    check_running_as_lfs
    extract_source_package ncurses
    sed -e 's/mawk//' -i configure
    mkdir build
    pushd build
    (
        ../configure
        make -C include
        make -C progs tic
    ) || exit 1
    popd
    (
        ./configure --prefix=/usr           \
            --host=${LFS_TGT}               \
            --build=$(./config.guess)       \
            --mandir=/usr/share/man         \
            --with-manpage-format=normal    \
            --with-shared                   \
            --without-debug                 \
            --without-ada                   \
            --without-normal                \
            --enable-widec
        make
        make DESTDIR=${LFS} TIC_PATH=$(pwd)/build/progs/tic install
        echo "INPUT(-lncursesw)" > ${LFS}/usr/lib/libncurses.so
    ) || exit 1
    clean_source_package ncurses
}

function ch06_04 () {
    echo "bash-5.1.8"
    check_running_as_lfs
    extract_source_package bash
    (
        ./configure --prefix=/usr --build=$(support/config.guess) --host=${LFS_TGT} --without-bash-malloc
        make
        make DESTDIR=${LFS} install
        ln -sv bash ${LFS}/bin/sh
    ) || exit 1
    clean_source_package bash
}

function ch06_05 () {
    echo "coreutils-8.32"
    check_running_as_lfs
    extract_source_package coreutils
    (
        ./configure --prefix=/usr --host=${LFS_TGT} --build=$(build-aux/config.guess) \
            --enable-install-program=hostname \
            --enable-no-install-program=kill,uptime
        make
        make DESTDIR=${LFS} install
        mv -v ${LFS}/usr/bin/chroot ${LFS}/usr/sbin/
        mkdir -pv ${LFS}/usr/share/man/man8
        mv -v ${LFS}/usr/share/man/man1/chroot.1 ${LFS}/usr/share/man/man8/chroot.8
        sed -e 's/"1"/"8"/' -i ${LFS}/usr/share/man/man8/chroot.8
    ) || exit 1
    clean_source_package coreutils
}

function ch06_06 () {
    echo "diffutils-3.8"
    check_running_as_lfs
    extract_source_package diffutils
    ( ./configure --prefix=/usr --host=${LFS_TGT} ; make ; make DESTDIR=${LFS} install ) || exit 1
    clean_source_package diffutils
}

function ch06_07 () {
    echo "file-5.40"
    check_running_as_lfs
    extract_source_package file
    mkdir build
    (
        pushd build
        ../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib
        make
        popd
        ./configure --prefix=/usr --host=${LFS_TGT} --build=$(./config.guess)
        make FILE_COMPILE=$(pwd)/build/src/file
        make DESTDIR=${LFS} install
    ) || exit 1
    clean_source_package file
}

function ch06_08 () {
    echo "findutils-4.8.0"
    check_running_as_lfs
    extract_source_package findutils
    (
        ./configure --prefix=/usr --localstatedir=/var/lib/locate --host=${LFS_TGT} --build=$(build-aux/config.guess)
        make
        make DESTDIR=${LFS} install
    ) || exit 1
    clean_source_package findutils
}

function ch06_09 () {
    echo "gawk-5.1.0"
    check_running_as_lfs
    extract_source_package gawk
    (
        sed -e 's/extras//' -i Makefile.in
        ./configure --prefix=/usr --host=${LFS_TGT} --build=$(./config.guess)
        make
        make DESTDIR=${LFS} install
    ) || exit 1
    clean_source_package gawk
}

function ch06_10 () {
    echo "grep-3.7"
    check_running_as_lfs
    extract_source_package grep
    (
        ./configure --prefix=/usr --host=${LFS_TGT}
        make
        make DESTDIR=${LFS} install
    ) || exit 1
    clean_source_package grep
}

function ch06_11 () {
    echo "gzip-1.10"
    check_running_as_lfs
    extract_source_package gzip
    (
        ./configure --prefix=/usr --host=${LFS_TGT}
        make
        make DESTDIR=${LFS} install
    ) || exit 1
    clean_source_package gzip
}

function ch06_12 () {
    echo "make-4.3"
    check_running_as_lfs
    extract_source_package make
    (
        ./configure --prefix=/usr --host=${LFS_TGT} --build=$(build-aux/config.guess) --without-guile
        make
        make DESTDIR=${LFS} install
    ) || exit 1
    clean_source_package make
}

function ch06_13 () {
    echo "patch-2.7.6"
    check_running_as_lfs
    extract_source_package patch
    (
        ./configure --prefix=/usr --host=${LFS_TGT} --build=$(build-aux/config.guess)
        make
        make DESTDIR=${LFS} install
    ) || exit 1
    clean_source_package patch
}

function ch06_14 () {
    echo "sed-4.8"
    check_running_as_lfs
    extract_source_package sed
    (
        ./configure --prefix=/usr --host=${LFS_TGT}
        make
        make DESTDIR=${LFS} install
    ) || exit 1
    clean_source_package sed
}

function ch06_15 () {
    echo "tar-1.34"
    check_running_as_lfs
    extract_source_package tar
    (
        ./configure --prefix=/usr --host=${LFS_TGT} --build=$(build-aux/config.guess)
        make
        make DESTDIR=${LFS} install
    ) || exit 1
    clean_source_package tar
}

function ch06_16 () {
    echo "xz-5.2.5"
    check_running_as_lfs
    extract_source_package xz
    (
        ./configure --prefix=/usr --host=${LFS_TGT} --build=$(build-aux/config.guess) \
            --disable-static \
            --docdir=/usr/share/doc/xz-5.2.5
        make
        make DESTDIR=${LFS} install
    ) || exit 1
    clean_source_package xz
}

function ch06_17 () {
    echo "binutils-2.37 - pass 2"
    check_running_as_lfs
    extract_source_package binutils
    mkdir -v build
    cd build
    (
        ../configure                    \
            --prefix=/usr               \
            --build=$(../config.guess)  \
            --host=${LFS_TGT}           \
            --disable-nls               \
            --enable-shared             \
            --disable-werror            \
            --enable-64-bit-bfd
        make
        make DESTDIR=${LFS} install -j1
        install -vm755 libctf/.libs/libctf.so.0.0.0 ${LFS}/usr/lib
    ) || exit 1
    clean_source_package binutils
}

function ch06_18 () {
    echo "gcc-11.2.0 - pass 2"
    check_running_as_lfs
    extract_source_package gcc
    (
        set -e
        mkdir -pv mpfr && tar xf ../mpfr-4.1.0.tar.xz -C mpfr --strip-components=1
        mkdir -pv gmp && tar xf ../gmp-6.2.1.tar.xz -C gmp --strip-components=1
        mkdir -pv mpc && tar xf ../mpc-1.2.1.tar.gz -C mpc --strip-components=1
        case $(uname -m) in
            x86_64)
                sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
                ;;
        esac
        mkdir -v build
        cd build
        mkdir -pv ${LFS_TGT}/libgcc
        ln -s ../../../libgcc/gthr-posix.h ${LFS_TGT}/libgcc/gthr-default.h
        ../configure                        \
            --prefix=/usr                   \
            --build=$(../config.guess)      \
            --host=${LFS_TGT}               \
            CC_FOR_TARGET=${LFS_TGT}-gcc    \
            --with-build-sysroot=${LFS}     \
            --enable-initfini-array         \
            --disable-nls                   \
            --disable-multilib              \
            --disable-decimal-float         \
            --disable-libatomic             \
            --disable-libgomp               \
            --disable-libquadmath           \
            --disable-libssp                \
            --disable-libvtv                \
            --disable-libstdcxx             \
            --enable-language=c,c++
        make
        make DESTDIR=${LFS} install || ( echo 'make install failed!' ; exit 1 )
        ln -sfv gcc ${LFS}/usr/bin/cc
    ) || exit 1
    clean_source_package gcc
}
