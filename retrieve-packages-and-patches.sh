#!/bin/bash -e

export LFS="${LFS:-/mnt/lfs}"

mkdir -pv "${LFS}/sources"
chmod -v a+wt "${LFS}/sources"

cd "${LFS}/sources"
wget --output-document=wget-list https://linuxfromscratch.org/lfs/view/stable/wget-list
wget --output-document=MD5SUMS.txt https://linuxfromscratch.org/lfs/view/stable/md5sums
wget --input-file=wget-list --continue --directory-prefix=${LFS}/sources
md5sum -c MD5SUMS.txt
