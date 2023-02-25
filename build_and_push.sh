#!/bin/bash
VERSION=$(git log -1 --pretty=%h)
REPO="ghcr.io/globaltillopensource/puppeteer-chromium-multi-arch:"
TAG="$REPO$VERSION"
LATEST="${REPO}buildx-latest"
BUILD_TIMESTAMP=$( date '+%F_%H:%M:%S' )
echo "Building $TAG"
echo "Building $LATEST"
echo "Build timestamp: $BUILD_TIMESTAMP"

# First time only
sudo docker buildx create --name pcmbuilder --platform linux/arm64,linux/amd64 --driver-opt network=host --use --buildkitd-flags '--allow-insecure-entitlement security.insecure'

# Each time
export CR_PAT=''
echo $CR_PAT | sudo docker login ghcr.io -u rexrrr --password-stdin
sudo docker buildx build --builder pcmbuilder --push --platform linux/arm64/v8,linux/amd64 -t "$TAG" -t "$LATEST" --build-arg BUILD_TIMESTAMP="$BUILD_TIMESTAMP" .

