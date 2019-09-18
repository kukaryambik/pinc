FROM alpine:3.10 as base

FROM base as builder

ARG CONMON_REF
ARG RUNC_REF
ARG CNI_PLUGINS_REF
ARG PODMAN_REF

ENV CONMON_REF=master \
    RUNC_REF=master \
    CNI_PLUGINS_REF=master \
    PODMAN_REF=master

RUN apk add --no-cache \
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
    ;

# Install runc
RUN set -x \
    && export GOPATH="$(mktemp -d)" \
    && git clone https://github.com/opencontainers/runc $GOPATH/src/github.com/opencontainers/runc \
    && cd $GOPATH/src/github.com/opencontainers/runc \
    && git checkout -q "$RUNC_REF" \
    && EXTRA_LDFLAGS="-s -w" make BUILDTAGS="seccomp apparmor selinux ambient" \
    && mkdir -p /podman/bin \
    && cp runc /podman/bin/runc \
    && rm -rf "$GOPATH"

# Install conmon
RUN set -x \
    && export GOPATH="$(mktemp -d)" \
    && git clone https://github.com/containers/conmon $GOPATH/src/github.com/containers/conmon \
    && cd $GOPATH/src/github.com/containers/conmon \
    && git checkout -q "$CONMON_REF" \
    && make \
    && mkdir -p /podman/libexec/podman \
    && install -D -m 755 bin/conmon /podman/libexec/podman/conmon \
    && rm -rf "$GOPATH"

# Install CNI plugins
RUN set -x \
    && export GOPATH="$(mktemp -d)" GOCACHE="$(mktemp -d)" \
    && git clone https://github.com/containernetworking/plugins.git $GOPATH/src/github.com/containernetworking/plugins \
    && cd $GOPATH/src/github.com/containernetworking/plugins \
    && git checkout -q "$CNI_PLUGINS_REF" \
    && ./build_linux.sh \
    && mkdir -p /podman/libexec/cni \
    && cp bin/* /podman/libexec/cni \
    && rm -rf "$GOPATH"

# Install podman
RUN set -x \
    && export GOPATH="$(mktemp -d)" \
    && git clone https://github.com/containers/libpod/ $GOPATH/src/github.com/containers/libpod \
    && cd $GOPATH/src/github.com/containers/libpod \
    && git checkout -q "$PODMAN_REF" \
    && make install.bin BUILDTAGS="selinux seccomp apparmor" PREFIX=/podman \
    && rm -rf "$GOPATH"

FROM base

COPY --from=builder /podman /usr

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
