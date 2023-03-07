# For Typescript projects with a build phase
FROM ghcr.io/globaltillopensource/puppeteer-chromium-multi-arch:buildx-latest AS build-stage

# Copy just package.json and package-lock.json
# to speed up the build using Docker layer cache.
COPY --chown=npcuser package*.json ./

# Install all dependencies. Don't audit to speed up the installation.
RUN npm install --include=dev --audit=false

# Next, copy the source files using the user set
# in the base image.
COPY --chown=npcuser . ./

# Install all dependencies and build the project.
# Don't audit to speed up the installation.
RUN npm run build

# Create final image
FROM ghcr.io/globaltillopensource/puppeteer-chromium-multi-arch:buildx-latest as run-stage

# Copy just package.json and package-lock.json
# to speed up the build using Docker layer cache.
COPY --chown=npcuser package*.json ./

USER npcuser

# Install NPM packages, skip optional and development dependencies to
# keep the image small. Avoid logging too much and print the dependency
# tree for debugging
RUN npm install --omit=dev --omit=optional --audit=false \
    && echo "Installed NPM packages:" \
    && (npm list --omit=dev --all || true) \
    && echo "Node version:" \
    && node --version \
    && echo "NPM version:" \
    && npm --version \
    && echo '------------------------'  \
    && echo "Chromium version:" \
    && bash -c "/usr/bin/chromium --version" \
    && npm cache clean --force \
    && rm -r ~/.npm

# Copy built JS files from builder image
COPY --from=0 --chown=npcuser /home/npcuser/dist ./dist

# Next, copy the remaining files and directories with the source code.
# Since we do this after NPM install, build will be quick for most 
# source file changes.
COPY --chown=npcuser . ./

CMD ./start_xvfb_and_run_cmd.sh node dist/main.js
