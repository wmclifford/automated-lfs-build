#!/bin/bash

optChapter=
optJail=
optMount=
optSection=
optUser=root

while getopts JLMUc:s:u: shortOpt ; do
    case $shortOpt in
        J)
            optJail=yes
            ;;
        L)
            optMount=list
            ;;
        M)
            optMount=up
            ;;
        U)
            optMount=down
            ;;
        c)
            optChapter=$(sed -r -e 's/^0+//' <<<${OPTARG})
            optChapter=$(printf "%02d" "${optChapter}")
            ;;
        s)
            optSection=$(sed -r -e 's/^0+//' <<<${OPTARG})
            optSection=$(printf "%02d" "${optSection}")
            ;;
        u)
            optUser=$(echo "$OPTARG" | grep -E --only-matching '\b\w+\b')
            ;;
        ?)
            echo "Usage: lfs-run.sh [-c value] [-s value] [-u value]"
            exit 2
            ;;
    esac
done

function is_mounted () {
    local mntpt=${1:-not_provided}
    if [ "${mntpt}" == "not_provided" ] ; then
        return 0
    fi
    mount | grep -Eq "\\s${mntpt}\\s"
}

function mounts_off () {
    for mp in ${LFS}/{run,sys,proc,dev/pts,dev,lfs} ; do
        if is_mounted ${mp} ; then
            umount ${mp}
        fi
    done
}

function mounts_on () {
    if ! is_mounted ${LFS}/lfs ; then
        mkdir -pv ${LFS}/lfs
        mount -v --bind /lfs ${LFS}/lfs
    fi
    if ! is_mounted ${LFS}/dev ; then
        mkdir -pv ${LFS}/dev
        mount -v --bind /dev ${LFS}/dev
    fi
    if ! is_mounted ${LFS}/dev/pts ; then
        mkdir -pv ${LFS}/dev/pts
        mount -v --bind /dev/pts ${LFS}/dev/pts
    fi
    if ! is_mounted ${LFS}/proc ; then
        mkdir -pv ${LFS}/proc
        mount -vt proc proc ${LFS}/proc
    fi
    if ! is_mounted ${LFS}/sys ; then
        mkdir -pv ${LFS}/sys
        mount -vt sysfs sysfs ${LFS}/sys
    fi
    if ! is_mounted ${LFS}/run ; then
        mkdir -pv ${LFS}/run
        mount -vt tmpfs tmpfs ${LFS}/run
    fi
    if [ -h ${LFS}/dev/shm ] ; then
        mkdir -pv ${LFS}/$(readlink ${LFS}/dev/shm)
    fi
}

# Drop mounts
if [ "z${optMount}" == "zdown" ] ; then
    mounts_off
    exit 0
fi

# List mounts
if [ "z${optMount}" == "zlist" ] ; then
    mount | grep ${LFS}/
    exit 0
fi

# Add mounts
if [ "z${optMount}" == "zup" ] ; then
    mounts_on
    exit 0
fi

# Execute a section of the LFS book
echo "=== Chapter ${optChapter}, section ${optSection}, as user ${optUser} ==="

if [ "z${optJail}" == "zyes" ] ; then
    chroot "${LFS}" /usr/bin/env -i                                                                         \
        HOME=/root TERM="${TERM}" PS1='(lfs chroot) \u:\w \$ ' PATH=/usr/bin:/usr/sbin                      \
        /bin/bash --login +h -c "set -e ; set -o pipefail ; source /lfs/ch${optChapter}.sh ; set -x ; ( ch${optChapter}_${optSection} && exit 0 ) || exit 1"
else
    if [ "z${optUser}" == "zroot" ] ; then
        /bin/bash -ec "source /lfs/ch${optChapter}.sh ; set -o pipefail ; set -x ; ( ch${optChapter}_${optSection} && exit 0 ) || exit 1"
    else
        scriptText=$(cat <<EOS
env -i HOME=\${HOME} TERM=\${TERM} \
    /bin/bash -c 'set -e ; set -o pipefail ; if [ -f \${HOME}/.bashrc ] ; then source \${HOME}/.bashrc ; fi ; source /lfs/ch${optChapter}.sh ; set -x ; ( ch${optChapter}_${optSection} && exit 0 ) || exit 1'
EOS
)
        /usr/bin/sudo -u ${optUser} -- /bin/bash -c "${scriptText}"
    fi
fi
