ARG ALPINE_VERSION="3.13"

FROM alpine:${ALPINE_VERSION}

ARG VERSION="1.3.0"

RUN apk add --no-cache \
		inotify-tools \
		procps \
		s6-overlay

ENTRYPOINT ["/init"]

RUN apk add --no-cache "nebula=${VERSION}-r1"

ARG CONFIG_DIR="/etc/nebula"
ENV CONFIG_DIR=${CONFIG_DIR}
VOLUME ${CONFIG_DIR}

ADD overlay-rootfs /
