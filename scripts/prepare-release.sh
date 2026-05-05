#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
  echo "Usage: npm run release:prepare -- <version>" >&2
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid semver version: $VERSION" >&2
  exit 1
fi

npm version "$VERSION" --no-git-tag-version --allow-same-version >/dev/null

node --input-type=module - "$ROOT_DIR/topogram-template.json" "$VERSION" <<'NODE'
import fs from "node:fs";

const [manifestPath, version] = process.argv.slice(2);
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
manifest.version = version;
fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
NODE

"$ROOT_DIR/scripts/check-release-version.sh"

echo "Prepared @topogram/template-todo@$VERSION"
echo
echo "Next:"
echo "  git add package.json package-lock.json topogram-template.json"
echo "  git commit -m \"Prepare Todo template $VERSION\""
echo "  git tag topogram-template-todo-v$VERSION"
echo "  git push origin main topogram-template-todo-v$VERSION"
