#!/usr/bin/env node
// diagram — turn a YAML spec into an Excalidraw scene.
//
//   diagram build   <spec.yaml> [-o out.excalidraw]
//   diagram preview <scene.excalidraw>      (renders it with Excalidraw's own engine)
//
// `build` is the default verb, so `diagram foo.yaml` works.

import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { basename, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from 'yaml';
import { build } from '../lib/build.mjs';
import { verify } from '../lib/verify.mjs';

const HOME = resolve(dirname(fileURLToPath(import.meta.url)), '..');

const USAGE = `usage:
  diagram [build] <spec.yaml> [-o out.excalidraw]   render a spec to an Excalidraw file
  diagram preview <file.excalidraw> [--port 8765]   serve it, rendered by Excalidraw itself
  diagram home                                      print the tool's install directory

Output defaults to \${DIAGRAM_OUT:-/workspace/tmp/diagrams}/<spec name>.excalidraw.
Examples live in ${HOME}/examples.`;

// Fail with a sentence, not a stack trace. Everything below funnels through
// this, because the usual mistakes here are a mistyped path or a YAML typo —
// neither of which deserves a node internals dump.
const die = (msg, hint) => {
  console.error(`diagram: ${msg}`);
  if (hint) console.error(`  ${hint}`);
  process.exit(1);
};

const argv = process.argv.slice(2);
if (!argv.length || argv[0] === '-h' || argv[0] === '--help') {
  console.log(USAGE);
  process.exit(argv.length ? 0 : 1);
}

if (argv[0] === 'home') {
  console.log(HOME);
  process.exit(0);
}

const verb = ['build', 'preview'].includes(argv[0]) ? argv.shift() : 'build';
const flag = (name) => {
  const i = argv.indexOf(name);
  return i !== -1 ? argv[i + 1] : undefined;
};
const positional = argv.filter(
  (a, i) => !a.startsWith('-') && !argv[i - 1]?.startsWith('-'),
);

if (!positional[0]) die(`no file given`, USAGE.split('\n')[1].trim());

if (verb === 'preview') {
  const scene = resolve(positional[0]);
  if (!existsSync(scene)) die(`no such file: ${scene}`);
  const { serve } = await import('../render/serve.mjs');
  const port = Number(flag('--port') ?? 8765);
  await serve(scene, port).catch((e) => die(e.message));
  console.log(`preview → http://localhost:${port}/`);
  console.log('(ctrl-c to stop)');
} else {
  const specPath = resolve(positional[0]);
  if (!existsSync(specPath))
    die(
      `no such spec: ${specPath}`,
      `the tool lives in ${HOME} — try: diagram ${HOME}/examples/tenancy.yaml`,
    );

  const outDir = process.env.DIAGRAM_OUT ?? '/workspace/tmp/diagrams';
  const outPath =
    flag('-o') ??
    resolve(outDir, basename(specPath).replace(/\.ya?ml$/, '') + '.excalidraw');

  let spec;
  try {
    spec = parse(readFileSync(specPath, 'utf8'));
  } catch (e) {
    die(`could not parse ${basename(specPath)}`, e.message.split('\n')[0]);
  }
  if (!spec || typeof spec !== 'object') die(`${basename(specPath)} is empty or not a YAML mapping`);

  const scene = await build(spec).catch((e) => die(e.message));
  mkdirSync(dirname(outPath), { recursive: true });
  writeFileSync(outPath, JSON.stringify(scene, null, 2));

  const { problems, counts } = verify(scene);
  console.log(
    `${counts.nodes} nodes · ${counts.containers} containers · ${counts.arrows} arrows (${counts.bindings} bound) · ${counts.texts} text`,
  );
  console.log(outPath);

  if (problems.length) {
    // Loud on purpose. A geometry problem still produces a file that opens
    // fine — it just looks wrong, which is exactly the failure that slips
    // through unnoticed.
    console.error(`\n${problems.length} layout problem(s):`);
    for (const p of problems) console.error(`  ✗ ${p}`);
    process.exit(1);
  }
}
