#!/bin/bash
# Builds the preview bundle: Excalidraw's own exportToSvg, bundled for a browser.
#
# These deps are installed --no-save on purpose. Generating a diagram needs only
# elkjs + yaml; this pulls ~200MB of React/Excalidraw/esbuild that only the
# preview needs, and nothing should drag that in by default.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE/.."

echo "→ installing preview deps (not saved to package.json)..."
npm install --no-save --no-audit --no-fund \
  @excalidraw/excalidraw@0.17.6 react@18.2.0 react-dom@18.2.0 esbuild

ESBUILD="node_modules/@esbuild/linux-x64/bin/esbuild"
[ -x "$ESBUILD" ] || ESBUILD="node_modules/.bin/esbuild"

# excalidraw's entry is `if (process.env.NODE_ENV === ...) require(...)`, so the
# defines pick the dist build and the banner keeps `process` defined for any
# reference the defines do not rewrite.
"$ESBUILD" render/entry.js \
  --bundle \
  --outfile=render/bundle.js \
  --banner:js='window.process={env:{NODE_ENV:"production",IS_PREACT:"false"}};' \
  --define:process.env.NODE_ENV='"production"' \
  --define:process.env.IS_PREACT='"false"' \
  --loader:.woff2=dataurl \
  --loader:.ttf=dataurl \
  --loader:.css=text

echo "  preview bundle ready — diagram preview <file.excalidraw>"
