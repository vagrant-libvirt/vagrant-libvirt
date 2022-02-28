# syntax = docker/dockerfile:1.0-experimental
ARG VAGRANT_VERSION=2.2.19

FROM debian:stable-slim as base

RUN apt-get -y -qq update \
    && apt-get -y --no-install-recommends install \
      bash \
      ca-certificates \
      curl \
      git \
      gosu \
      kmod \
      libguestfs-tools \
      libvirt0 \
      libvirt-clients \
      libvirt-dev \
      libxml2-dev \
      libxslt-dev \
      openssh-client \
      openssh-sftp-server \
      qemu-system \
      qemu-utils \
      rsync \
      ruby-dev \
      zlib1g-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    ;

RUN mkdir /vagrant
ENV VAGRANT_HOME /vagrant

ARG VAGRANT_VERSION
ENV VAGRANT_VERSION ${VAGRANT_VERSION}

ARG DEFAULT_UID=1000
ARG DEFAULT_USER=vagrant
ARG DEFAULT_GROUP=users

RUN set -e \
    && apt-get -y -qq update \
    && curl -sSL -o /tmp/vagrant.deb "https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_x86_64.deb" \
    && apt-get install -y /tmp/vagrant.deb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && useradd -M --uid ${DEFAULT_UID} --gid ${DEFAULT_GROUP} ${DEFAULT_USER} \
    ;

ENV VAGRANT_DEFAULT_PROVIDER=libvirt

FROM base as build

RUN grep ^deb /etc/apt/sources.list | sed "s/^deb/deb-src/g" > /etc/apt/sources.list.d/sources.list \
    && apt-get -y -qq update \
    && apt build-dep -y \
        vagrant \
        ruby-libvirt \
    && apt install -y --no-install-recommends \
        libxslt-dev \
        libxml2-dev \
        libvirt-dev \
        ruby-bundler \
        ruby-dev \
        zlib1g-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    ;

WORKDIR /build

# comma-separated list of other supporting plugins to install
ARG DEFAULT_OTHER_PLUGINS=vagrant-mutate

COPY . .
RUN rake build \
    && vagrant plugin install ./pkg/vagrant-libvirt*.gem \
    && for plugin in $(echo "$DEFAULT_OTHER_PLUGINS" | sed "s/,/ /g"); \
         do \
           vagrant plugin install ${plugin} ; \
         done \
    && for dir in boxes data tmp; \
         do \
           touch /vagrant/${dir}/.remove; \
         done \
         ;

FROM base as slim

COPY --from=build /vagrant /vagrant

COPY entrypoint.sh /usr/local/bin/

ENTRYPOINT ["entrypoint.sh"]

FROM build as final

COPY entrypoint.sh /usr/local/bin/

ENTRYPOINT ["entrypoint.sh"]

# vim: set expandtab sw=4: