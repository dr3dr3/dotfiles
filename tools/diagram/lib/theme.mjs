// Named styles map onto Excalidraw's own colour picker values, so anything the
// generator draws can be re-picked by hand in the editor without hunting for a
// hex that isn't in the palette.

const swatch = (stroke, bg) => ({ stroke, bg });

export const THEMES = {
  light: {
    background: '#ffffff',
    ink: '#1e1e1e',
    muted: '#5c5f66',
    groupStroke: '#adb5bd',
    groupFill: '#f8f9fa',
    edge: '#495057',
    styles: {
      neutral: swatch('#1e1e1e', '#f1f3f5'),
      frontend: swatch('#6741d9', '#e5dbff'),
      service: swatch('#1971c2', '#d0ebff'),
      datastore: swatch('#2f9e44', '#d3f9d8'),
      external: swatch('#495057', '#e9ecef'),
      actor: swatch('#f08c00', '#fff3bf'),
      danger: swatch('#e03131', '#ffe3e3'),
      accent: swatch('#0c8599', '#c5f6fa'),
    },
  },

  // Rock of Eye brand register: gold on near-black. Deliberately restrained —
  // one accent, everything else in greys, because gold on gold reads as mud.
  roe: {
    background: '#14110e',
    ink: '#f5f1e8',
    muted: '#9c948a',
    groupStroke: '#4a423a',
    groupFill: '#1c1814',
    edge: '#8a8178',
    styles: {
      neutral: swatch('#c9c2b8', '#26211c'),
      frontend: swatch('#ac9250', '#2a2318'),
      service: swatch('#d4bd85', '#241f18'),
      datastore: swatch('#8fae8b', '#1b211b'),
      external: swatch('#7d766d', '#1f1c19'),
      actor: swatch('#c9a227', '#292314'),
      danger: swatch('#c25b52', '#271a19'),
      accent: swatch('#7fb0b8', '#182022'),
    },
  },
};

export function resolveTheme(name) {
  const theme = THEMES[name] ?? THEMES.light;
  if (!THEMES[name] && name) {
    console.warn(`[diagram] unknown theme "${name}", falling back to light`);
  }
  return theme;
}

export function resolveStyle(theme, name) {
  if (!name) return theme.styles.neutral;
  const style = theme.styles[name];
  if (!style) {
    console.warn(
      `[diagram] unknown style "${name}" — known: ${Object.keys(theme.styles).join(', ')}`,
    );
    return theme.styles.neutral;
  }
  return style;
}
