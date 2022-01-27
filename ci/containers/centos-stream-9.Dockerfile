# THIS FILE WAS AUTO-GENERATED
#
#  $ lcitool manifest ci/manifest.yml
#
# https://gitlab.com/libvirt/libvirt-ci

FROM quay.io/centos/centos:stream9

RUN dnf update -y && \
    dnf install 'dnf-command(config-manager)' -y && \
    dnf config-manager --set-enabled -y crb && \
    dnf install -y \
        https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm \
        https://dl.fedoraproject.org/pub/epel/epel-next-release-latest-9.noarch.rpm && \
    dnf install -y \
        ca-certificates \
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
        rpcgen \
        rpm-build && \
    dnf autoremove -y && \
    dnf clean all -y && \
    rpm -qa | sort > /packages.txt

ENV LANG "en_US.UTF-8"
ENV MAKE "/usr/bin/make"
ENV NINJA "/usr/bin/ninja"
ENV PYTHON "/usr/bin/python3"
