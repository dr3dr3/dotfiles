#!/bin/bash
# Installs the `diagram` tool: deps, a launcher on PATH, and the VS Code
# Excalidraw editor so .excalidraw files open as a canvas rather than as JSON.
#
# Safe to re-run. Called from the repo's top-level install.sh.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v node >/dev/null 2>&1; then
  echo "  diagram: no node on PATH — skipping (needs Node 18+)"
  exit 0
fi

echo "→ Installing diagram tool..."
(cd "$HERE" && npm install --silent --no-audit --no-fund) || {
  echo "  diagram: npm install failed — the tool will not run"
  exit 0
}

# Launcher on PATH. A wrapper rather than a symlink so the script always
# resolves its own node_modules regardless of where it is invoked from.
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/diagram" <<EOF
#!/bin/bash
exec node "$HERE/bin/diagram.mjs" "\$@"
EOF
chmod +x "$HOME/.local/bin/diagram"

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "  note: \$HOME/.local/bin is not on PATH — add it to use \`diagram\` directly" ;;
esac

# VS Code extension: renders .excalidraw files as an editable canvas.
#
# pomdtr.excalidraw-editor is a UI extension — it runs on the LOCAL VS Code, not
# in the remote/devcontainer host. Attempting it from inside the container fails
# with "declared to not run in this setup", and `code --install-extension` still
# exits 0 when it does, so this deliberately checks the extension list rather
# than the exit code.
if command -v code >/dev/null 2>&1; then
  if code --list-extensions 2>/dev/null | grep -qix "pomdtr.excalidraw-editor"; then
    echo "  excalidraw editor extension present"
  else
    code --install-extension pomdtr.excalidraw-editor --force >/dev/null 2>&1 || true
    if code --list-extensions 2>/dev/null | grep -qix "pomdtr.excalidraw-editor"; then
      echo "  installed VS Code extension pomdtr.excalidraw-editor"
    else
      echo "  NOTE: install the Excalidraw editor on your LOCAL VS Code, not in the container:"
      echo "        Extensions view -> search 'Excalidraw' (pomdtr) -> Install."
      echo "        It is a UI extension, so it cannot be installed from in here."
    fi
  fi
fi

echo "  diagram ready — try: diagram $HERE/examples/tenancy.yaml"
