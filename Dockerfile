ARG ALPINE_VERSION="3.13"

FROM alpine:${ALPINE_VERSION}

ARG VERSION="1.3.0"

RUN apk add --no-cache \
		bash \
		libqrencode \
		s6

# TODO: deal with raspberry pi;
RUN apk add --no-cache "nebula=${VERSION}-r0"

VOLUME ["/etc/nebula"]

ARG PWD="/opt/services.d"
WORKDIR ${PWD}
ADD services.d .
RUN grep -rl "^#\!" . | xargs chmod -v a+x

CMD ["s6-svscan"]
