# THIS FILE WAS AUTO-GENERATED
#
#  $ lcitool dockerfile opensuse-tumbleweed libvirt+minimal,libvirt-perl
#
# https://gitlab.com/libvirt/libvirt-ci/-/commit/96eec529480444db063e409827cf8ebd0ad5c012

FROM registry.opensuse.org/opensuse/tumbleweed:latest

RUN zypper update -y && \
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
           perl-Archive-Tar \
           perl-CPAN-Changes \
           perl-Module-Build \
           perl-Test-Pod \
           perl-Test-Pod-Coverage \
           perl-Time-HiRes \
           perl-XML-XPath \
           perl-base \
           pkgconfig \
           python3-base \
           python3-docutils \
           rpcgen \
           rpm-build && \
    zypper clean --all && \
    rpm -qa | sort > /packages.txt && \
    mkdir -p /usr/libexec/ccache-wrappers && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/cc && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/gcc

ENV LANG "en_US.UTF-8"
ENV MAKE "/usr/bin/make"
ENV NINJA "/usr/bin/ninja"
ENV PYTHON "/usr/bin/python3"
ENV CCACHE_WRAPPERSDIR "/usr/libexec/ccache-wrappers"
