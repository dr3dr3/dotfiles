// Approximate advance widths for Excalifont (fontFamily 1). There is no DOM
// here to measure with, so we bias every estimate WIDE: a box a few pixels too
// roomy looks deliberate, a box that clips its own label looks broken.

const NARROW = new Set([...`ijltfIr!.,:;'"|()[]{}\`-`]);
const WIDE = new Set([...'mMWw@%']);
const CAPS = /[A-Z]/;

const factorFor = (ch) => {
  if (ch === ' ') return 0.3;
  if (NARROW.has(ch)) return 0.34;
  if (WIDE.has(ch)) return 0.92;
  if (CAPS.test(ch)) return 0.68;
  return 0.56;
};

export function measureLine(line, fontSize) {
  let total = 0;
  for (const ch of line) total += factorFor(ch) * fontSize;
  return Math.ceil(total);
}

export function measureBlock(text, fontSize) {
  const lines = String(text).split('\n');
  return {
    width: Math.max(0, ...lines.map((l) => measureLine(l, fontSize))),
    height: Math.ceil(lines.length * fontSize * LINE_HEIGHT),
    lines,
  };
}

export const LINE_HEIGHT = 1.25;

// Greedy wrap to a target pixel width. Used for node labels so a long service
// name becomes two tidy lines instead of one box wider than the diagram.
export function wrapToWidth(text, fontSize, maxWidth) {
  return String(text)
    .split('\n')
    .flatMap((paragraph) => {
      const words = paragraph.split(/\s+/).filter(Boolean);
      if (!words.length) return [''];
      const lines = [];
      let current = words[0];
      for (const word of words.slice(1)) {
        const candidate = `${current} ${word}`;
        if (measureLine(candidate, fontSize) <= maxWidth) current = candidate;
        else {
          lines.push(current);
          current = word;
        }
      }
      lines.push(current);
      return lines;
    })
    .join('\n');
}
