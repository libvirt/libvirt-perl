# THIS FILE WAS AUTO-GENERATED
#
#  $ lcitool manifest ci/manifest.yml
#
# https://gitlab.com/libvirt/libvirt-ci

FROM registry.opensuse.org/opensuse/leap:15.3

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
           ninja \
           perl-Archive-Tar \
           perl-CPAN-Changes \
           perl-ExtUtils-CBuilder \
           perl-Module-Build \
           perl-Test-Pod \
           perl-Test-Pod-Coverage \
           perl-Time-HiRes \
           perl-XML-XPath \
           perl-base \
           pkgconfig \
           python3-base \
           python3-docutils \
           python3-pip \
           python3-setuptools \
           python3-wheel \
           rpcgen \
           rpm-build && \
    zypper clean --all && \
    rpm -qa | sort > /packages.txt && \
    mkdir -p /usr/libexec/ccache-wrappers && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/cc && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/gcc

RUN /usr/bin/pip3 install meson==0.56.0

ENV CCACHE_WRAPPERSDIR "/usr/libexec/ccache-wrappers"
ENV LANG "en_US.UTF-8"
ENV MAKE "/usr/bin/make"
ENV NINJA "/usr/bin/ninja"
ENV PYTHON "/usr/bin/python3"
