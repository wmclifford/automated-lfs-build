# QEMU

The automation for the LFS build provided in this repository is based upon using QEMU to
provide a virtual machine, in which we create our LFS system. Please note that the system
resources allocated to the virtual machine are somewhat limited due to the hardware and
operating system on which QEMU was run. That being said, this proof-of-concept build
should work both on lower-end systems and powerhouse systems with much greater resources.

## Basic setup

For those interested, my development environment is (generally) Mac OS X, and where
needed, a Linux virtual machine or two is run to provide additional support. Unfortunately,
the Mac is not terribly powerful (Mac Mini circa 2014), and so my VMs tend to be of
limited resources. For this experiment, we will be running an `x86_64` virtual machine
with 2 virtual CPUs and 2GB of virtual memory. The virtual machine also has a single
virtual network interface which is used for accessing the Internet for downloading the
LFS source packages and patches. To keep things organized, the virtual hard disk(s) and
boot media (ISOs) are kept within a single folder, along with a couple of helper shell
scripts which are used to boot the virtual machine.

## Boot media

While any Linux distribution may be used to build an LFS system, I spent some time looking
for a small distribution which can be run from CD so that the hard disk on which LFS is
built may remain solely for LFS and not require space for the host operating system.
There are various available (Knoppix works well, for example), but I settled on [Tiny Core
Linux](http://tinycorelinux.net/) for this build. It has its pros and cons, much of which
will be documented throughout the build scripts, however it works well in a limited
environment.

If you want to experiment with a different host distribution, there is a
[list of Live CDs](https://livecdlist.com/os/linux/) that is relatively comprehensive,
albeit not up-to-date with the actual latest releases of many of the Linux distributions
it lists. For example, last checked the Tiny Core distribution is listed as having its
last release in 2015, and its actual most recent release as of this writing was
February 2021. So don't let the latest release dates put you off or divert you from
trying a particular distribution. Most link to the distribution's website, and there you
can see for yourself what is the current status of the distribution.

As Tiny Core Linux was chosen for this build, we will be using the latest version that
is presently available. Please note that the distribution provides both a UI/desktop
ISO and a console-only ISO. Use whichever you prefer, however the console-only version
was chosen here. It can be found [here](http://tinycorelinux.net/12.x/x86_64/release/CorePure64-12.0.iso),
along with its [MD5 checksum](http://tinycorelinux.net/12.x/x86_64/release/CorePure64-12.0.iso.md5.txt).
For those interested in using the desktop version, it can be found
[here](http://tinycorelinux.net/12.x/x86_64/release/TinyCorePure64-12.0.iso), along with its
[MD5 checksum](http://tinycorelinux.net/12.x/x86_64/release/TinyCorePure64-12.0.iso.md5.txt).
Optionally, you can download the ISO and MD5 files using:

```shell
 # Console-only
 $ wget -O CorePure64-12.0.iso http://tinycorelinux.net/12.x/x86_64/release/CorePure64-12.0.iso
 $ wget -O CorePure64-12.0.iso.md5 http://tinycorelinux.net/12.x/x86_64/release/CorePure64-12.0.iso.md5.txt
 
 # Desktop
 $ wget -O TinyCorePure64-12.0.iso http://tinycorelinux.net/12.x/x86_64/release/TinyCorePure64-12.0.iso
 $ wget -O TinyCorePure64-12.0.iso.md5 http://tinycorelinux.net/12.x/x86_64/release/TinyCorePure64-12.0.iso.md5.txt
```

## Install media

Depending on how sophisticated one wishes to make the LFS build, one or more virtual hard
disks may be used. For our initial build, we will only be using a single virtual hard disk
of 30 GB in size. That provides us with enough space to install our LFS system, have a
swap partition, and house the LFS sources with room enough to build everything. If it is
desired to not have the LFS sources on the same virtual hard disk as the final system,
a second virtual hard disk may be used. We may attempt that at a later time, but for now,
we use a single disk.

To create the virtual hard disk, use the following command:

```shell
 $ qemu-img create -f qcow2 lfs11-sda.qcow2 30G
```

This creates our 30 GB disk using the QCOW2 format. If one prefers to use VDI or VMDK instead,
that should work as well. I have built VMs using a raw disk image as well, however there
is little, if anything, to gain in doing so. The QCOW2 format will start as a small file and
grow in size as needed, up to our 30 GB maximum size. Using a raw disk image will result in
the full 30 GB being allocated immediately. Once again, use what works for you.

As far as partitioning is concerned, that will be covered in more detail elsewhere. For
now, let it be known that the entire disk will be used without creating any "special"
partitions. That is, we will create the `/boot` partition for our Linux kernel and boot
loader, a swap partition, and the rest of the disk will be used for the `root` system.
The LFS book discusses using additional partitions for things like `/home`, `/usr`,
`/tmp`, and others. If you plan on using your LFS system for a "production" environment,
then thought should be put into using such additional partitions, along with following
the CIS security standards for hardening a Linux system. Both of these topics are
beyond the scope of this build.

## Booting the virtual machine

Once the boot media and install media are available, we can boot the virtual machine as
follows:

```shell
 $ qemu-system-x86_64 -smp 2 -m 2048 -cpu max -accel hvf      \
        -net nic,model=virtio -net user                       \
        -hda lfs11-sda.qcow2                                  \
        -cdrom CorePure64-12.0.iso                            \
        -boot order=dc
```

This gets things up and running. Additional options may be provided to configure sound,
display settings, and other things; this is the basic requirements. Also, note the use
of the `-boot` argument. If the machine must be rebooted during the build process, this
argument will force the machine to boot from the virtual CD-ROM and not the virtual hard
disk. Once the system should be booted from the installation disk, this argument should
no longer be used.

Once the virtual machine is running, it should prompt the user to provide kernel boot
options. These will be dependent on the distribution being used. For details regarding
Tiny Core Linux, please refer to the other documentation provided in this repository.

---
Copyright &copy; 2021, William Clifford.
