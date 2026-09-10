// Geometric sanity check on a generated scene, run automatically after every
// build. It is independent of any renderer: it asks whether the numbers
// describe a diagram a human would call correct.
//
// This is the part that earns its keep. A generator that emits valid JSON and
// a generator that emits a READABLE diagram look identical from the outside —
// both exit 0 and produce a file. Every rule below was added because it caught
// something real.

const rect = (e) => ({ x1: e.x, y1: e.y, x2: e.x + e.width, y2: e.y + e.height });

const overlap = (a, b) =>
  a.x1 < b.x2 - 1 && b.x1 < a.x2 - 1 && a.y1 < b.y2 - 1 && b.y1 < a.y2 - 1;

// An arrow's x/y is its FIRST POINT, not the top-left of its bounding box, so
// a back-edge that loops upward extends well above its own y.
const fullBox = (e) => {
  if (e.type !== 'arrow') return rect(e);
  const xs = e.points.map(([dx]) => e.x + dx);
  const ys = e.points.map(([, dy]) => e.y + dy);
  return {
    x1: Math.min(...xs),
    y1: Math.min(...ys),
    x2: Math.max(...xs),
    y2: Math.max(...ys),
  };
};

const distToRect = (px, py, r) =>
  Math.hypot(Math.max(r.x1 - px, 0, px - r.x2), Math.max(r.y1 - py, 0, py - r.y2));

export function verify(scene) {
  const byId = new Map(scene.elements.map((e) => [e.id, e]));
  const shapes = scene.elements.filter((e) =>
    ['rectangle', 'ellipse', 'diamond'].includes(e.type),
  );
  const nodes = shapes.filter((e) => e.strokeWidth === 2);
  const containers = shapes.filter((e) => e.strokeWidth === 1);
  const arrows = scene.elements.filter((e) => e.type === 'arrow');
  const texts = scene.elements.filter((e) => e.type === 'text');
  const problems = [];

  // 1. no two node boxes may overlap
  for (let i = 0; i < nodes.length; i++)
    for (let j = i + 1; j < nodes.length; j++)
      if (overlap(rect(nodes[i]), rect(nodes[j])))
        problems.push(`node boxes overlap: ${nodes[i].id} / ${nodes[j].id}`);

  // 2. every arrow endpoint must land on the shape it claims to be bound to.
  //    Catches the layout engine reporting a route in a different coordinate
  //    space from the one the shapes were placed in.
  let bindings = 0;
  for (const a of arrows) {
    const abs = a.points.map(([dx, dy]) => [a.x + dx, a.y + dy]);
    for (const [pt, binding] of [
      [abs[0], a.startBinding],
      [abs.at(-1), a.endBinding],
    ]) {
      if (!binding) continue;
      bindings++;
      const target = byId.get(binding.elementId);
      if (!target) {
        problems.push(`arrow ${a.id} is bound to an element that is not in the scene`);
        continue;
      }
      const d = distToRect(pt[0], pt[1], rect(target));
      if (d > 24)
        problems.push(`an arrow endpoint is ${Math.round(d)}px adrift of the shape it binds to`);
    }
  }

  const nodeTags = new Set(nodes.flatMap((n) => n.groupIds));

  // 3. a node's own label must stay inside its box
  for (const t of texts.filter((e) => e.groupIds.length && nodeTags.has(e.groupIds[0]))) {
    const parent = nodes.find((n) => n.groupIds[0] === t.groupIds[0]);
    if (!parent) continue;
    const p = rect(parent);
    const head = t.text.split('\n')[0];
    if (t.x < p.x1 - 1 || t.x + t.width > p.x2 + 1)
      problems.push(`label "${head}" overflows its box horizontally`);
    if (t.y < p.y1 - 1 || t.y + t.height > p.y2 + 1)
      problems.push(`label "${head}" overflows its box vertically`);
  }

  // 4. the title block must clear everything the layout produced
  const chrome = texts.filter(
    (e) => !e.containerId && !e.groupIds.length && e.fontSize >= 14,
  );
  for (const t of chrome)
    for (const other of scene.elements)
      if (other !== t && other.type !== 'text' && overlap(rect(t), fullBox(other)))
        problems.push(`title text "${t.text}" collides with a ${other.type}`);

  // 5. edge labels must not sit on top of a node box
  for (const t of texts.filter((e) => e.groupIds.length && !nodeTags.has(e.groupIds[0])))
    for (const n of nodes)
      if (overlap(rect(t), rect(n)))
        problems.push(`edge label "${t.text}" overlaps a node box`);

  // 6. a node must be fully inside its container, or fully outside it
  for (const c of containers) {
    const cr = rect(c);
    for (const n of nodes) {
      const nr = rect(n);
      const inside = nr.x1 >= cr.x1 && nr.x2 <= cr.x2 && nr.y1 >= cr.y1 && nr.y2 <= cr.y2;
      if (overlap(nr, cr) && !inside)
        problems.push(`node ${n.id} straddles the edge of a container`);
    }
  }

  return {
    problems,
    counts: {
      nodes: nodes.length,
      containers: containers.length,
      arrows: arrows.length,
      bindings,
      texts: texts.length,
    },
  };
}
