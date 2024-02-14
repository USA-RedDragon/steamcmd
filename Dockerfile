FROM debian:12.5-slim as box-arm64

# renovate: datasource=repology versioning=deb depName=debian_12/gcc
ENV LIBSTDCPP__6_VERSION=12.2.0-14
# renovate: datasource=repology versioning=deb depName=debian_12/glibc
ENV LIBC6_VERSION=2.36-9+deb12u4
# renovate: datasource=repology versioning=deb depName=debian_12/ca-certificates
ENV CA_CERTIFICATES_VERSION=20230311
# renovate: datasource=git-refs versioning=git depName=https://github.com/ptitSeb/box86.git
ENV BOX86_VERSION=8378f9b307a1efd12aa056f8131a6d78361ee2e1
# renovate: datasource=git-refs versioning=git depName=https://github.com/ptitSeb/box64.git
ENV BOX64_VERSION=549e042e678e0909c1a79325fb406fb0081ccac7

RUN export DEBIAN_FRONTEND=noninteractive \
    && dpkg --add-architecture armhf \
    && apt-get update \
    && apt-get install --yes --no-install-recommends --no-install-suggests \
        python3 \
        git \
        build-essential \
        cmake \
        gcc-arm-linux-gnueabihf \
        libc6-dev-armhf-cross \
        ca-certificates=${CA_CERTIFICATES_VERSION} \
        libc6:armhf=${LIBC6_VERSION} \
        libstdc++6:armhf=${LIBSTDCPP__6_VERSION} \
    && git clone --single-branch https://github.com/ptitSeb/box86.git; mkdir /box86/build \
    && git clone --single-branch https://github.com/ptitSeb/box64.git; mkdir /box64/build \
    && cd /box86 \
    && git checkout ${BOX86_VERSION} \
    && cd /box86/build \
    && cmake .. -DARM64=1 -DARM_DYNAREC=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    && make -j$(nproc) \
    && make install \
    && cd /box64 \
    && git checkout ${BOX64_VERSION} \
    && cd /box64/build \
    && cmake .. -DARM64=1 -DARM_DYNAREC=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    && make -j$(nproc) \
    && make install \
    && apt-get remove --yes --purge \
        python3 \
        git \
        build-essential \
        cmake \
        gcc-arm-linux-gnueabihf \
        ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

FROM debian:12.5-slim as box-amd64

ARG TARGETARCH
FROM box-${TARGETARCH}

LABEL maintainer="walentinlamonos@gmail.com"
ARG PUID=1000

ENV USER steam
ENV STEAMCMDDIR "/home/${USER}/steamcmd"

ENV DEBUGGER "/usr/local/bin/box86"

# renovate: datasource=repology versioning=deb depName=debian_12/gcc
ENV LIB32STDCPP__6_VERSION=12.2.0-14
# renovate: datasource=repology versioning=deb depName=debian_12/gcc
ENV LIB32GCC_S1_VERSION=12.2.0-14
# renovate: datasource=repology versioning=deb depName=debian_12/ca-certificates
ENV CA_CERTIFICATES_VERSION=20230311
# renovate: datasource=repology versioning=deb depName=debian_12/nano
ENV NANO_VERSION=7.2-1
# renovate: datasource=repology versioning=deb depName=debian_12/curl
ENV CURL_VERSION=7.88.1-10+deb12u5
# renovate: datasource=repology versioning=deb depName=debian_12/glibc
ENV LOCALES_VERSION=2.36-9+deb12u4

ARG TARGETARCH
RUN set -x \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests \
        ca-certificates=${CA_CERTIFICATES_VERSION} \
        nano=${NANO_VERSION} \
        curl=${CURL_VERSION} \
        locales=${LOCALES_VERSION} \
    && if [ "${TARGETARCH}" = "amd64" ]; then \
        echo '#!/bin/sh\nexec "$@"' > /usr/local/bin/box86 \
        && chmod +x /usr/local/bin/box86 \
        && apt-get install -y --no-install-recommends --no-install-suggests \
            lib32stdc++6=${LIB32STDCPP__6_VERSION} \
            lib32gcc-s1=${LIB32GCC_S1_VERSION} \
        ; \
    fi \
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && dpkg-reconfigure locales \
    # Create unprivileged user
    && useradd -u "${PUID}" -m "${USER}" \
    && rm -rf /var/lib/apt/lists/*

# Symlink steamclient.so; So misconfigured dedicated servers can find it
RUN ln -s "${STEAMCMDDIR}/linux64/steamclient.so" "/usr/lib/x86_64-linux-gnu/steamclient.so"

USER ${USER}
WORKDIR ${STEAMCMDDIR}

# Download SteamCMD, execute as user
RUN curl -fsSL 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz' | tar xvzf - -C "${STEAMCMDDIR}" \
    && ln -s "${STEAMCMDDIR}/linux32/steamclient.so" "${STEAMCMDDIR}/steamservice.so" \
    && "${STEAMCMDDIR}/steamcmd.sh" +quit \
    && mkdir -p "${HOME}/.steam/sdk32" \
    && ln -s "${STEAMCMDDIR}/linux32/steamclient.so" "${HOME}/.steam/sdk32/steamclient.so" \
    && ln -s "${STEAMCMDDIR}/linux32/steamcmd" "${STEAMCMDDIR}/linux32/steam" \
    && mkdir -p "${HOME}/.steam/sdk64" \
    && ln -s "${STEAMCMDDIR}/linux64/steamclient.so" "${HOME}/.steam/sdk64/steamclient.so" \
    && ln -s "${STEAMCMDDIR}/linux64/steamcmd" "${STEAMCMDDIR}/linux64/steam" \
    && ln -s "${STEAMCMDDIR}/steamcmd.sh" "${STEAMCMDDIR}/steam.sh"

USER ${USER}
