# THIS FILE WAS AUTO-GENERATED
#
#  $ lcitool manifest ci/manifest.yml
#
# https://gitlab.com/libvirt/libvirt-ci

function install_buildenv() {
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get dist-upgrade -y
    apt-get install --no-install-recommends -y \
            ca-certificates \
            ccache \
            cpp \
            gcc \
            gettext \
            git \
            libarchive-tar-perl \
            libc-dev-bin \
            libc6-dev \
            libcpan-changes-perl \
            libextutils-cbuilder-perl \
            libglib2.0-dev \
            libgnutls28-dev \
            libmodule-build-perl \
            libnl-3-dev \
            libnl-route-3-dev \
            libtest-pod-coverage-perl \
            libtest-pod-perl \
            libtime-hr-perl \
            libtirpc-dev \
            libxml-xpath-perl \
            libxml2-dev \
            libxml2-utils \
            locales \
            make \
            ninja-build \
            perl-base \
            pkgconf \
            python3 \
            python3-docutils \
            python3-pip \
            python3-setuptools \
            python3-wheel \
            xsltproc
    sed -Ei 's,^# (en_US\.UTF-8 .*)$,\1,' /etc/locale.gen
    dpkg-reconfigure locales
    dpkg-query --showformat '${Package}_${Version}_${Architecture}\n' --show > /packages.txt
    mkdir -p /usr/libexec/ccache-wrappers
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/cc
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/gcc
    /usr/bin/pip3 install meson==0.56.0
}

export CCACHE_WRAPPERSDIR="/usr/libexec/ccache-wrappers"
export LANG="en_US.UTF-8"
export MAKE="/usr/bin/make"
export NINJA="/usr/bin/ninja"
export PYTHON="/usr/bin/python3"
