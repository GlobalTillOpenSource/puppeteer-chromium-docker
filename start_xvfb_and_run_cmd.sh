#!/bin/bash
set -euo pipefail

echo "Starting X virtual framebuffer using: Xvfb $DISPLAY -ac -screen 0 $XVFB_WHD -nolisten tcp"
Xvfb $DISPLAY -ac -screen 0 $XVFB_WHD -nolisten tcp &

exec xvfb-run -a --server-args="-screen 0 1280x800x24 -ac -nolisten tcp -dpi 96 +extension RANDR" "$@"