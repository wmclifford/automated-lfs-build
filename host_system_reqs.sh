#!/bin/bash -e

export DEBIAN_FRONTEND=noninteractive

# Add contrib and non-free source to APT
sed -r -e 's/\bmain$/& contrib non-free/' -i /etc/apt/sources.list
apt update

# Add known requirements for building LFS
apt install -y \
    bash binutils bison bzip2 coreutils diffutils findutils \
    gawk gcc g++ grep gzip m4 make patch perl python3 sed   \
    tar texinfo xz-utils wget curl sudo less nano-tiny vim-tiny

# Make sure /bin/sh points at bash
ln -sf /bin/bash /bin/sh
