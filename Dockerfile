FROM alpine:3.10 as build

RUN apk add --no-cache \
      git \
      go \
      go-md2man \
      make \
      linux-headers \
      bash \
      libc-dev \
      runc \
      glib-dev \
      gpgme-dev \
      libseccomp-dev \
      ostree-dev

ENV GOPATH="/usr/go" \
    PATH="$GOPATH/bin:$PATH"

RUN mkdir -p /usr/src/conmon \
    && cd /usr/src/conmon \
    && git clone https://github.com/containers/conmon . \
    && make \
    && make podman PREFIX=/opt/podman \
    && ln -s /opt/podman/libexec/podman /usr/libexec/podman

RUN git clone https://github.com/containernetworking/plugins.git $GOPATH/src/github.com/containernetworking/plugins \
    && cd $GOPATH/src/github.com/containernetworking/plugins \
    && ./build_linux.sh \
    && mkdir -p /opt/podman/libexec/cni \
    && cp bin/* /opt/podman/libexec/cni

RUN git clone https://github.com/containers/libpod/ $GOPATH/src/github.com/containers/libpod \
    && cd $GOPATH/src/github.com/containers/libpod \
    && make BUILDTAGS="exclude_graphdriver_btrfs exclude_graphdriver_devicemapper" \
    && make install.bin install.config PREFIX=/opt/podman

FROM alpine:3.10

EXPOSE 2345
VOLUME /var/lib/containers

COPY --from=build /opt/podman /usr

RUN apk add --no-cache \
      ip6tables \
      runc \
      gpgme \
      ostree \
    && mkdir -p /etc/cni/net.d \
    && wget https://raw.githubusercontent.com/containers/libpod/master/cni/87-podman-bridge.conflist -O /etc/cni/net.d/87-podman-bridge.conflist \
    && wget https://raw.githubusercontent.com/projectatomic/registries/master/registries.conf -O /etc/containers/registries.conf \
    && wget https://raw.githubusercontent.com/containers/skopeo/master/default-policy.json -O /etc/containers/policy.json

COPY ./conf /etc/containers

CMD ["podman","varlink","--timeout","0","tcp:127.0.0.1:2345"]
