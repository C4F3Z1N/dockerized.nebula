# stage 0: select the base image;
FROM c4f3z1n/s6-alpine as base

# stage 1: download the binaries;
FROM base as download

ARG ARCH
ARG NEBULA_VERSION

RUN if { apk add --no-cache curl } \
	pipeline { mktemp -d } \
	withstdinas -E PWD \
	execline-cd ${PWD} \
	# if NEBULA_VERSION is not set, retrieve the latest version from GitHub;
	backtick -E NEBULA_VERSION { \
		if -nt { printenv NEBULA_VERSION } \
		pipeline { curl -sL "https://api.github.com/repos/slackhq/nebula/releases/latest" } \
		pipeline { awk "/tag_name/ {print $NF}" } \
		grep -Eo "([0-9]\\.*)*" \
	} \
	# if ARCH is not set, detect and convert the string to the expected naming convention;
	backtick -E ARCH { \
		if -nt { printenv ARCH } \
		backtick -E arch { uname -m } \
		ifelse { heredoc 0 ${arch} grep -q "x86_64" } { s6-echo "amd64" } \
		ifelse { heredoc 0 ${arch} grep -q "aarch64" } { s6-echo "arm64" } \
		if { heredoc 0 ${arch} grep -q "arm" } \
		pipeline { heredoc 0 ${arch} tr -cd "0-9" } \
		withstdinas -E arch_version \
		s6-echo "arm-${arch_version}" \
	} \
	# debug message;
	foreground { \
		fdmove -c 1 2 \
		s6-echo "\n[debug] ARCH: ${ARCH}, NEBULA_VERSION: ${NEBULA_VERSION}" \
	} \
	# download and extract the binaries;
	define download_page_url "https://github.com/slackhq/nebula/releases/download" \
	define tar_name "nebula-linux-${ARCH}.tar.gz" \
	if { curl -L "${download_page_url}/v${NEBULA_VERSION}/${tar_name}" -o ${tar_name} } \
	if { tar -xzf ${tar_name} } \
	if { \
		# verify SHA256 hashes;
		fdmove -c 1 2 \
		# debug message;
		foreground { s6-echo "\n[debug] sha256sum verification:" } \
		pipeline { curl -sL "${download_page_url}/v${NEBULA_VERSION}/SHASUM256.txt" } \
		pipeline { grep ${tar_name} } \
		pipeline { sed "s,${tar_name}/,./," } \
		sha256sum -c \
	} \
	# sanitize the current directory;
	foreground { s6-rmrf ${tar_name} } \
	foreground { elglob i "*" s6-chmod 775 ${i} } \
	foreground { \
		# dump NEBULA_VERSION to "env" for the next stage;
		exec -c \
		export NEBULA_VERSION ${NEBULA_VERSION} \
		s6-dumpenv "env" \
	} \
	# debug message;
	foreground { \
		fdmove -c 1 2 \
		foreground { s6-echo "\n[debug] directory content:" } \
		s6-ls ${PWD} \
	} \
	s6-ln -fs ${PWD} "/tmp/downloads"

# stage 2: final adjustments and health check;
FROM base

RUN apk add --no-cache \
		inotify-tools \
		libcap \
		procps \
		yq

WORKDIR "/tmp/downloads"
COPY --from=download "/tmp/downloads" .

RUN backtick -E NEBULA_VERSION { \
		if { redirfd -r 0 "env/NEBULA_VERSION" s6-cat } \
		s6-rmrf "env" \
	} \
	# try to install the specified/latest version from alpine repos;
	backtick -E output { mktemp -u } \
	ifelse { \
		redirfd -w 1 ${output} \
		fdmove -c 2 1 \
		apk add --no-cache "nebula~=${NEBULA_VERSION}" \
	} { redirfd -r 0 ${output} s6-cat }\
	# use the downloaded binaries if it fails;
	elglob items "*" \
	mv -fv ${items} "/usr/local/bin"

ARG CONFIG_DIR="/config"
ENV CONFIG_DIR=${CONFIG_DIR}
VOLUME ${CONFIG_DIR}
WORKDIR ${CONFIG_DIR}

COPY overlay-rootfs /

HEALTHCHECK --interval=15s --timeout=30s --start-period=15s \  
	CMD ["healthcheck"]

