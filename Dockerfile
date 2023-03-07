ARG ARCH=
ARG NODE_VERSION=18
FROM ${ARCH}node:${NODE_VERSION}-bullseye-slim

LABEL maintainer="dev@ops.globaltill.com"
LABEL Description="Multiarch image for Puppeteer using headless Chromium"
LABEL org.opencontainers.image.source=https://github.com/GlobalTillOpenSource/puppeteer-chromium-docker.git
LABEL org.opencontainers.image.source = "https://github.com/GlobalTillOpenSource/puppeteer-chromium-docker"
LABEL org.opencontainers.image.title="Puppeteer + Chromium"
LABEL org.opencontainers.image.description="Multiarch image for headless Chromium/Puppeteer using Debian Node 16"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.vendor="GlobalTill OSS"
LABEL org.opencontainers.image.authors="GlobalTill DevOps"

ARG DEFAULT_PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_SKIP_DOWNLOAD=$DEFAULT_PUPPETEER_SKIP_DOWNLOAD

ARG DEFAULT_NODE_ENV=true
ENV NODE_ENV=$DEFAULT_NODE_ENV

ARG DEFAULT_USER=npcuser
ENV USER=$DEFAULT_USER

ARG DEFAULT_PUPPETEER_EXECUTABLE_PATH="/usr/lib/chromium/chromium"
ENV PUPPETEER_EXECUTABLE_PATH=$DEFAULT_PUPPETEER_EXECUTABLE_PATH


COPY 01_nodoc /etc/dpkg/dpkg.cfg.d/


# Install latest Chrome dev packages and select fonts
RUN set -eux \
    && sh -c 'echo "deb http://deb.debian.org/debian bullseye main contrib non-free" > /etc/apt/sources.list' \
    && sh -c 'echo "deb http://deb.debian.org/debian bullseye-updates main contrib non-free" >> /etc/apt/sources.list' \
    && sh -c 'echo "deb http://security.debian.org/debian-security/ bullseye-security main contrib non-free" >> /etc/apt/sources.list' \
    && DEBIAN_FRONTEND=noninteractive apt-get -y update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
    fonts-freefont-ttf \
    fonts-ipafont-gothic \
    fonts-kacst \
    fonts-liberation \
    fonts-dejavu \
    fonts-noto \
    git \
    libxss1 \
    lsb-release \
    procps \
    xdg-utils \
    xauth \
    xvfb \
    xorg \
    dbus-x11 \
    chromium \
    chromium-sandbox \
    && apt-get -y clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /src/*.deb \
    && mkdir -p /tmp/.X11-unix \
    && chmod 1777 /tmp/.X11-unix

# TODO npm version needs to be templated
RUN npm config --global set update-notifier false \
    && npm config --global set progress false \
    && npm install -g npm@9.5.1

RUN mkdir -p /tmp/build
WORKDIR /tmp/build

COPY package.json puppeteer_*.js /tmp/build/

# Add user so we don't need --no-sandbox.
RUN groupadd -r $USER && useradd -r -g $USER -G audio,video $USER \
    && mkdir -p /home/$USER/Downloads \
    && chown -R $USER:$USER /home/$USER


# Copy just package.json and package-lock.json
# to speed up the build using Docker layer cache.
COPY --chown=$USER package*.json ./

# Install default dependencies
RUN npm --quiet set progress=false \
    && npm install --only=prod --no-optional --no-package-lock --prefer-online --audit=false

# Run everything after as non-privileged user ($USER)
USER $USER
WORKDIR /home/$USER

# Copy source code and xvfb script
COPY --chown=$USER:$USER package.json puppeteer_*.js start_xvfb_and_run_cmd.sh /home/$USER/

# We use wildcards so Docker doesn't get annoyed when a file doesn't exist. And
# we make sure there's always at least one file copied, otherwise the `docker
# build` fails.
# COPY requirements.tx[t] pyproject.tom[l] poetry.loc[k] Pipfile* \
#      dev-requirements.tx[t] \
#      docker-shared/install-py-dependencies.py \
#      docker-config/custom-install-py-dependencies.sh \
#      ./

# As of February 2023 there is no arm64 chromium build, so we need to skip the download.
ARG PUPPETEER_SKIP_DOWNLOAD=true

# max-old-space-size (64-bit systems)

# Node Version      Limit
#----------------- -------
#  18.x             4.0 GB
#  17.x             4.0 GB
#  16.x             4.0 GB
#  15.x             4.0 GB
#  14.x             4.0 GB
#  13.x             2.0 GB
#  12.x             2.0 GB
#  11.x             1.4 GB
#  10.x             1.4 GB
#  9.x              1.4 GB

# --max-old-space-size <number> Sets the V8 JavaScript heap size limit in MB.
# Increasing the value prevents the process from crashing due to out of memory errors.

# max-http-header-size

# Node Version      Limit
#----------------- -----------------------------
#  13.13.0          Changed from 8 KiB to 16 KiB
#  11.6.0           Added in: v11.6.0
#  10.15.0          Added in: v10.15.0

# --max-http-header-size <number> Optionally overrides the value of --max-http-header-size
# for requests received by this server, i.e. the maximum length of request headers in bytes.

# Set Node memory limit 32 GB and max http header size 64 KB
ARG DEFAULT_NODE_OPTIONS="--max-old-space-size=32768 --max-http-header-size=65536"
ENV NODE_OPTIONS=$DEFAULT_NODE_OPTIONS

COPY --chown=$USER:$USER package*.json puppeteer_*.js start_xvfb_and_run_cmd.sh /home/$USER/

# Install all dependencies. Don't audit to speed up the installation.
RUN npm install --omit=dev --omit=optional --audit=false --prefer-online --no-package-lock \
    && echo "Installed NPM packages:" \
    && (npm list --omit=dev --all || true) \
    && echo "Node version:" \
    && node --version \
    && echo "NPM version:" \
    && npm --version \
    && echo '------------------------'  \
    && echo "Chromium version:" \
    && bash -c "/usr/bin/chromium --version" \
    && echo "Debian version:" \
    && cat /etc/debian_version \
    && echo "Debian release info:" \
    && echo $(lsb_release -a) \
    && echo "Chromium version:" \
    && bash -c "$PUPPETEER_EXECUTABLE_PATH --version" \
    && npm cache clean --force \
    && rm -r ~/.npm

# Set up xvfb
ENV DISPLAY=:99
ENV XVFB_WHD=1920x1080x24+32

RUN chmod +x start_xvfb_and_run_cmd.sh


CMD ./start_xvfb_and_run_cmd.sh node src/main.js
