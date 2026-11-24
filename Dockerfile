# syntax = docker/dockerfile:1.0-experimental
ARG VAGRANT_VERSION=2.4.9


FROM ubuntu:noble as base

RUN apt update \
    && apt install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        gosu \
        iproute2 \
        kmod \
        libvirt-clients \
        openssh-client \
        qemu-utils \
        rsync \
    && rm -rf /var/lib/apt/lists \
    ;

ENV VAGRANT_HOME /.vagrant.d

ARG VAGRANT_VERSION
ENV VAGRANT_VERSION ${VAGRANT_VERSION}
RUN set -e \
    && curl https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}-1_amd64.deb -o vagrant.deb \
    && apt update \
    && apt install -y ./vagrant.deb \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f vagrant.deb \
    ;

ENV VAGRANT_DEFAULT_PROVIDER=libvirt

FROM base as build

# allow caching of packages for build
RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
RUN apt update \
    && apt build-dep -y \
        ruby-libvirt \
    && apt install -y --no-install-recommends \
        libxslt-dev \
        libxml2-dev \
        libvirt-dev \
        ruby-bundler \
        ruby-dev \
        zlib1g-dev \
    ;

WORKDIR /build

COPY . .
RUN rake build

RUN mkdir -p /tmp/vagrant-home \
    && VAGRANT_HOME=/tmp/vagrant-home vagrant plugin install ./pkg/vagrant-libvirt*.gem \
    && mkdir -p /vagrant-libvirt-plugin \
    && mv /tmp/vagrant-home/plugins.json /vagrant-libvirt-plugin/plugins.json \
    && mv /tmp/vagrant-home/gems /vagrant-libvirt-plugin/gems \
    && rm -rf /tmp/vagrant-home \
    && cd / && rm -rf /build

FROM base as slim

COPY --from=build /vagrant-libvirt-plugin /vagrant-libvirt-plugin

COPY entrypoint.sh /usr/local/bin/

ENTRYPOINT ["entrypoint.sh"]

FROM build as final

COPY entrypoint.sh /usr/local/bin/

ENTRYPOINT ["entrypoint.sh"]

# vim: set expandtab sw=4:
