############################################################
# Dockerfile that contains SteamCMD
############################################################
FROM debian:bookworm-slim as build_stage

LABEL maintainer="walentinlamonos@gmail.com"
ARG PUID=1000

ENV USER steam
ENV HOMEDIR "/home/${USER}"
ENV STEAMCMDDIR "${HOMEDIR}/steamcmd"

# renovate: datasource=repology versioning=deb depName=debian_12/lib32stdc++6
ENV LIB32STDCPP__6_VERSION=12.2.0-14
# renovate: datasource=repology versioning=deb depName=debian_12/lib32gcc-s1
ENV LIB32GCC_S1_VERSION=12.2.0-14
# renovate: datasource=repology versioning=deb depName=debian_12/ca-certificates
ENV CA_CERTIFICATES_VERSION=20230311
# renovate: datasource=repology versioning=deb depName=debian_12/nano
ENV NANO_VERSION=7.2-1
# renovate: datasource=repology versioning=deb depName=debian_12/curl
ENV CURL_VERSION=7.88.1-10+deb12u5
# renovate: datasource=repology versioning=deb depName=debian_12/locales
ENV LOCALES_VERSION=2.36-9+deb12u4

RUN set -x \
    # Install, update & upgrade packages
    && apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests \
        lib32stdc++6=${LIB32STDCPP__6_VERSION} \
        lib32gcc-s1=${LIB32GCC_S1_VERSION} \
        ca-certificates=${CA_CERTIFICATES_VERSION} \
        nano=${NANO_VERSION} \
        curl=${CURL_VERSION} \
        locales=${LOCALES_VERSION} \
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && dpkg-reconfigure --frontend=noninteractive locales \
    # Create unprivileged user
    && useradd -u "${PUID}" -m "${USER}" \
    # Download SteamCMD, execute as user
    && su "${USER}" -c \
        "mkdir -p \"${STEAMCMDDIR}\" \
        && curl -fsSL 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz' | tar xvzf - -C \"${STEAMCMDDIR}\" \
        && \"./${STEAMCMDDIR}/steamcmd.sh\" +quit \
        && ln -s \"${STEAMCMDDIR}/linux32/steamclient.so\" \"${STEAMCMDDIR}/steamservice.so\" \
        && mkdir -p \"${HOMEDIR}/.steam/sdk32\" \
        && ln -s \"${STEAMCMDDIR}/linux32/steamclient.so\" \"${HOMEDIR}/.steam/sdk32/steamclient.so\" \
        && ln -s \"${STEAMCMDDIR}/linux32/steamcmd\" \"${STEAMCMDDIR}/linux32/steam\" \
        && mkdir -p \"${HOMEDIR}/.steam/sdk64\" \
        && ln -s \"${STEAMCMDDIR}/linux64/steamclient.so\" \"${HOMEDIR}/.steam/sdk64/steamclient.so\" \
        && ln -s \"${STEAMCMDDIR}/linux64/steamcmd\" \"${STEAMCMDDIR}/linux64/steam\" \
        && ln -s \"${STEAMCMDDIR}/steamcmd.sh\" \"${STEAMCMDDIR}/steam.sh\"" \
    # Symlink steamclient.so; So misconfigured dedicated servers can find it
    && ln -s "${STEAMCMDDIR}/linux64/steamclient.so" "/usr/lib/x86_64-linux-gnu/steamclient.so" \
    && rm -rf /var/lib/apt/lists/*

FROM build_stage AS bookworm-root
WORKDIR ${STEAMCMDDIR}

FROM bookworm-root AS bookworm
# Switch to user
USER ${USER}
