FROM alpine:3.10

ARG CONMON_REF
ARG RUNC_REF
ARG CNI_PLUGINS_REF
ARG PODMAN_REF

ENV CONMON_REF=${CONMON_REF:-master} \
    RUNC_REF=${RUNC_REF:-master} \
    CNI_PLUGINS_REF=${CNI_PLUGINS_REF:-master} \
    PODMAN_REF=${PODMAN_REF:-master}

RUN set -ex \
    && apk add --no-cache --virtual build-deps \
      git \
      go \
      make \
      linux-headers \
      bash \
      libc-dev \
      glib-dev \
      gpgme-dev \
      libseccomp-dev \
      ostree-dev \
      btrfs-progs-dev \
      build-base \
      device-mapper \
      ip6tables \
      libassuan-dev \
      libselinux-dev \
      lvm2-dev \
      pkgconf \
      openssl \
      protobuf-c-dev \
      protobuf-dev \
    \
    # Install runc
    && export GOPATH="$(mktemp -d)" \
    && git clone https://github.com/opencontainers/runc $GOPATH/src/github.com/opencontainers/runc \
    && cd $GOPATH/src/github.com/opencontainers/runc \
    && git checkout -q "$RUNC_REF" \
    && EXTRA_LDFLAGS="-s -w" make BUILDTAGS="seccomp apparmor selinux ambient" \
    && cp runc /usr/bin/runc \
    && rm -rf "$GOPATH" \
    \
    # Install conmon
    && export GOPATH="$(mktemp -d)" \
    && git clone https://github.com/containers/conmon $GOPATH/src/github.com/containers/conmon \
    && cd $GOPATH/src/github.com/containers/conmon \
    && git checkout -q "$CONMON_REF" \
    && make \
    && mkdir -p /usr/libexec/podman \
    && install -D -m 755 bin/conmon /usr/libexec/podman/conmon \
    && rm -rf "$GOPATH" \
    \
    # Install CNI plugins
    && export GOPATH="$(mktemp -d)" GOCACHE="$(mktemp -d)" \
    && git clone https://github.com/containernetworking/plugins.git $GOPATH/src/github.com/containernetworking/plugins \
    && cd $GOPATH/src/github.com/containernetworking/plugins \
    && git checkout -q "$CNI_PLUGINS_REF" \
    && ./build_linux.sh \
    && mkdir -p /usr/libexec/cni \
    && cp bin/* /usr/libexec/cni/ \
    && rm -rf "$GOPATH" \
    \
    # Install podman
    && export GOPATH="$(mktemp -d)" \
    && git clone https://github.com/containers/libpod/ $GOPATH/src/github.com/containers/libpod \
    && cd $GOPATH/src/github.com/containers/libpod \
    && git checkout -q "$PODMAN_REF" \
    && make install.bin BUILDTAGS="selinux seccomp apparmor" PREFIX=/usr \
    && rm -rf "$GOPATH" \
    \
    # Cleanup
    && rm -rf /var/lib/apt/lists/* \
    && apk del build-deps

    # Dependencies
RUN apk add --no-cache \
      ip6tables \
      gpgme \
      libseccomp \
      device-mapper \
      git \
      openssh-client \
      curl \
      jq \
    # Configs
    && mkdir -p /etc/cni/net.d /etc/containers \
    && wget https://raw.githubusercontent.com/containers/libpod/master/cni/87-podman-bridge.conflist -O /etc/cni/net.d/87-podman-bridge.conflist \
    && wget https://raw.githubusercontent.com/projectatomic/registries/master/registries.conf -O /etc/containers/registries.conf \
    && wget https://raw.githubusercontent.com/containers/skopeo/master/default-policy.json -O /etc/containers/policy.json \
    && wget https://raw.githubusercontent.com/containers/libpod/master/libpod.conf -O /etc/containers/libpod.conf \
    && sed -i -e 's/^\(cgroup_manager = \).*/\1"cgroupfs"/' /etc/containers/libpod.conf

ENTRYPOINT ["podman"]
CMD ["info"]

VOLUME /var/lib/containers
