FROM alpine:3.10 as builder

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

ENV GOPATH="/go" \
    PATH="$GOPATH/bin:$PATH"

RUN git clone https://github.com/containers/conmon $GOPATH/src/github.com/containers/conmon \
    && cd $GOPATH/src/github.com/containers/conmon \
    && make

RUN git clone https://github.com/opencontainers/runc $GOPATH/src/github.com/opencontainers/runc \
    && cd $GOPATH/src/github.com/opencontainers/runc \
    && EXTRA_LDFLAGS="-s -w" make BUILDTAGS="seccomp apparmor selinux ambient"

RUN git clone https://github.com/containernetworking/plugins.git $GOPATH/src/github.com/containernetworking/plugins \
    && cd $GOPATH/src/github.com/containernetworking/plugins \
    && GOFLAGS="-ldflags=-s -ldflags=-w" ./build_linux.sh

RUN git clone https://github.com/containers/libpod/ $GOPATH/src/github.com/containers/libpod \
    && cd $GOPATH/src/github.com/containers/libpod \
    && LDFLAGS="-s -w" make varlink_generate install.bin BUILDTAGS="selinux seccomp apparmor"

FROM alpine:3.10

EXPOSE 2345
VOLUME /var/lib/containers

COPY --from=builder /go/src/github.com/containers/conmon/bin/ /usr/bin/
COPY --from=builder /go/src/github.com/opencontainers/runc/runc /usr/bin/
COPY --from=builder /go/src/github.com/containernetworking/plugins/bin/ /usr/lib/cni/
COPY --from=builder /go/src/github.com/containers/libpod/bin/ /usr/bin/

RUN apk add --no-cache \
      ip6tables \
      gpgme \
      libseccomp \
      device-mapper \
      git \
      openssh-client \
      curl \
      jq \
    && mkdir -p /etc/cni/net.d /etc/containers \
    && wget https://raw.githubusercontent.com/containers/libpod/master/cni/87-podman-bridge.conflist -O /etc/cni/net.d/87-podman-bridge.conflist \
    && wget https://raw.githubusercontent.com/projectatomic/registries/master/registries.conf -O /etc/containers/registries.conf \
    && wget https://raw.githubusercontent.com/containers/skopeo/master/default-policy.json -O /etc/containers/policy.json

COPY ./conf /etc/containers

CMD ["podman","varlink","--timeout","0","tcp:127.0.0.1:2345"]
