# diagram

Turns a small YAML spec into an **editable Excalidraw file** that is already laid out.

The point is the loop, not the file format: describe a diagram in conversation, get
something you can open and drag around, change the description, regenerate. The layout
is done by [ELK](https://eclipse.dev/elk/) (the layered algorithm behind most decent
architecture diagram tools), so you are not hand-placing boxes and you are not accepting
whatever a text-to-diagram model guessed.

```bash
diagram "$(diagram home)/examples/tenancy.yaml"
# 7 nodes · 2 containers · 6 arrows (12 bound) · 24 text
# /workspace/tmp/diagrams/tenancy.excalidraw
```

`diagram home` prints the install directory, so nothing needs to hard-code where this
repo happens to be cloned.

Open the result in VS Code (the `pomdtr.excalidraw-editor` extension renders `.excalidraw`
as a canvas) or drag it into Excalidraw+.

> **The VS Code extension must be installed on your LOCAL VS Code, not in the
> devcontainer.** It is a UI extension, so installing it from inside the container fails
> with *"declared to not run in this setup"* — and `code --install-extension` exits 0
> anyway, so it looks like it worked. Install it from the Extensions view while the
> window is local, then it works in remote windows too.

## Why not just ask an AI for the JSON

Excalidraw's file format is easy to emit and very hard to emit *well*. The failure is
never invalid JSON — it is twelve boxes in a row with arrows crossing through them.
Everything here exists to separate those two outcomes:

- **ELK does layout**, so node placement and edge routing are solved rather than guessed.
- **A geometry check runs on every build** and exits non-zero: overlapping boxes, arrow
  endpoints adrift of the shape they bind to, labels overflowing their box, edge labels
  sitting on a node, a title struck through by a back-edge. Every rule was added because
  it caught something real.
- **The preview renders with Excalidraw's own `exportToSvg`**, not a lookalike — a
  homegrown renderer would agree with the generator about its own mistakes.
- **Arrows are really bound and elements are really grouped**, so the file behaves
  correctly when you edit it: drag a box and its label follows, its arrows reroute.

## Spec

See `examples/tenancy.yaml`. In short:

```yaml
title: Request-time tenant resolution
subtitle: How a portal request reaches the right tenant DB
theme: light            # light | roe   (roe = brand gold on near-black)
direction: RIGHT        # RIGHT | DOWN | LEFT | UP
roughness: 1            # 0 ruled · 1 hand-drawn · 2 sketchy

groups:
  - { id: backends, label: Backends }

nodes:
  - id: api
    label: rock-of-eye-api
    sub: Laravel 10 · 28 modules
    style: service      # neutral frontend service datastore external actor danger accent
    shape: rect         # rect | sharp | ellipse | diamond
    group: backends

edges:
  - from: aio
    to: api
    label: Bearer + X-ROE-SSO-KEY
    style: solid        # solid | dashed | dotted
    arrow: end          # end | both | none
    emphasis: true      # thicker — reserve for the happy path
```

Output goes to `$DIAGRAM_OUT` (default `/workspace/tmp/diagrams`, which is gitignored).
Override per-run with `-o path.excalidraw`.

## Preview

One-off setup, then a rendered view of any scene:

```bash
npm run build:render                              # ~2 min, pulls excalidraw + esbuild
diagram preview /workspace/tmp/diagrams/foo.excalidraw
# → http://localhost:8765/
```

The preview deps are deliberately **not** in `dependencies` — generating a diagram needs
only `elkjs` and `yaml`.

## Layout notes

- A **back-edge** (B → A when A → B already exists) makes the layout sweep a long arc
  around the whole diagram. Model round trips as one `arrow: both` edge instead.
- **`direction: RIGHT`** suits call/request flows; **`DOWN`** suits hierarchies and state
  machines. A very wide RIGHT diagram usually wants DOWN, not more spacing tuning.
- Text is measured with a per-character width table rather than a real font metric —
  there is no DOM here. Estimates are biased **wide**: a roomy box looks deliberate, a
  clipped label looks broken.
