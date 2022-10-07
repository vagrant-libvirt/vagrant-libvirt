# syntax = docker/dockerfile:1.0-experimental
ARG VAGRANT_VERSION=2.3.0


FROM ubuntu:jammy as base

RUN apt update \
    && apt install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        gosu \
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
RUN sed -i '/deb-src/s/^# //' /etc/apt/sources.list
RUN apt update \
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

RUN find /opt/vagrant/embedded/ -type f | grep -v /opt/vagrant/embedded/plugins.json > /files-to-delete.txt

RUN /opt/vagrant/embedded/bin/gem install --install-dir /opt/vagrant/embedded/gems/${VAGRANT_VERSION} ./pkg/vagrant-libvirt*.gem

RUN echo -n '{\n\
    "version": "1",\n\
    "installed": {\n\
        "vagrant-libvirt": {\n\
            "ruby_version": "'$(/opt/vagrant/embedded/bin/ruby -e 'puts "#{RUBY_VERSION}"')'",\n\
            "vagrant_version": "'${VAGRANT_VERSION}'",\n\
            "gem_version":"",\n\
            "require":"",\n\
            "sources":[]\n\
        }\n\
    }\n\
}' > /opt/vagrant/embedded/plugins.json

FROM build as pruned

RUN cat /files-to-delete.txt | xargs rm -f

FROM base as slim

COPY --from=pruned /opt/vagrant/embedded/gems /opt/vagrant/embedded/gems
COPY --from=build /opt/vagrant/embedded/plugins.json /opt/vagrant/embedded/plugins.json

COPY entrypoint.sh /usr/local/bin/

ENTRYPOINT ["entrypoint.sh"]

FROM build as final

COPY entrypoint.sh /usr/local/bin/

ENTRYPOINT ["entrypoint.sh"]

# vim: set expandtab sw=4:
