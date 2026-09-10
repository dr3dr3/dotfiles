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
  if (!existsSync(BUNDLE)) {
    throw new Error(
      `preview bundle missing — run:  cd ${ROOT} && npm run build:render`,
    );
  }

  const assets = join(ROOT, 'node_modules/@excalidraw/excalidraw/dist/excalidraw-assets');

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

  return new Promise((ok) => server.listen(port, () => ok(server)));
}
