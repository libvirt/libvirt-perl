# THIS FILE WAS AUTO-GENERATED
#
#  $ lcitool manifest ci/manifest.yml
#
# https://gitlab.com/libvirt/libvirt-ci

function install_buildenv() {
    apk update
    apk upgrade
    apk add \
        ca-certificates \
        ccache \
        gcc \
        gettext \
        git \
        glib-dev \
        gnutls-dev \
        libnl3-dev \
        libtirpc-dev \
        libxml2-dev \
        libxml2-utils \
        libxslt \
        make \
        meson \
        musl-dev \
        perl \
        perl-app-cpanminus \
        perl-dev \
        perl-module-build \
        perl-test-pod \
        perl-test-pod-coverage \
        perl-time-hires \
        perl-xml-xpath \
        pkgconf \
        py3-docutils \
        python3 \
        samurai
    rm -f /usr/lib*/python3*/EXTERNALLY-MANAGED
    apk list --installed | sort > /packages.txt
    mkdir -p /usr/libexec/ccache-wrappers
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/cc
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/gcc
    cpanm --notest \
          Archive::Tar \
          CPAN::Changes
}

export CCACHE_WRAPPERSDIR="/usr/libexec/ccache-wrappers"
export LANG="en_US.UTF-8"
export MAKE="/usr/bin/make"
export NINJA="/usr/bin/ninja"
export PYTHON="/usr/bin/python3"
