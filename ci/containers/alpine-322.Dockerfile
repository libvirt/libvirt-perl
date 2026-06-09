# THIS FILE WAS AUTO-GENERATED
#
#  $ lcitool manifest ci/manifest.yml
#
# https://gitlab.com/libvirt/libvirt-ci

FROM docker.io/library/alpine:3.22

RUN apk update && \
    apk upgrade && \
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
        samurai && \
    rm -f /usr/lib*/python3*/EXTERNALLY-MANAGED && \
    apk list --installed | sort > /packages.txt && \
    mkdir -p /usr/libexec/ccache-wrappers && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/cc && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/gcc

RUN cpanm --notest \
          Archive::Tar \
          CPAN::Changes

ENV CCACHE_WRAPPERSDIR="/usr/libexec/ccache-wrappers"
ENV LANG="en_US.UTF-8"
ENV MAKE="/usr/bin/make"
ENV NINJA="/usr/bin/ninja"
ENV PYTHON="/usr/bin/python3"
