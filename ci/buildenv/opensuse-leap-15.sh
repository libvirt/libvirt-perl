# THIS FILE WAS AUTO-GENERATED
#
#  $ lcitool manifest ci/manifest.yml
#
# https://gitlab.com/libvirt/libvirt-ci

function install_buildenv() {
    zypper update -y
    zypper addrepo -fc https://download.opensuse.org/update/leap/15.6/backports/openSUSE:Backports:SLE-15-SP6:Update.repo
    zypper install -y \
           ca-certificates \
           ccache \
           cpp \
           gcc \
           gettext-runtime \
           git \
           glib2-devel \
           glibc-devel \
           glibc-locale \
           libgnutls-devel \
           libnl3-devel \
           libtirpc-devel \
           libxml2 \
           libxml2-devel \
           libxslt \
           make \
           meson \
           ninja \
           perl \
           perl-Archive-Tar \
           perl-CPAN-Changes \
           perl-Module-Build \
           perl-Test-Pod \
           perl-Test-Pod-Coverage \
           perl-XML-XPath \
           perl-base \
           pkgconfig \
           python3-base \
           python3-docutils \
           rpm-build
    rm -f /usr/lib*/python3*/EXTERNALLY-MANAGED
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
