// Minimal factories for the Excalidraw scene format. Deliberately hand-rolled:
// @excalidraw/excalidraw is a browser/React bundle and pulling it in headless
// just to mint ids and seeds would cost a Chrome instance per diagram.
//
// `index` (the fractional z-index) is intentionally omitted — Excalidraw's own
// restore pass assigns indices in array order on load, so array order IS the
// z-order and we control it by emission order.

import { randomBytes } from 'node:crypto';
import { LINE_HEIGHT } from './text.mjs';

export const FONT = { hand: 1, normal: 2, code: 3 };

const rand = () => randomBytes(4).readUInt32BE(0);

export const newId = () =>
  randomBytes(12).toString('base64url').replace(/[^A-Za-z0-9]/g, 'a').slice(0, 16);

const base = (type, props) => ({
  id: newId(),
  type,
  x: 0,
  y: 0,
  width: 0,
  height: 0,
  angle: 0,
  strokeColor: '#1e1e1e',
  backgroundColor: 'transparent',
  fillStyle: 'solid',
  strokeWidth: 2,
  strokeStyle: 'solid',
  roughness: 1,
  opacity: 100,
  groupIds: [],
  frameId: null,
  roundness: null,
  seed: rand(),
  version: 1,
  versionNonce: rand(),
  isDeleted: false,
  boundElements: null,
  updated: Date.now(),
  link: null,
  locked: false,
  ...props,
});

export function rectangle(props) {
  return base('rectangle', { roundness: { type: 3 }, ...props });
}

export function ellipse(props) {
  return base('ellipse', { roundness: { type: 2 }, ...props });
}

export function diamond(props) {
  return base('diamond', { roundness: { type: 2 }, ...props });
}

export function shapeOf(kind, props) {
  if (kind === 'ellipse') return ellipse(props);
  if (kind === 'diamond') return diamond(props);
  if (kind === 'sharp') return base('rectangle', { roundness: null, ...props });
  return rectangle(props);
}

export function text({ text: value, fontSize = 16, fontFamily = FONT.hand, ...props }) {
  const lines = String(value).split('\n');
  return base('text', {
    text: value,
    originalText: value,
    fontSize,
    fontFamily,
    textAlign: 'left',
    verticalAlign: 'top',
    containerId: null,
    lineHeight: LINE_HEIGHT,
    autoResize: true,
    height: Math.ceil(lines.length * fontSize * LINE_HEIGHT),
    ...props,
  });
}

export function arrow({ points, ...props }) {
  const xs = points.map((p) => p[0]);
  const ys = points.map((p) => p[1]);
  return base('arrow', {
    width: Math.max(...xs) - Math.min(...xs),
    height: Math.max(...ys) - Math.min(...ys),
    points,
    roundness: { type: 2 },
    startBinding: null,
    endBinding: null,
    startArrowhead: null,
    endArrowhead: 'arrow',
    elbowed: false,
    ...props,
  });
}

// Two-way wiring: a bound label needs `containerId` on the text AND an entry in
// the container's `boundElements`. Miss either half and Excalidraw silently
// renders the label as a free-floating text element that no longer moves with
// its shape — which looks fine in a screenshot and falls apart on first drag.
export function bind(container, child) {
  child.containerId = container.id;
  container.boundElements = [
    ...(container.boundElements ?? []),
    { id: child.id, type: child.type },
  ];
}

export function bindArrow(arrowEl, { start, end }) {
  if (start) {
    arrowEl.startBinding = { elementId: start.id, focus: 0, gap: 4 };
    start.boundElements = [
      ...(start.boundElements ?? []),
      { id: arrowEl.id, type: 'arrow' },
    ];
  }
  if (end) {
    arrowEl.endBinding = { elementId: end.id, focus: 0, gap: 4 };
    end.boundElements = [
      ...(end.boundElements ?? []),
      { id: arrowEl.id, type: 'arrow' },
    ];
  }
}

export function scene(elements, { background = '#ffffff', name = 'diagram' } = {}) {
  return {
    type: 'excalidraw',
    version: 2,
    source: 'roe-diagram',
    name,
    elements,
    appState: {
      gridSize: null,
      gridStep: 5,
      gridModeEnabled: false,
      viewBackgroundColor: background,
    },
    files: {},
  };
}
