# THIS FILE WAS AUTO-GENERATED
#
#  $ lcitool manifest ci/manifest.yml
#
# https://gitlab.com/libvirt/libvirt-ci

FROM registry.fedoraproject.org/fedora:42

RUN dnf install -y nosync && \
    printf '#!/bin/sh\n\
if test -d /usr/lib64\n\
then\n\
    export LD_PRELOAD=/usr/lib64/nosync/nosync.so\n\
else\n\
    export LD_PRELOAD=/usr/lib/nosync/nosync.so\n\
fi\n\
exec "$@"\n' > /usr/bin/nosync && \
    chmod +x /usr/bin/nosync && \
    nosync dnf update -y && \
    nosync dnf install -y \
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
               rpm-build && \
    nosync dnf autoremove -y && \
    nosync dnf clean all -y && \
    rm -f /usr/lib*/python3*/EXTERNALLY-MANAGED && \
    rpm -qa | sort > /packages.txt && \
    mkdir -p /usr/libexec/ccache-wrappers && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/cc && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/gcc

ENV CCACHE_WRAPPERSDIR "/usr/libexec/ccache-wrappers"
ENV LANG "en_US.UTF-8"
ENV MAKE "/usr/bin/make"
ENV NINJA "/usr/bin/ninja"
ENV PYTHON "/usr/bin/python3"
