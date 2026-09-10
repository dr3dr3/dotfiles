import ELK from 'elkjs/lib/elk.bundled.js';
import { resolveTheme, resolveStyle } from './theme.mjs';
import { measureBlock, wrapToWidth, LINE_HEIGHT } from './text.mjs';
import {
  FONT,
  newId,
  shapeOf,
  text,
  arrow,
  bindArrow,
  rectangle,
  scene,
} from './excalidraw.mjs';

const LABEL_SIZE = 16;
const SUB_SIZE = 12;
const EDGE_LABEL_SIZE = 12;
const TITLE_SIZE = 28;
const SUBTITLE_SIZE = 14;
const GROUP_LABEL_SIZE = 14;

const NODE_PAD_X = 22;
const NODE_PAD_Y = 16;
const MIN_NODE_W = 150;
const MIN_NODE_H = 58;
const MAX_LABEL_W = 210;

const GROUP_PAD = { top: 44, left: 22, right: 22, bottom: 22 };

function sizeNode(node) {
  const label = wrapToWidth(node.label ?? node.id, LABEL_SIZE, MAX_LABEL_W);
  const sub = node.sub ? wrapToWidth(node.sub, SUB_SIZE, MAX_LABEL_W) : null;

  const labelBox = measureBlock(label, LABEL_SIZE);
  const subBox = sub ? measureBlock(sub, SUB_SIZE) : { width: 0, height: 0 };

  // A rectangle's usable area is its bounding box; a diamond's is half of it,
  // an ellipse's about 70%. Without this the label of a non-rect node spills
  // out over the stroke — which the geometry check cannot see, because the
  // text IS inside the bounding box.
  const INFLATE = {
    diamond: [1.9, 1.8],
    ellipse: [1.4, 1.35],
  };
  const [fx, fy] = INFLATE[node.shape] ?? [1, 1];

  const gap = sub ? 6 : 0;
  const width = Math.round(
    (Math.max(MIN_NODE_W, labelBox.width, subBox.width) + NODE_PAD_X * 2) * fx,
  );
  const height = Math.round(
    Math.max(MIN_NODE_H, labelBox.height + gap + subBox.height + NODE_PAD_Y * 2) * fy,
  );

  return { ...node, label, sub, width, height, labelBox, subBox, gap };
}

function toElkGraph(spec, nodes, groups) {
  const byGroup = new Map();
  for (const node of nodes) {
    const key = node.group ?? null;
    if (!byGroup.has(key)) byGroup.set(key, []);
    byGroup.get(key).push(node);
  }

  const elkNode = (n) => ({ id: n.id, width: n.width, height: n.height });

  const children = [
    ...(byGroup.get(null) ?? []).map(elkNode),
    ...groups.map((group) => ({
      id: group.id,
      layoutOptions: {
        'elk.padding': `[top=${GROUP_PAD.top},left=${GROUP_PAD.left},bottom=${GROUP_PAD.bottom},right=${GROUP_PAD.right}]`,
      },
      children: (byGroup.get(group.id) ?? []).map(elkNode),
    })),
  ];

  return {
    id: 'root',
    layoutOptions: {
      'elk.algorithm': 'layered',
      'elk.direction': spec.direction ?? 'RIGHT',
      'elk.edgeRouting': spec.routing ?? 'ORTHOGONAL',
      'elk.hierarchyHandling': 'INCLUDE_CHILDREN',
      'elk.layered.nodePlacement.strategy': 'BRANDES_KOEPF',
      'elk.layered.considerModelOrder.strategy': 'NODES_AND_EDGES',
      'elk.spacing.nodeNode': String(spec.spacing?.node ?? 56),
      'elk.layered.spacing.nodeNodeBetweenLayers': String(spec.spacing?.layer ?? 96),
      'elk.spacing.edgeNode': String(spec.spacing?.edgeNode ?? 28),
      'elk.spacing.edgeLabel': '10',
      // Edge labels are emitted at ELK's own computed label position (see the
      // edge loop below), so ELK is left to place them beside the edge in its
      // default way. Forcing CENTER/inline placement here made it reserve a
      // whole empty band between layers for labels it had already found room
      // for — a wide gap in RIGHT diagrams and a very tall one in DOWN.
      'elk.layered.spacing.edgeNodeBetweenLayers': '28',
    },
    children,
    // Every edge is declared on the root graph so ELK reports one consistent
    // coordinate space for the routes. Declaring them on the nearest common
    // ancestor instead makes each section relative to a different container.
    edges: spec.edges.map((edge, i) => ({
      id: `e${i}`,
      sources: [edge.from],
      targets: [edge.to],
      ...(edge.label
        ? {
            labels: [
              {
                text: edge.label,
                width: measureBlock(edge.label, EDGE_LABEL_SIZE).width + 12,
                height: Math.ceil(EDGE_LABEL_SIZE * LINE_HEIGHT) + 6,
              },
            ],
          }
        : {}),
    })),
  };
}

// ELK reports each child's position relative to its parent. Flatten to one
// absolute space so nodes inside a group land in the same coordinates as the
// root-declared edge routes.
function flatten(graph) {
  const positions = new Map();
  const walk = (node, ox, oy) => {
    for (const child of node.children ?? []) {
      const x = ox + (child.x ?? 0);
      const y = oy + (child.y ?? 0);
      positions.set(child.id, { x, y, width: child.width, height: child.height });
      walk(child, x, y);
    }
  };
  walk(graph, 0, 0);
  return positions;
}

export async function build(spec) {
  const theme = resolveTheme(spec.theme);
  const roughness = spec.roughness ?? 1;
  const nodes = (spec.nodes ?? []).map(sizeNode);
  const groups = spec.groups ?? [];

  const known = new Set(nodes.map((n) => n.id));
  for (const edge of spec.edges ?? []) {
    for (const end of [edge.from, edge.to]) {
      if (!known.has(end)) throw new Error(`edge references unknown node "${end}"`);
    }
  }

  const laidOut = await new ELK().layout(toElkGraph(spec, nodes, groups));
  const pos = flatten(laidOut);

  const groupLayer = [];
  const edgeLayer = [];
  const nodeLayer = [];
  const chromeLayer = [];
  const shapes = new Map();

  // --- subsystem containers (drawn first = furthest back) ---
  for (const group of groups) {
    const box = pos.get(group.id);
    if (!box) continue;
    const style = group.style ? resolveStyle(theme, group.style) : null;
    const groupTag = newId();
    const rect = rectangle({
      groupIds: [groupTag],
      x: box.x,
      y: box.y,
      width: box.width,
      height: box.height,
      strokeColor: style?.stroke ?? theme.groupStroke,
      backgroundColor: style?.bg ?? theme.groupFill,
      fillStyle: 'solid',
      strokeStyle: 'dashed',
      strokeWidth: 1,
      roughness,
    });
    groupLayer.push(rect);
    if (group.label) {
      groupLayer.push(
        text({
          text: group.label,
          x: box.x + GROUP_PAD.left,
          y: box.y + 14,
          width: measureBlock(group.label, GROUP_LABEL_SIZE).width,
          fontSize: GROUP_LABEL_SIZE,
          strokeColor: theme.muted,
          groupIds: [groupTag],
        }),
      );
    }
  }

  // --- nodes ---
  for (const node of nodes) {
    const box = pos.get(node.id);
    if (!box) throw new Error(`node "${node.id}" was dropped by layout`);
    const style = resolveStyle(theme, node.style);
    const groupTag = newId();

    const shape = shapeOf(node.shape ?? 'rect', {
      x: box.x,
      y: box.y,
      width: box.width,
      height: box.height,
      strokeColor: style.stroke,
      backgroundColor: style.bg,
      fillStyle: 'solid',
      strokeWidth: 2,
      strokeStyle: node.outline === 'dashed' ? 'dashed' : 'solid',
      roughness,
      groupIds: [groupTag],
      link: node.link ?? null,
    });
    shapes.set(node.id, shape);
    nodeLayer.push(shape);

    // Label and sub-label are grouped siblings rather than one bound label:
    // a bound label is a single text element, so it cannot carry two type
    // sizes. Grouping keeps them moving together when the box is dragged.
    const stackHeight = node.labelBox.height + node.gap + node.subBox.height;
    let cursorY = box.y + (box.height - stackHeight) / 2;

    nodeLayer.push(
      text({
        text: node.label,
        x: box.x + box.width / 2 - node.labelBox.width / 2,
        y: cursorY,
        width: node.labelBox.width,
        fontSize: LABEL_SIZE,
        textAlign: 'center',
        strokeColor: style.stroke,
        groupIds: [groupTag],
      }),
    );

    if (node.sub) {
      cursorY += node.labelBox.height + node.gap;
      nodeLayer.push(
        text({
          text: node.sub,
          x: box.x + box.width / 2 - node.subBox.width / 2,
          y: cursorY,
          width: node.subBox.width,
          fontSize: SUB_SIZE,
          textAlign: 'center',
          strokeColor: theme.muted,
          groupIds: [groupTag],
        }),
      );
    }
  }

  // --- edges (behind the nodes, so any overshoot tucks under the box) ---
  for (const [i, edge] of (spec.edges ?? []).entries()) {
    const route = laidOut.edges?.find((e) => e.id === `e${i}`);
    const section = route?.sections?.[0];
    if (!section) continue;

    // ELK hands an edge to the lowest common ancestor of its endpoints and
    // reports the route relative to THAT container — so an edge between two
    // nodes in the same group comes back in group-local coordinates while a
    // cross-group edge comes back in root coordinates. Re-base both onto the
    // absolute space the shapes were placed in.
    const base = pos.get(route.container) ?? { x: 0, y: 0 };
    const raw = [section.startPoint, ...(section.bendPoints ?? []), section.endPoint].map(
      (p) => ({ x: p.x + base.x, y: p.y + base.y }),
    );
    const origin = raw[0];
    const points = raw.map((p) => [p.x - origin.x, p.y - origin.y]);

    const style = edge.style === 'dotted' ? 'dotted' : edge.style === 'dashed' ? 'dashed' : 'solid';
    const edgeTag = newId();
    const el = arrow({
      x: origin.x,
      y: origin.y,
      points,
      groupIds: [edgeTag],
      strokeColor: edge.color ?? theme.edge,
      strokeWidth: edge.emphasis ? 2.5 : 1.5,
      strokeStyle: style,
      roughness,
      startArrowhead: edge.arrow === 'both' ? 'arrow' : null,
      endArrowhead: edge.arrow === 'none' ? null : 'arrow',
    });
    bindArrow(el, { start: shapes.get(edge.from), end: shapes.get(edge.to) });
    edgeLayer.push(el);

    if (edge.label) {
      const box = measureBlock(edge.label, EDGE_LABEL_SIZE);
      // Deliberately NOT bound to the arrow. A bound label is pinned to the
      // arrow's midpoint, which is not where the layout reserved room for it,
      // so bound labels sit on top of nodes. Placing it at ELK's own label
      // position and grouping it with the arrow keeps the reserved position
      // and still drags the two together.
      const placed = route.labels?.[0];
      const lx = placed ? placed.x + base.x : origin.x;
      const ly = placed ? placed.y + base.y : origin.y;
      edgeLayer.push(
        text({
          text: edge.label,
          x: lx + ((placed?.width ?? box.width) - box.width) / 2,
          y: ly,
          width: box.width,
          fontSize: EDGE_LABEL_SIZE,
          textAlign: 'center',
          strokeColor: edge.color ?? theme.muted,
          groupIds: [edgeTag],
        }),
      );
    }
  }

  // --- title block, placed above the laid-out content ---
  // An arrow's `y` is its FIRST POINT, not the top of its bounding box, so a
  // back-edge that loops upward extends well above its own `y`. Taking `y`
  // as the top is how the title ended up struck through by a return edge.
  const bboxOf = (el) => {
    if (el.type === 'arrow') {
      const ys = el.points.map(([, dy]) => el.y + dy);
      const xs = el.points.map(([dx]) => el.x + dx);
      return { minX: Math.min(...xs), minY: Math.min(...ys) };
    }
    return { minX: el.x, minY: el.y };
  };

  const all = [...groupLayer, ...edgeLayer, ...nodeLayer];
  const boxes = all.map(bboxOf);
  const bounds = boxes.length
    ? {
        minX: Math.min(...boxes.map((b) => b.minX)),
        minY: Math.min(...boxes.map((b) => b.minY)),
      }
    : { minX: 0, minY: 0 };

  if (spec.title) {
    const box = measureBlock(spec.title, TITLE_SIZE);
    chromeLayer.push(
      text({
        text: spec.title,
        x: bounds.minX,
        y: bounds.minY - (spec.subtitle ? 92 : 64),
        width: box.width,
        height: box.height,
        fontSize: TITLE_SIZE,
        strokeColor: theme.ink,
      }),
    );
  }
  if (spec.subtitle) {
    const box = measureBlock(spec.subtitle, SUBTITLE_SIZE);
    chromeLayer.push(
      text({
        text: spec.subtitle,
        x: bounds.minX,
        y: bounds.minY - 44,
        width: box.width,
        height: box.height,
        fontSize: SUBTITLE_SIZE,
        strokeColor: theme.muted,
      }),
    );
  }

  return scene([...groupLayer, ...edgeLayer, ...nodeLayer, ...chromeLayer], {
    background: theme.background,
    name: spec.title ?? 'diagram',
  });
}
