# syntax = docker/dockerfile:1.0-experimental
ARG VAGRANT_VERSION=2.2.10


FROM ubuntu:bionic as base

RUN apt update \
    && apt install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        gosu \
        kmod \
        libvirt-bin \
        openssh-client \
        qemu-utils \
        rsync \
    && rm -rf /var/lib/apt/lists \
    ;

RUN mkdir /vagrant
ENV VAGRANT_HOME /vagrant

ARG VAGRANT_VERSION
ENV VAGRANT_VERSION ${VAGRANT_VERSION}
RUN set -e \
    && curl https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_x86_64.deb -o vagrant.deb \
    && apt update \
    && apt install -y ./vagrant.deb \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f vagrant.deb \
    ;


FROM base as build

# allow caching of packages for build
RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN sed -i '/deb-src/s/^# //' /etc/apt/sources.list
RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt \
    apt update \
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
    ;

WORKDIR /build

COPY . .
RUN rake build
RUN vagrant plugin install ./pkg/vagrant-libvirt*.gem


RUN for dir in boxes data tmp; \
    do \
        rm -rf /vagrant/${dir} && ln -s /.vagrant.d/${dir} /vagrant/${dir}; \
    done \
    ;

FROM base as final

ENV VAGRANT_DEFAULT_PROVIDER=libvirt

COPY --from=build /vagrant /vagrant
COPY entrypoint.sh /usr/local/bin/

ENTRYPOINT ["entrypoint.sh"]
# vim: set expandtab sw=4:
