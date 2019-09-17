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
    && make podman PREFIX=/usr

RUN git clone https://github.com/containers/libpod/ $GOPATH/src/github.com/containers/libpod \
    && cd $GOPATH/src/github.com/containers/libpod \
    && make BUILDTAGS="exclude_graphdriver_btrfs exclude_graphdriver_devicemapper" \
    && make install PREFIX=/usr

FROM alpine:3.10

EXPOSE 2345
VOLUME ["/var/lib/containers/storage","/var/run/containers/storage"]

RUN apk add --no-cache \
      runc \
      gpgme \
      ostree

COPY --from=build /usr/libexec/podman /usr/libexec/podman
COPY --from=build /usr/bin/*pod* /usr/bin/
COPY  ./conf /etc/containers

RUN ln -s /usr/bin/podman /usr/bin/docker

ENTRYPOINT ["podman","varlink","--timeout","0","tcp:127.0.0.1:2345"]
