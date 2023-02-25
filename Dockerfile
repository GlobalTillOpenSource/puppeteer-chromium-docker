ARG ARCH=
ARG NODE_VERSION=16
FROM ${ARCH}node:${NODE_VERSION}-bullseye-slim AS prep-stage

LABEL maintainer="dev@ops.globaltill.com"
LABEL Description="Multiarch image for Puppeteer using headless Chromium"
LABEL org.opencontainers.image.source=https://github.com/GlobalTillOpenSource/puppeteer-chromium-docker.git
LABEL org.opencontainers.image.source = "https://github.com/GlobalTillOpenSource/puppeteer-chromium-docker"
LABEL org.opencontainers.image.title="Puppeteer + Chromium"
LABEL org.opencontainers.image.description="Multiarch image for headless Chromium/Puppeteer using Debian Node 16"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.vendor="GlobalTill OSS"
LABEL org.opencontainers.image.authors="GlobalTill DevOps"

ARG PUPPETEER_SKIP_DOWNLOAD=true
ARG NODE_ENV=production

COPY 01_nodoc /etc/dpkg/dpkg.cfg.d/

# Install latest Chrome dev packages and select fonts
RUN set -ex \
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
    xvfb \
    chromium \
    && apt-get -y clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /src/*.deb \
    && mkdir -p /tmp/.X11-unix \
    && chmod 1777 /tmp/.X11-unix

RUN echo $(dpkg -L chromium)
RUN echo $(/usr/bin/chromium --version)

# Prepare to install the latest Chrome compatible
RUN mkdir -p /tmp/install
WORKDIR /tmp/install
# COPY package.json puppeteer_*.js /tmp/install/


# TODO npm version needs to be templated
RUN npm config --global set update-notifier false \
    && npm config --global set progress false \
    && npm install -g npm@9.5.1


# Copy source code and xvfb script

FROM prep-stage as run-stage

# Add user so we don't need --no-sandbox.
RUN groupadd -r npcuser && useradd -r -g npcuser -G audio,video npcuser \
    && mkdir -p /home/npcuser/Downloads \
    && chown -R npcuser:npcuser /home/npcuser

COPY --chown=npcuser:npcuser package.json puppeteer_*.js start_xvfb_and_run_cmd.sh healthcheck.js /home/npcuser/

# Run everything after as non-privileged user (npcuser)
USER npcuser
WORKDIR /home/npcuser

# As of February 2023 there is no arm64 chromium build, so we need to skip the download.
ARG PUPPETEER_SKIP_DOWNLOlsAD=true

# Path to Chromium/Chrome executable, used by launchPuppeteer()
ARG PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Tell Node this is a production environemnt
ENV NODE_ENV=production

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
ENV NODE_OPTIONS="--max-old-space-size=32768 --max-http-header-size=65536"

# COPY  --from=builder --chown=npcuser:npcuser package.json puppeteer_*.js start_xvfb_and_run_cmd.sh healthcheck.js /home/npcuser/
# COPY --chown=npcuser:npcuser package.json puppeteer_*.js start_xvfb_and_run_cmd.sh healthcheck.js /home/npcuser/

RUN mkdir -p /home/npcuser/.config/chromium/Crash Reports/pending

# Install all dependencies. Don't audit to speed up the installation.
RUN npm --quiet set progress=false \
    && npm install --omit=dev --omit=optional --audit=false --prefer-online --no-package-lock \
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
    && npm cache clean --force \
    && rm -r ~/.npm


# Set up xvfb
ENV DISPLAY=:99
ENV XVFB_WHD=1920x1080x24+32

# Using CMD instead of ENTRYPOINT, to allow manual overriding.
CMD ["/home/npcuser/start_xvfb_and_run_cmd.sh", "node", "src/main.js" ]

# https://adambrodziak.pl/dockerfile-good-practices-for-node-and-npm
# Execute NodeJS (not NPM script) to handle SIGTERM and SIGINT signals.
# CMD ["node", "./src/index.js"]
