#!/bin/bash -e

#
# Installing Basic System Software
#

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
    local srcpkg_dir=$(tar tf ${srcpkg_tar} | head -n1 | grep -E --only-matching '^([^/]+?/)')
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
    local srcpkg_dir=$(tar tf ${srcpkg_tar} | head -n1 | grep -E --only-matching '^([^/]+?/)')
    tar xf ${srcpkg_tar}
    if [ ! -d "./${srcpkg_dir}" ] ; then
        echo "Unable to identify the root directory for package '${srcpkg_pfx}'; reading root as '${srcpkg_dir}'"
        return 1
    fi
    cd ${srcpkg_dir}
}

function ch08_03 () {
    echo "(jail) man-pages-5.13"
    check_running_in_jail
    extract_source_package man-pages
    make prefix=/usr install || exit 1
    clean_source_package man-pages
}

function ch08_04 () {
    echo "(jail) iana-etc-20210611"
    check_running_in_jail
    extract_source_package iana-etc
    cp services protocols /etc/
    clean_source_package iana-etc
}

function ch08_05 () {
    echo "(jail) glibc-2.34"
    check_running_in_jail
    extract_source_package glibc
    (
        sed -e '/NOTIFY_REMOVED)/s/)/ \&\& data.attr != NULL)/' -i sysdeps/unix/sysv/linux/mq_notify.c
        patch -Np1 -i ../glibc-2.34-fhs-1.patch
        mkdir -pv build
        cd build
        echo "rootsbindir=/usr/sbin" > configparms
        ../configure --prefix=/usr --disable-werror --enable-kernel=3.2 --enable-stack-protector=strong --with-headers=/usr/include libc_cv_slibdir=/usr/lib
        make
        make check || echo '*** WARNING: some glibc test failures occurred'
        touch /etc/ld.so.conf
        sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
        make install
        sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd
        cp -v ../nscd/nscd.conf /etc/nscd.conf
        mkdir -pv /var/cache/nscd
        mkdir -pv /usr/lib/locale
        localedef -i POSIX -f UTF-8 C.UTF-8 2> /dev/null || true
        localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
        localedef -i de_DE -f ISO-8859-1 de_DE
        localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
        localedef -i de_DE -f UTF-8 de_DE.UTF-8
        localedef -i el_GR -f ISO-8859-7 el_GR
        localedef -i en_GB -f ISO-8859-1 en_GB
        localedef -i en_GB -f UTF-8 en_GB.UTF-8
        localedef -i en_HK -f ISO-8859-1 en_HK
        localedef -i en_PH -f ISO-8859-1 en_PH
        localedef -i en_US -f ISO-8859-1 en_US
        localedef -i en_US -f UTF-8 en_US.UTF-8
        localedef -i es_ES -f ISO-8859-15 es_ES@euro
        localedef -i es_MX -f ISO-8859-1 es_MX
        localedef -i fa_IR -f UTF-8 fa_IR
        localedef -i fr_FR -f ISO-8859-1 fr_FR
        localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
        localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
        localedef -i is_IS -f ISO-8859-1 is_IS
        localedef -i is_IS -f UTF-8 is_IS.UTF-8
        localedef -i it_IT -f ISO-8859-1 it_IT
        localedef -i it_IT -f ISO-8859-15 it_IT@euro
        localedef -i it_IT -f UTF-8 it_IT.UTF-8
        localedef -i ja_JP -f EUC-JP ja_JP
        localedef -i ja_JP -f SHIFT_JIS ja_JP.SIJS 2> /dev/null || true
        localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
        localedef -i nl_NL@euro -f ISO-8859-15 nl_NL@euro
        localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
        localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
        localedef -i se_NO -f UTF-8 se_NO.UTF-8
        localedef -i ta_IN -f UTF-8 ta_IN.UTF-8
        localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
        localedef -i zh_CN -f GB18030 zh_CN.GB18030
        localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS
        localedef -i zh_TW -f UTF-8 zh_TW.UTF-8
    ) || exit 1
    # ---
    cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF
    # ---
    tar -xf ../../tzdata2021a.tar.gz
    ZONEINFO=/usr/share/zoneinfo
    mkdir -pv $ZONEINFO/{posix,right}
    for tz in etcetera southamerica northamerica europe africa antarctica  \
            asia australasia backward; do
        zic -L /dev/null   -d $ZONEINFO       ${tz}
        zic -L /dev/null   -d $ZONEINFO/posix ${tz}
        zic -L leapseconds -d $ZONEINFO/right ${tz}
    done
    cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
    zic -d $ZONEINFO -p America/New_York
    unset ZONEINFO
    # ---
    ln -sfv /usr/share/zoneinfo/America/New_York /etc/localtime
    # ---
    cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
    mkdir -pv /etc/ld.so.conf.d
    # ---
    clean_source_package glibc
}

function ch08_06 () {
    echo "(jail) zlib-1.2.11"
    check_running_in_jail
    extract_source_package zlib
    (
        ./configure --prefix=/usr
        make
        make check
        make install
        rm -fv /usr/lib/libz.a
    ) || exit 1
    clean_source_package zlib
}

function ch08_07 () {
    echo "(jail) bzip2-1.0.8"
    check_running_in_jail
    extract_source_package bzip2
    (
        patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
        sed -e 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' -i Makefile
        sed -e "s@(PREFIX)/man@(PREFIX)/share/man@g" -i Makefile
        make -f Makefile-libbz2_so
        make clean
        make
        make PREFIX=/usr install
        cp -av libbz2.so.* /usr/lib/
        ln -sv libbz2.so.1.0.8 /usr/lib/libbz2.so
        cp -v bzip2-shared /usr/bin/bzip2
        for i in /usr/bin/{bzcat,bunzip2} ; do
            ln -sfv bzip2 ${i}
        done
        rm -fv /usr/lib/libbz2.a
    ) || exit 1
    clean_source_package bzip2
}

function ch08_08 () {
    echo "(jail) xz-5.2.5"
    check_running_in_jail
    extract_source_package xz
    (
        ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/xz-5.2.5
        make
        make check
        make install
    ) || exit 1
    clean_source_package xz
}

function ch08_09 () {
    echo "(jail) zstd-1.5.0"
    check_running_in_jail
    extract_source_package zstd
    ( make ; make check ; make prefix=/usr install ; rm -v /usr/lib/libzstd.a ) || exit 1
    clean_source_package zstd
}

function ch08_10 () {
    echo "(jail) file-5.40"
    check_running_in_jail
    extract_source_package file
    ( ./configure --prefix=/usr ; make ; make check ; make install ) || exit 1
    clean_source_package file
}

function ch08_11 () {
    echo "(jail) readline-8.1"
    check_running_in_jail
    extract_source_package readline
    (
        sed -e '/MV.*old/d' -i Makefile.in
        sed -e '/{OLDSUFF}/c:' -i support/shlib-install
        ./configure --prefix=/usr --disable-static --with-curses --docdir=/usr/share/doc/readline-8.1
        make SHLIB_LIBS="-lncursesw"
        make SHLIB_LIBS="-lncursesw" install
    ) || exit 1
    clean_source_package readline
}

function ch08_12 () {
    echo "(jail) m4-1.4.19"
    check_running_in_jail
    extract_source_package m4
    ( ./configure --prefix=/usr ; make ; make check ; make install ) || exit 1
    clean_source_package m4
}

function ch08_13 () {
    echo "(jail) bc-5.0.0"
    check_running_in_jail
    extract_source_package bc
    (
        CC=gcc ./configure --prefix=/usr -G -O3
        make
        make test
        make install
    ) || exit 1
    clean_source_package bc
}

function ch08_14 () {
    echo "(jail) flex-2.6.4"
    check_running_in_jail
    extract_source_package flex
    (
        ./configure --prefix=/usr --docdir=/usr/share/doc/flex-2.6.4 --disable-static
        make
        make check
        make install
        ln -sv flex /usr/bin/lex
    ) || exit 1
    clean_source_package flex
}

function ch08_15 () {
    echo "(jail) tcl-8.6.11"
    check_running_in_jail
    extract_source_package tcl
    tar xf ../tcl8.6.11-html.tar.gz --strip-components=1
    SRCDIR=$(pwd)
    cd unix
    ./configure --prefix=/usr --mandir=/usr/share/man $([ "$(uname -m)" == x86_64 ] && echo --enable-64bit)
    make
    sed -e "s|$SRCDIR/unix|/usr/lib|" \
        -e "s|$SRCDIR|/usr/include|"  \
        -i tclConfig.sh

    sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.2|/usr/lib/tdbc1.1.2|" \
        -e "s|$SRCDIR/pkgs/tdbc1.1.2/generic|/usr/include|"    \
        -e "s|$SRCDIR/pkgs/tdbc1.1.2/library|/usr/lib/tcl8.6|" \
        -e "s|$SRCDIR/pkgs/tdbc1.1.2|/usr/include|"            \
        -i pkgs/tdbc1.1.2/tdbcConfig.sh

    sed -e "s|$SRCDIR/unix/pkgs/itcl4.2.1|/usr/lib/itcl4.2.1|" \
        -e "s|$SRCDIR/pkgs/itcl4.2.1/generic|/usr/include|"    \
        -e "s|$SRCDIR/pkgs/itcl4.2.1|/usr/include|"            \
        -i pkgs/itcl4.2.1/itclConfig.sh
    unset SRCDIR
    make test
    make install
    chmod -v u+w /usr/lib/libtcl8.6.so
    make install-private-headers
    ln -sfv tclsh8.6 /usr/bin/tclsh
    mv /usr/share/man/man3/{Thread,Tcl_Thread}.3
    clean_source_package tcl
}

function ch08_16 () {
    echo "(jail) expect-5.45.4"
    check_running_in_jail
    extract_source_package expect
    (
        ./configure --prefix=/usr --with-tcl=/usr/lib --enable-shared --mandir=/usr/share/man --with-tclinclude=/usr/include
        make
        make test
        make install
        ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib
    ) || exit 1
    clean_source_package expect
}

function ch08_17 () {
    echo "(jail) dejagnu-1.6.3"
    check_running_in_jail
    extract_source_package dejagnu
    (
        mkdir -pv build
        cd build
        ../configure --prefix=/usr
        makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
        makeinfo --plaintext -o doc/dejagnu.txt ../doc/dejagnu.texi
        make install
        install -v -dm755 /usr/share/doc/dejagnu-1.6.3
        install -v -m644 doc/dejagnu.{html,txt} /usr/share/doc/dejagnu-1.6.3/
        make check
    ) || exit 1
    clean_source_package dejagnu
}

function ch08_18 () {
    echo "(jail) binutils-2.37"
    check_running_in_jail
    expect -c "spawn ls" || ( echo 'ERROR: environment not set up for proper PTY operation' ; exit 1 )
    extract_source_package binutils
    (
        patch -Np1 -i ../binutils-2.37-upstream_fix-1.patch
        sed -e '63d' -i etc/texi2pod.pl
        find -name \*.1 -delete
        mkdir -pv build
        cd build
        ../configure --prefix=/usr --enable-gold --enable-ld=default --enable-plugins --enable-shared \
            --disable-werror --enable-64-bit-bfd --with-system-zlib
        make tooldir=/usr
        make -k check
        make tooldir=/usr install -j1
        rm -fv /usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes}.a
    ) || exit 1
    clean_source_package binutils
}

function ch08_19 () {
    echo "(jail) gmp-6.2.1"
    check_running_in_jail
    extract_source_package gmp
    (
        ./configure --prefix=/usr --enable-cxx --disable-static --docdir=/usr/share/doc/gmp-6.2.1
        make
        make html
        make check 2>&1 | tee gmp-check-log
        awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log
        make install
        make install-html
    ) || exit 1
    clean_source_package gmp
}

function ch08_20 () {
    echo "(jail) mpfr-4.1.0"
    check_running_in_jail
    extract_source_package mpfr
    (
        ./configure --prefix=/usr --disable-static --enable-thread-safe --docdir=/usr/share/doc/mpfr-4.1.0
        make
        make html
        make check
        make install
        make install-html
    ) || exit 1
    clean_source_package mpfr
}

function ch08_21 () {
    echo "(jail) mpc-1.2.1"
    check_running_in_jail
    extract_source_package mpc
    (
        ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/mpc-1.2.1
        make
        make html
        make check
        make install
        make install-html
    ) || exit 1
    clean_source_package mpc
}

function ch08_22 () {
    echo "(jail) attr-2.5.1"
    check_running_in_jail
    extract_source_package attr
    (
        ./configure --prefix=/usr --disable-static --sysconfdir=/etc --docdir=/usr/share/doc/attr-2.5.1
        make
        #make check
        make install
    ) || exit 1
    clean_source_package attr
}

function ch08_23 () {
    echo "(jail) acl-2.3.1"
    check_running_in_jail
    extract_source_package acl
    (
        ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/acl-2.3.1
        make
        make install
    ) || exit 1
    clean_source_package acl
}

function ch08_24 () {
    echo "(jail) libcap-2.53"
    check_running_in_jail
    extract_source_package libcap
    (
        sed -e '/install -m.*STA/d' -i libcap/Makefile
        make prefix=/usr lib=lib
        make test
        make prefix=/usr lib=lib install
        chmod -v 755 /usr/lib/lib{cap,psx}.so.2.53
    ) || exit 1
    clean_source_package libcap
}

function ch08_25 () {
    echo "(jail) shadow-4.9"
    check_running_in_jail
    extract_source_package shadow
    sed -i 's/groups$(EXEEXT) //' src/Makefile.in
    find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
    find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
    find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
    sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD SHA512:' \
        -e 's:/var/spool/mail:/var/mail:'                 \
        -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                \
        -i etc/login.defs
    sed -e "224s/rounds/min_rounds/" -i libmisc/salt.c
    touch /usr/bin/passwd
    (
        ./configure --sysconfdir=/etc --with-group-name-max-length=32
        make
        make exec_prefix=/usr install
        make -C man install-man
        mkdir -p /etc/default
        useradd -D --gid 999
    ) || exit 1
    # Configure shadow
    pwconv
    grpconv
    #passwd root
    clean_source_package shadow
}

function ch08_26 () {
    echo "(jail) gcc-11.2.0"
    check_running_in_jail
    extract_source_package gcc
    (
        sed -e '/static.*SIGSTKSZ/d' \
            -e 's/return kAltStackSize/return SIGSTKSZ * 4/' \
            -i libsanitizer/sanitizer_common/sanitizer_posix_libcdep.cpp
        case $(uname -m) in
            x86_64)
                sed -e '/m64=/s/lib64/lib/' \
                    -i.orig gcc/config/i386/t-linux64
                ;;
        esac
        mkdir -pv build
        cd build
        ../configure --prefix=/usr LD=ld --enable-languages=c,c++ --disable-multilib --disable-bootstrap --with-system-zlib
        make
        ulimit -s 32768
        chown -Rv tester .
        su tester -c "PATH=$PATH make -k check"
        ../contrib/test_summary | grep -A7 Summ
        make install
        rm -rf /usr/lib/gcc/$(gcc -dumpmachine)/11.2.0/include-fixed/bits/
        chown -v -R root:root /usr/lib/gcc/*linux-gnu/11.2.0/include{,-fixed}
        ln -svr /usr/bin/cpp /usr/lib
        ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/11.2.0/liblto_plugin.so /usr/lib/bfd-plugins/
        echo 'int main(){}' > dummy.c
        cc dummy.c -v -Wl,--verbose &> dummy.log
        readelf -l a.out | grep ': /lib'
        grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
        grep -B4 '^ /usr/include' dummy.log
        grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
        grep "/lib.*/libc.so.6 " dummy.log
        grep found dummy.log
        mkdir -pv /usr/share/gdb/auto-load/usr/lib
        mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
    ) || exit 1
    clean_source_package gcc
}

function ch08_27 () {
    echo "(jail) pkg-config-0.29.2"
    check_running_in_jail
    extract_source_package pkg-config
    (
        ./configure --prefix=/usr --with-internal-glib --disable-host-tool --docdir=/usr/share/doc/pkg-config-0.29.2
        make
        make check
        make install
    ) || exit 1
    clean_source_package pkg-config
}

function ch08_28 () {
    echo "(jail) ncurses-6.2"
    check_running_in_jail
    extract_source_package ncurses
    (
        ./configure --prefix=/usr --mandir=/usr/share/man --with-shared --without-debug --without-normal --enable-pc-files --enable-widec
        make
        make install
        for lib in ncurses form panel menu ; do
            rm -vf                    /usr/lib/lib${lib}.so
            echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
            ln -sfv ${lib}w.pc        /usr/lib/pkgconfig/${lib}.pc
        done
        rm -vf                     /usr/lib/libcursesw.so
        echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
        ln -sfv libncurses.so      /usr/lib/libcurses.so
        rm -fv /usr/lib/libncurses++w.a
        #mkdir -v       /usr/share/doc/ncurses-6.2
        #cp -v -R doc/* /usr/share/doc/ncurses-6.2
    ) || exit 1
    clean_source_package ncurses
}

function ch08_29 () {
    echo "(jail) sed-4.8"
    check_running_in_jail
    extract_source_package sed
    (
        ./configure --prefix=/usr
        make
        make html
        chown -Rv tester .
        su tester -c "PATH=$PATH make check"
        make install
        install -d -m755 /usr/share/doc/sed-4.8
        install -m644 doc/sed.html /usr/share/doc/sed-4.8
    ) || exit 1
    clean_source_package sed
}

function ch08_30 () {
    echo "(jail) psmisc-23.4"
    check_running_in_jail
    extract_source_package psmisc
    ( ./configure --prefix=/usr ; make ; make install ) || exit 1
    clean_source_package psmisc
}

function ch08_31 () {
    echo "(jail) gettext-0.21"
    check_running_in_jail
    extract_source_package gettext
    (
        ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/gettext-0.21
        make
        make check
        make install
        chmod -v 0755 /usr/lib/preloadable_libintl.so
    ) || exit 1
    clean_source_package gettext
}

function ch08_32 () {
    echo "(jail) bison-3.7.6"
    check_running_in_jail
    extract_source_package bison
    ( ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.7.6 ; make ; make check ; make install ) || exit 1
    clean_source_package bison
}

function ch08_33 () {
    echo "(jail) grep-3.7"
    check_running_in_jail
    extract_source_package grep
    ( ./configure --prefix=/usr ; make ; make check ; make install ) || exit 1
    clean_source_package grep
}

function ch08_34 () {
    echo "(jail) bash-5.1.8"
    check_running_in_jail
    extract_source_package bash
    (
        ./configure --prefix=/usr --docdir=/usr/share/doc/bash-5.1.8 --without-bash-malloc --with-installed-readline
        make
        # skipping tests
        make install
    ) || exit 1
    clean_source_package bash
}

function ch08_35 () {
    echo "(jail) libtool-2.4.6"
    check_running_in_jail
    extract_source_package libtool
    ( ./configure --prefix=/usr ; make ; make install ; rm -fv /usr/lib/libltdl.a ) || exit 1
    clean_source_package libtool
}

function ch08_36 () {
    echo "(jail) gdbm-1.20"
    check_running_in_jail
    extract_source_package gdbm
    (
        ./configure --prefix=/usr --disable-static --enable-libgdbm-compat
        make
        #make check
        make install
    ) || exit 1
    clean_source_package gdbm
}

function ch08_37 () {
    echo "(jail) gperf-3.1"
    check_running_in_jail
    extract_source_package gperf
    (
        ./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.1
        make
        #make -j1 check
        make install
    ) || exit 1
    clean_source_package gperf
}

function ch08_38 () {
    echo "(jail) expat-2.4.1"
    check_running_in_jail
    extract_source_package expat
    (
        ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/expat-2.4.1
        make
        make check
        make install
        #install -v -m644 doc/*.{html,png,css} /usr/share/doc/expat-2.4.1
    ) || exit 1
    clean_source_package expat
}

function ch08_39 () {
    echo "(jail) inetutils-2.1"
    check_running_in_jail
    extract_source_package inetutils
    (
        ./configure --prefix=/usr --bindir=/usr/bin --localstatedir=/var \
            --disable-logger --disable-whois --disable-rcp --disable-rexec --disable-rlogin --disable-rsh --disable-servers
        make
        make check
        make install
        mv -v /usr/{,s}bin/ifconfig
    ) || exit 1
    clean_source_package inetutils
}

function ch08_40 () {
    echo "(jail) less-590"
    check_running_in_jail
    extract_source_package less
    ( ./configure --prefix=/usr --sysconfdir=/etc ; make ; make install ) || exit 1
    clean_source_package less
}

function ch08_41 () {
    echo "(jail) perl-5.34.0"
    check_running_in_jail
    extract_source_package perl
    (
        patch -Np1 -i ../perl-5.34.0-upstream_fixes-1.patch
        export BUILD_ZLIB=False
        export BUILD_BZIP2=0
        sh Configure -des                                           \
                    -Dprefix=/usr                                   \
                    -Dvendorprefix=/usr                             \
                    -Dprivlib=/usr/lib/perl5/5.34/core_perl         \
                    -Darchlib=/usr/lib/perl5/5.34/core_perl         \
                    -Dsitelib=/usr/lib/perl5/5.34/site_perl         \
                    -Dsitearch=/usr/lib/perl5/5.34/site_perl        \
                    -Dvendorlib=/usr/lib/perl5/5.34/vendor_perl     \
                    -Dvendorarch=/usr/lib/perl5/5.34/vendor_perl    \
                    -Dman1dir=/usr/share/man/man1                   \
                    -Dman3dir=/usr/share/man/man3                   \
                    -Dpager="/usr/bin/less -isR"                    \
                    -Duseshrplib                                    \
                    -Dusethreads
        make
        #make test
        make install
        unset BUILD_ZLIB BUILD_BZIP2
    ) || exit 1
    clean_source_package perl
}

function ch08_42 () {
    echo "(jail) XML::Parser-2.46"
    check_running_in_jail
    extract_source_package XML-Parser
    (
        perl Makefile.PL
        make
        #make test
        make install
    ) || exit 1
    clean_source_package XML-Parser
}

function ch08_43 () {
    echo "(jail) intltool-0.51.0"
    check_running_in_jail
    extract_source_package intltool
    (
        sed -i 's:\\\${:\\\$\\{:' intltool-update.in
        ./configure --prefix=/usr
        make
        make check
        make install
        install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
    ) || exit 1
    clean_source_package intltool
}

function ch08_44 () {
    echo "(jail) autoconf-2.71"
    check_running_in_jail
    extract_source_package autoconf
    (
        ./configure --prefix=/usr
        make
        make check TESTSUITEFLAGS=-j2
        make install
    ) || exit 1
    clean_source_package autoconf
}

function ch08_45 () {
    echo "(jail) automake-1.16.4"
    check_running_in_jail
    extract_source_package automake
    (
        ./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.16.4
        make
        make -j4 check
        make install
    ) || exit 1
    clean_source_package automake
}

function ch08_46 () {
    echo "(jail) kmod-29"
    check_running_in_jail
    extract_source_package kmod
    (
        ./configure --prefix=/usr --sysconfdir=/etc --with-xz --with-zstd --with-zlib
        make
        make install
        for target in depmod insmod modinfo modprobe rmmod ; do
            ln -sfv ../bin/kmod /usr/sbin/${target}
        done
        ln -sfv kmod /usr/bin/lsmod
    ) || exit 1
    clean_source_package kmod
}

function ch08_47 () {
    echo "(jail) libelf from elfutils-0.185"
    check_running_in_jail
    extract_source_package elfutils
    (
        ./configure --prefix=/usr --disable-debuginfod --enable-libdebuginfod=dummy
        make
        make check
        make -C libelf install
        install -vm644 config/libelf.pc /usr/lib/pkgconfig
        rm /usr/lib/libelf.a
    ) || exit 1
    clean_source_package elfutils
}

function ch08_48 () {
    echo "(jail) libffi-3.4.2"
    check_running_in_jail
    extract_source_package libffi
    (
        ./configure --prefix=/usr --disable-static --with-gcc-arch=native --disable-exec-static-tramp
        make
        make check
        make install
    ) || exit 1
    clean_source_package libffi
}

function ch08_49 () {
    echo "(jail) openssl-1.1.1l"
    check_running_in_jail
    extract_source_package openssl
    (
        ./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib shared zlib-dynamic
        make
        make test
        sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
        make MANSUFFIX=ssl install
        mv -v /usr/share/doc/openssl /usr/share/doc/openssl-1.1.1l
        #cp -vfr doc/* /usr/share/doc/openssl-1.1.1l
    ) || exit 1
    clean_source_package openssl
}

function ch08_50 () {
    echo "(jail) python-3.9.6"
    check_running_in_jail
    extract_source_package Python
    (
        ./configure --prefix=/usr --enable-shared --with-system-expat --with-system-ffi --with-ensurepip=yes --enable-optimizations
        make install
        #install -v -dm755 /usr/share/doc/python-3.9.6/html
        #tar --strip-components=1 --no-same-owner --no-same-permissions -C /usr/share/doc/python-3.9.6/html -xvf ../python-3.9.6-docs-html.tar.bz2
    ) || exit 1
    clean_source_package Python
}

function ch08_51 () {
    echo "(jail) ninja-1.10.2"
    check_running_in_jail
    extract_source_package ninja
    (
        sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' src/ninja.cc
        python3 configure.py --bootstrap
        ./ninja ninja_test
        ./ninja_test --gtest_filter=-SubprocessTest.SetWithLots
        install -vm755 ninja /usr/bin/
        install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
        install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja
    ) || exit 1
    clean_source_package ninja
}

function ch08_52 () {
    echo "(jail) meson-0.59.1"
    check_running_in_jail
    extract_source_package meson
    (
        python3 setup.py build
        python3 setup.py install --root=dest
        cp -rv dest/* /
        install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
        install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
    ) || exit 1
    clean_source_package meson
}

function ch08_53 () {
    echo "(jail) coreutils-8.32"
    check_running_in_jail
    extract_source_package coreutils
    (
        patch -Np1 -i ../coreutils-8.32-i18n-1.patch
        autoreconf -fiv
        FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr --enable-no-install-program=kill,uptime
        make
        #make NON_ROOT_USERNAME=tester check-root
        #echo "dummy:x:102:tester" >> /etc/group
        #chown -Rv tester .
        #su tester -c "PATH=$PATH make RUN_EXPENSIVE_TESTS=yes check"
        #sed -i '/dummy/d' /etc/group
        make install
        mv -v /usr/bin/chroot /usr/sbin
        mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
        sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
    ) || exit 1
    clean_source_package coreutils
}

function ch08_54 () {
    echo "(jail) check-0.15.2"
    check_running_in_jail
    extract_source_package check
    (
        ./configure --prefix=/usr --disable-static
        make
        make check
        make docdir=/usr/share/doc/check-0.15.2 install
    ) || exit 1
    clean_source_package check
}

function ch08_55 () {
    echo "(jail) diffutils-3.8"
    check_running_in_jail
    extract_source_package diffutils
    ( ./configure --prefix=/usr ; make ; make check ; make install ) || exit 1
    clean_source_package diffutils
}

function ch08_56 () {
    echo "(jail) gawk-5.1.0"
    check_running_in_jail
    extract_source_package gawk
    (
        sed -i 's/extras//' Makefile.in
        ./configure --prefix=/usr
        make
        make check
        make install
        #mkdir -v /usr/share/doc/gawk-5.1.0
        #cp -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/gawk-5.1.0
    ) || exit 1
    clean_source_package gawk
}

function ch08_57 () {
    echo "(jail) findutils-4.8.0"
    check_running_in_jail
    extract_source_package findutils
    (
        ./configure --prefix=/usr --localstatedir=/var/lib/locate
        make
        chown -Rv tester .
        su tester -c "PATH=$PATH make check"
        make install
    ) || exit 1
    clean_source_package findutils
}

function ch08_58 () {
    echo "(jail) groff-1.22.4"
    check_running_in_jail
    extract_source_package groff
    (
        PAGE=letter ./configure --prefix=/usr
        make -j1
        make install
    ) || exit 1
    clean_source_package groff
}

function ch08_59 () {
    echo "(jail) grub-2.06"
    check_running_in_jail
    extract_source_package grub
    (
        ./configure --prefix=/usr --sysconfdir=/etc --disable-efiemu --disable-werror
        make
        make install
        mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions
    ) || exit 1
    clean_source_package grub
}

function ch08_60 () {
    echo "(jail) gzip-1.10"
    check_running_in_jail
    extract_source_package gzip
    ( ./configure --prefix=/usr ; make ; make check ; make install ) || exit 1
    clean_source_package gzip
}

function ch08_61 () {
    echo "(jail) iproute2-5.13.0"
    check_running_in_jail
    extract_source_package iproute2
    (
        sed -i /ARPD/d Makefile
        rm -fv man/man8/arpd.8
        sed -i 's/.m_ipt.o//' tc/Makefile
        make
        make SBINDIR=/usr/sbin install
        #mkdir -v /usr/share/doc/iproute2-5.13.0
        #cp -v COPYING README* /usr/share/doc/iproute2-5.13.0
    ) || exit 1
    clean_source_package iproute2
}

function ch08_62 () {
    echo "(jail) kbd-2.4.0"
    check_running_in_jail
    extract_source_package kbd
    (
        patch -Np1 -i ../kbd-2.4.0-backspace-1.patch
        sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
        sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
        ./configure --prefix=/usr --disable-vlock
        make
        make check
        make install
        #mkdir -v /usr/share/doc/kbd-2.4.0
        #cp -Rv docs/doc/* /usr/share/doc/kbd-2.4.0
    ) || exit 1
    clean_source_package kbd
}

function ch08_63 () {
    echo "(jail) libpipeline-1.5.3"
    check_running_in_jail
    extract_source_package libpipeline
    ( ./configure --prefix=/usr ; make ; make check ; make install ) || exit 1
    clean_source_package libpipeline
}

function ch08_64 () {
    echo "(jail) make-4.3"
    check_running_in_jail
    extract_source_package make
    ( ./configure --prefix=/usr ; make ; make check ; make install ) || exit 1
    clean_source_package make
}

function ch08_65 () {
    echo "(jail) patch-2.7.6"
    check_running_in_jail
    extract_source_package patch
    ( ./configure --prefix=/usr ; make ; make check ; make install ) || exit 1
    clean_source_package patch
}

function ch08_66 () {
    echo "(jail) tar-1.34"
    check_running_in_jail
    extract_source_package tar
    (
        FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr
        make
        make check
        make install
        make -C doc install-html docdir=/usr/share/doc/tar-1.34
    ) || exit 1
    clean_source_package tar
}

function ch08_67 () {
    echo "(jail) texinfo-6.8"
    check_running_in_jail
    extract_source_package texinfo
    (
        ./configure --prefix=/usr
        sed -e 's/__attribute_nonnull__/__nonnull/' \
            -i gnulib/lib/malloc/dynarray-skeleton.c
        make
        make check
        make install
        make TEXMF=/usr/share/texmf install-tex
    ) || exit 1
    clean_source_package texinfo
}

function recreate_info_menu_entries () {
    pushd /usr/share/info
    rm -v dir
    for f in * ; do install-info $f dir 2>/dev/null ; done
    popd
}

function ch08_68 () {
    echo "(jail) vim-8.2.3337"
    check_running_in_jail
    extract_source_package vim
    (
        echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
        ./configure --prefix=/usr
        make
        chown -Rv tester .
        su tester -c "LANG=en_US.UTF-8 make -j1 test" &> vim-test.log
        grep -q 'ALL DONE' vim-test.log
        make install
        ln -sv vim /usr/bin/vi
        for L in /usr/share/man/{,*/}man1/vim.1 ; do
            ln -sv vim.1 $(dirname ${L})/vi.1
        done
        ln -sv ../vim/vim82/doc /usr/share/doc/vim-8.2.3337
    ) || exit 1
    # ---
    # Configure vim
    cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1 

set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF
    # ---
    clean_source_package vim
}

function ch08_69 () {
    echo "(jail) eudev-3.2.10"
    check_running_in_jail
    extract_source_package eudev
    (
        ./configure --prefix=/usr --bindir=/usr/sbin --sysconfdir=/etc --enable-manpages --disable-static
        make
        mkdir -pv /usr/lib/udev/rules.d
        mkdir -pv /etc/udev/rules.d
        make check
        make install
        tar xvf ../udev-lfs-20171102.tar.xz
        make -f udev-lfs-20171102/Makefile.lfs install
    ) || exit 1
    # ---
    udevadm hwdb --update
    # ---
    clean_source_package eudev
}

function ch08_70 () {
    echo "(jail) man-db-2.9.4"
    check_running_in_jail
    extract_source_package man-db
    (
        ./configure --prefix=/usr --docdir=/usr/share/doc/man-db-2.9.4 --sysconfdir=/etc \
            --disable-setuid --enable-cache-owner=bin --with-browser=/usr/bin/lynx \
            --with-vgrind=/usr/bin/vgrind --with-grap=/usr/bin/grap \
            --with-systemdtmpfilesdir= --with-systemdsystemunitdir=
        make
        make check
        make install
    ) || exit 1
    clean_source_package man-db
}

function ch08_71 () {
    echo "(jail) procps-ng-3.3.17"
    check_running_in_jail
    extract_source_package procps-ng
    (
        ./configure --prefix=/usr --docdir=/usr/share/doc/procps-ng-3.3.17 --disable-static --disable-kill
        make
        #make check
        make install
    ) || exit 1
    clean_source_package procps-ng
}

function ch08_72 () {
    echo "(jail) util-linux-2.37.2"
    check_running_in_jail
    extract_source_package util-linux
    (
        ./configure ADJTIME_PATH=/var/lib/hwclock/adjtime \
            --libdir=/usr/lib \
            --docdir=/usr/share/doc/util-linux-2.37.2 \
            --disable-chfn-chsh \
            --disable-login \
            --disable-nologin \
            --disable-su \
            --disable-setpriv \
            --disable-runuser \
            --disable-pylibmount \
            --disable-static \
            --without-python \
            --without-systemd \
            --without-systemdsystemunitdir \
            runstatedir=/run
        make
        #chown -Rv tester .
        #su tester -c "make -k check"
        make install
    ) || exit 1
    clean_source_package util-linux
}

function ch08_73 () {
    echo "(jail) e2fsprogs-1.46.4"
    check_running_in_jail
    extract_source_package e2fsprogs
    (
        mkdir -v build
        cd build
        ../configure --prefix=/usr --sysconfdir=/etc --enable-elf-shlibs \
            --disable-libblkid --disable-libuuid --disable-uuidd --disable-fsck
        make
        #make check
        make install
        rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
        gunzip -v /usr/share/info/libext2fs.info.gz
        install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
    ) || exit 1
    #makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo
    #install -v -m644 doc/com_err.info /usr/share/info
    #install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
    clean_source_package e2fsprogs
}

function ch08_74 () {
    echo "(jail) sysklogd-1.5.1"
    check_running_in_jail
    extract_source_package sysklogd
    (
        sed -i '/Error loading kernel symbols/{n;n;d}' ksym_mod.c
        sed -i 's/union wait/int/' syslogd.c
        make
        make BINDIR=/sbin install
    ) || exit 1
    # ---
    cat > /etc/syslog.conf << "EOF"
# Begin /etc/syslog.conf

auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *

# End /etc/syslog.conf
EOF
    # ---
    clean_source_package sysklogd
}

function ch08_75 () {
    echo "(jail) sysvinit-2.99"
    check_running_in_jail
    extract_source_package sysvinit
    (
        patch -Np1 -i ../sysvinit-2.99-consolidated-1.patch
        make
        make install
    ) || exit 1
    clean_source_package sysvinit
}

function ch08_77 () {
    echo "(jail) stripping debug symbols"
    check_running_in_jail
    save_usrlib="$(cd /usr/lib; ls ld-linux*)
                libc.so.6
                libthread_db.so.1
                libquadmath.so.0.0.0 
                libstdc++.so.6.0.29
                libitm.so.1.0.0 
                libatomic.so.1.2.0" 

    cd /usr/lib

    for LIB in $save_usrlib; do
        objcopy --only-keep-debug $LIB $LIB.dbg
        cp $LIB /tmp/$LIB
        strip --strip-unneeded /tmp/$LIB
        objcopy --add-gnu-debuglink=$LIB.dbg /tmp/$LIB
        install -vm755 /tmp/$LIB /usr/lib
        rm /tmp/$LIB
    done

    online_usrbin="bash find strip"
    online_usrlib="libbfd-2.37.so
                libhistory.so.8.1
                libncursesw.so.6.2
                libm.so.6
                libreadline.so.8.1
                libz.so.1.2.11
                $(cd /usr/lib; find libnss*.so* -type f)"

    for BIN in $online_usrbin; do
        cp /usr/bin/$BIN /tmp/$BIN
        strip --strip-unneeded /tmp/$BIN
        install -vm755 /tmp/$BIN /usr/bin
        rm /tmp/$BIN
    done

    for LIB in $online_usrlib; do
        cp /usr/lib/$LIB /tmp/$LIB
        strip --strip-unneeded /tmp/$LIB
        install -vm755 /tmp/$LIB /usr/lib
        rm /tmp/$LIB
    done

    for i in $(find /usr/lib -type f -name \*.so* ! -name \*dbg) \
            $(find /usr/lib -type f -name \*.a)                 \
            $(find /usr/{bin,sbin,libexec} -type f); do
        case "$online_usrbin $online_usrlib $save_usrlib" in
            *$(basename $i)* ) 
                ;;
            * ) strip --strip-unneeded $i 
                ;;
        esac
    done

    unset BIN LIB save_usrlib online_usrbin online_usrlib
}

function ch08_78 () {
    echo "(jail) cleaning up"
    check_running_in_jail
    rm -rf /tmp/*
    find /usr/lib /usr/libexec -name \*.la -delete
    find /usr -depth -name $(uname -m)-lfs-linux-gnu\* | xargs rm -rf
    userdel -r tester
}
