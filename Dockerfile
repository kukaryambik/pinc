FROM alpine:3

ARG CONMON_REF
ARG RUNC_REF
ARG CNI_PLUGINS_REF
ARG PODMAN_REF

ENV CONMON_REF=${CONMON_REF:-master} \
    RUNC_REF=${RUNC_REF:-master} \
    CNI_PLUGINS_REF=${CNI_PLUGINS_REF:-master} \
    PODMAN_REF=${PODMAN_REF:-master}

    # Build Dependencies
RUN set -ex \
    && apk add --no-cache --virtual build-deps \
      go \
      git \
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
      libassuan-dev \
      libselinux-dev \
      lvm2-dev \
      pkgconf \
    \
    && export GOPATH="$(mktemp -d)" GOCACHE="$(mktemp -d)" \
    # Install runc
    && git clone https://github.com/opencontainers/runc $GOPATH/src/github.com/opencontainers/runc \
    && cd $GOPATH/src/github.com/opencontainers/runc \
    && git checkout -q "$RUNC_REF" \
    && EXTRA_LDFLAGS="-s -w" make BUILDTAGS="seccomp apparmor selinux ambient" \
    && cp runc /usr/bin/runc \
    \
    # Install conmon
    && git clone https://github.com/containers/conmon $GOPATH/src/github.com/containers/conmon \
    && cd $GOPATH/src/github.com/containers/conmon \
    && git checkout -q "$CONMON_REF" \
    && make \
    && mkdir -p /usr/libexec/podman \
    && install -D -m 755 bin/conmon /usr/libexec/podman/conmon \
    \
    # Install CNI plugins
    && git clone https://github.com/containernetworking/plugins.git $GOPATH/src/github.com/containernetworking/plugins \
    && cd $GOPATH/src/github.com/containernetworking/plugins \
    && git checkout -q "$CNI_PLUGINS_REF" \
    && ./build_linux.sh \
    && mkdir -p /usr/libexec/cni \
    && cp bin/* /usr/libexec/cni/ \
    \
    # Install podman
    && git clone https://github.com/containers/podman/ $GOPATH/src/github.com/containers/podman \
    && cd $GOPATH/src/github.com/containers/podman \
    && git checkout -q "$PODMAN_REF" \
    && make install.bin BUILDTAGS="selinux seccomp apparmor" PREFIX=/usr \
    \
    # Cleanup
    && cd \
    && rm -rf "$GOPATH" "$GOCACHE" \
    && apk del build-deps

    # Dependencies
RUN set -ex \
    && apk add --no-cache \
      device-mapper \
      gpgme \
      ip6tables \
      libseccomp \
      tzdata

    # Configs
RUN set -ex \
    && mkdir -p /etc/cni/net.d /etc/containers \
    && wget https://raw.githubusercontent.com/containers/podman/${PODMAN_REF}/cni/87-podman-bridge.conflist -O /etc/cni/net.d/87-podman-bridge.conflist \
    && wget https://raw.githubusercontent.com/projectatomic/registries/master/registries.conf -O /etc/containers/registries.conf \
    && wget https://raw.githubusercontent.com/containers/skopeo/master/default-policy.json -O /etc/containers/policy.json

ENTRYPOINT ["podman"]
CMD ["info"]

VOLUME /var/lib/containers
