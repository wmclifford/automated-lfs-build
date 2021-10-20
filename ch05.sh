#!/bin/bash -e

function ch05_00 () {
    echo "I am user $(whoami)"
    umask
    echo "LFS=${LFS}"
    echo "LC_ALL=${LC_ALL}"
    echo "LFS_TGT=${LFS_TGT}"
    echo "PATH=${PATH}"
    echo "CONFIG_SITE=${CONFIG_SITE}"
}

#
# Compiling a Cross-Toolchain
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

function ch05_02 () {
    echo "binutils_pass_1"
    check_running_as_lfs
    extract_source_package binutils
    (
        mkdir -v build
        cd build
        ../configure --prefix=${LFS}/tools --with-sysroot=${LFS} --target=${LFS_TGT} --disable-nls --disable-werror
        make
        make install -j1
    ) || exit 1
    clean_source_package binutils
}

function ch05_03 () {
    echo "gcc_pass_1"
    check_running_as_lfs
    extract_source_package gcc
    (
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
        ../configure                    \
            --target=${LFS_TGT}         \
            --prefix=${LFS}/tools       \
            --with-glibc-version=2.11   \
            --with-sysroot=${LFS}       \
            --with-newlib               \
            --without-headers           \
            --enable-initfini-array     \
            --disable-nls               \
            --disable-shared            \
            --disable-multilib          \
            --disable-decimal-float     \
            --disable-threads           \
            --disable-libatomic         \
            --disable-libgomp           \
            --disable-libquadmath       \
            --disable-libssp            \
            --disable-libvtv            \
            --disable-libstdcxx         \
            --enable-languages=c,c++
        make
        make install
        cd ${LFS}/sources/gcc-11.2.0/
        cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
            `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/install-tools/include/limits.h
    ) || exit 1
    clean_source_package gcc
}

function ch05_04 () {
    echo "linux-5.13.12_api_headers"
    check_running_as_lfs
    extract_source_package linux
    (
        make mrproper
        make headers
        find usr/include -name '.*' -delete
        rm usr/include/Makefile
        cp -rv usr/include ${LFS}/usr
    ) || exit 1
    clean_source_package linux
}

function ch05_05 () {
    echo "glibc-2.34"
    check_running_as_lfs
    extract_source_package glibc
    (
        case $(uname -m) in
            i?86)
                ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
                ;;
            x86_64)
                ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
                ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
                ;;
        esac
        patch -Np1 -i ../glibc-2.34-fhs-1.patch
        mkdir -v build
        cd build
        echo "rootsbindir=/usr/sbin" > configparms
        ../configure                            \
            --prefix=/usr                       \
            --host=${LFS_TGT}                   \
            --build=$(../scripts/config.guess)  \
            --enable-kernel=3.2                 \
            --with-headers=${LFS}/usr/include   \
            libc_cv_slibdir=/usr/lib
        make
        make DESTDIR=${LFS} install
        sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd
        echo 'int main(){}' > dummy.c
        ${LFS_TGT}-gcc dummy.c
        readelf -l a.out | grep '/ld-linux'
        ${LFS}/tools/libexec/gcc/${LFS_TGT}/11.2.0/install-tools/mkheaders
    ) || exit 1
    clean_source_package glibc
}

function ch05_06 () {
    echo "libstdc++_from_gcc-11.2.0, pass 1"
    check_running_as_lfs
    extract_source_package gcc
    (
        mkdir -v build
        cd build
        ../libstdc++-v3/configure                                           \
            --host=${LFS_TGT}                                               \
            --build=$(../config.guess)                                      \
            --prefix=/usr                                                   \
            --disable-multilib                                              \
            --disable-nls                                                   \
            --disable-libstdcxx-pch                                         \
            --with-gxx-include-dir=/tools/${LFS_TGT}/include/c++/11.2.0
        make
        make DESTDIR=${LFS} install
    ) || exit 1
    clean_source_package gcc
}
