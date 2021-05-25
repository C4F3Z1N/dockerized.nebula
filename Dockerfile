ARG ALPINE_VERSION="3.13"

FROM alpine:${ALPINE_VERSION}

RUN apk add --no-cache \
		inotify-tools \
		libcap \
		nebula \
		procps \
		s6-overlay

ARG S6_BEHAVIOUR_IF_STAGE2_FAILS=2
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=${S6_BEHAVIOUR_IF_STAGE2_FAILS}

ARG CONFIG_DIR="/etc/nebula"
ENV CONFIG_DIR=${CONFIG_DIR}
VOLUME ${CONFIG_DIR}
WORKDIR ${CONFIG_DIR}

COPY overlay-rootfs /

CMD ["/init"]
