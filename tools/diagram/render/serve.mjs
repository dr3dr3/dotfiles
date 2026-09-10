// Preview harness. Serves one scene file plus a browser bundle of Excalidraw's
// own exportToSvg, so what you look at is rendered by Excalidraw rather than by
// a lookalike of it. That distinction is the whole point: a homegrown renderer
// would agree with the generator about its own mistakes.
//
// The bundle is optional — build it once with `npm run build:render`.

import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { extname, join, normalize, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');
const BUNDLE = join(HERE, 'bundle.js');

const MIME = {
  '.js': 'text/javascript',
  '.html': 'text/html',
  '.json': 'application/json',
  '.excalidraw': 'application/json',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.css': 'text/css',
};

export function serve(scenePath, port = 8765) {
  const assets = join(ROOT, 'node_modules/@excalidraw/excalidraw/dist/excalidraw-assets');

  // Two artifacts with DIFFERENT LIFETIMES, so both are checked.
  //
  // bundle.js is built and survives anything. The fonts live in node_modules and
  // do not: build.sh installs them with `npm install --no-save`, and the repo's
  // installer later runs a plain `npm install`, which prunes whatever is not in
  // package.json. Guarding on the bundle alone therefore reports ready while
  // /assets/* 404s — Excalidraw silently falls back to system fonts, text metrics
  // stop matching the real editor, and the preview quietly lies about whether a
  // label fits. That is the exact failure this tool exists to prevent, so the
  // guard checks the artifact that actually goes missing.
  const missing = [
    !existsSync(BUNDLE) && 'the bundle',
    !existsSync(assets) && 'the Excalidraw fonts',
  ].filter(Boolean);

  if (missing.length) {
    throw new Error(
      `preview is missing ${missing.join(' and ')} — run:  cd ${ROOT} && npm run build:render`,
    );
  }

  const server = createServer(async (req, res) => {
    const url = normalize(decodeURIComponent(req.url.split('?')[0]));
    let path;
    if (url === '/scene.excalidraw') path = scenePath;
    else if (url === '/bundle.js') path = BUNDLE;
    else if (url.startsWith('/assets/')) path = join(assets, url.slice('/assets'.length));
    else path = join(HERE, url === '/' ? 'index.html' : url);

    try {
      const body = await readFile(path);
      res.writeHead(200, {
        'content-type': MIME[extname(path)] ?? 'application/octet-stream',
        'cache-control': 'no-store',
      });
      res.end(body);
    } catch {
      res.writeHead(404).end('not found');
    }
  });

  // Reject rather than let a failed bind become an unhandled 'error' event —
  // that prints a raw node stack, where every other error in this CLI is one
  // sentence from die(). EADDRINUSE is the common case: a preview server
  // outlives the session that started it.
  return new Promise((ok, fail) => {
    server.once('error', (e) =>
      fail(
        e.code === 'EADDRINUSE'
          ? new Error(`port ${port} is already in use — try: diagram preview <file> --port ${port + 1}`)
          : e,
      ),
    );
    server.listen(port, () => ok(server));
  });
}
