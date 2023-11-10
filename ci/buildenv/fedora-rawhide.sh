# THIS FILE WAS AUTO-GENERATED
#
#  $ lcitool manifest ci/manifest.yml
#
# https://gitlab.com/libvirt/libvirt-ci

function install_buildenv() {
    dnf update -y --nogpgcheck fedora-gpg-keys
    dnf distro-sync -y
    dnf install -y \
        ca-certificates \
        ccache \
        cpp \
        gcc \
        gettext \
        git \
        glib2-devel \
        glibc-devel \
        glibc-langpack-en \
        gnutls-devel \
        libnl3-devel \
        libtirpc-devel \
        libxml2 \
        libxml2-devel \
        libxslt \
        make \
        meson \
        ninja-build \
        perl-Archive-Tar \
        perl-CPAN-Changes \
        perl-ExtUtils-CBuilder \
        perl-Module-Build \
        perl-Sys-Hostname \
        perl-Test-Pod \
        perl-Test-Pod-Coverage \
        perl-Time-HiRes \
        perl-XML-XPath \
        perl-base \
        perl-generators \
        pkgconfig \
        python3 \
        python3-docutils \
        rpm-build
    rpm -qa | sort > /packages.txt
    mkdir -p /usr/libexec/ccache-wrappers
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/cc
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/gcc
}

export CCACHE_WRAPPERSDIR="/usr/libexec/ccache-wrappers"
export LANG="en_US.UTF-8"
export MAKE="/usr/bin/make"
export NINJA="/usr/bin/ninja"
export PYTHON="/usr/bin/python3"
