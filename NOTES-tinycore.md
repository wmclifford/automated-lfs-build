# NOTES For Building LFS Using TinyCore Linux

## Boot Options

By default, TinyCore runs as the `tc` user, and unless to tell it to allow you to do so, you cannot switch to `root`.
This, naturally, would make building LFS impossible. However, there are a couple of boot options that can be used to
allow access to the `root` user. When booting from CD/ISO, add the following options (assuming we are booting the
`CorePure64` ISO and not the `TinyCorePure64` ISO):

* `secure` - this will cause the boot process to prompt for passwords for both the `root` and `tc` users.
* `superuser` - this will cause the `root` user to be automatically logged in upon startup. It also causes the boot
  process to create the empty file `/etc/sysconfig/superuser`, which tells TinyCore that it is ok to run as `root`.
  If you forget to use `superuser` at boot time, you can always create the file yourself using `sudo touch /etc/sysconfig/superuser`.

Optionally, there are various other arguments you can provide at boot. However, the two options most likely to be used
would be:

* `tz=ZZZZZ`, where `ZZZZZ` is the code for your timezone. For example, `tz=EDT` for Eastern Daylight Time.
* `vga=7nn`, where `7nn` is the code for the video mode you wish to use. Pressing `F3` at the boot prompt will display
  a table of the codes and to what resolution/color depth they correspond. For example, `vga=794` sets the video mode
  to `1280x1024x32`.

## Package Management

Unfortunately, it seems that this aspect of this distribution was done completely bass-ackwards. Attempting to add
packages (or extensions, to which they are also referred) as the `root` user gives you an error message telling you it
is not a good idea to run the package utility as `root`. You have to run it as the `tc` user. So if you were automatically
logged in as `root` because the `superuser` boot argument was used, you have to `exit` and log in as `tc`. Once you have
done that, you can (optionally) set up the mirror from which you wish to download the packages. The GUI version is much
easier to use, so if you want to toy around with that first before diving into your LFS build, go for it. You should be
able to identify the fastest mirror that way, then when you run the `CorePure64` image, you can simply select it from
the list of mirrors when prompted. Of course, you can always skip this and use the default URL which works just fine.

### Selecting the tce mirror (optional)

Again, as `tc`, you need to add the `mirrors` package for this to work.

```bash
    tc@box:~$ tce-load -wi mirrors
    Downloading: mirrors.tcz
    Connecting to repo.tinycorelinux.net (89.22.99.37:80)
    saving to 'mirrors.tcz'
    mirrors.tcz          100% |************************************************************|  4096  0:00:00 ETA
    'mirrors.tcz' saved
    mirrors.tcz: OK
    tc@box:~$
```

This installs the list of mirrors. To select one, run `tcemirror.sh`. You will be presented with a menu of the mirrors,
from which you may select the mirror of your choice via number. Once you have done that, all downloads will be from
that mirror.

### Adding additional packages needed for LFS

The LFS build has some relatively strict requirements for the host system. Most modern Linux distros will have the
majority of the tools already installed, or will have the requirements little more than a call to the package manager
away. TinyCore Linux provides the necessary packages, however almost all of them will need to be installed on top of
the base system. One of the primary reasons for this is because TinyCore uses BusyBox for almost all of the system
tools. This is a great space saver, and generally this is more than enough for normal use cases. However, the LFS
build will expect certain versions of tools to be available, specifically the GNU version of these tools, and be able
to call those tools with certain arguments. BusyBox mimics most of this, but there are notable distinctions which will
break the LFS build. Right out the chute, one of the requirements is that `/bin/sh` be a symlink to `/bin/bash`. Since
BusyBox is used, both of those are symlinks to the BusyBox executable, not actual Bash, and things definitely do not
work correctly in the build when this is the case.

In order to provide the minimum host requirements for the LFS build, the following packages must be added before
starting the build:

* `compiletc`
* `bash`
* `bzip2`
* `coreutils`
* `curl`
* `gawk`
* `git`
* `grep`
* `gzip`
* `less`
* `nano`
* `perl5`
* `python3.9`
* `sed`
* `tar`
* `texinfo`
* `util-linux`
* `vim`
* `wget`
* `xz`

The `compiletc` meta-package brings in basically all of the development tool requirements (`binutils`, `gcc`, etc) and
a few system tools as well. `bash` was already discussed. Other things like `bzip2`, `gawk`, `grep`, and such are
added specifically to override those provided by BusyBox. `curl` and `wget` provide CLI download support. `nano` and
`vim` provide console text editor support. And, while not needed if you simply follow the LFS book, `git` is added so
that helpful automation support (such as this repository) may be retrieved and used as part of the build.

To add the aforementioned packages, as the `tc` user, run `tce-load -wi <PACKAGE-NAME>` for each package individually,
or, if you want, you can provide the entire list to `tce-load` in one call.
