#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_ROOT="$ROOT_DIR/.tmp/template-package"
NPM_CACHE_DIR="$ROOT_DIR/.tmp/npm-cache"
DEFAULT_CLI_VERSION="$(cat "$ROOT_DIR/topogram-cli.version")"
CLI_PACKAGE_SPEC="${TOPOGRAM_CLI_PACKAGE_SPEC:-@topogram/cli@$DEFAULT_CLI_VERSION}"
STARTER_CLI_PACKAGE_SPEC="$CLI_PACKAGE_SPEC"
if [[ "$STARTER_CLI_PACKAGE_SPEC" == @topogram/cli@* ]]; then
  STARTER_CLI_PACKAGE_SPEC="${STARTER_CLI_PACKAGE_SPEC#@topogram/cli@}"
fi

mkdir -p "$WORK_ROOT" "$NPM_CACHE_DIR"
export npm_config_cache="$NPM_CACHE_DIR"

RUN_DIR="$(mktemp -d "$WORK_ROOT/run.XXXXXX")"
PACK_DIR="$RUN_DIR/pack"
CONSUMER_DIR="$RUN_DIR/consumer"
mkdir -p "$PACK_DIR" "$CONSUMER_DIR"

echo "Checking release metadata..."
"$ROOT_DIR/scripts/check-release-version.sh"

GENERATOR_OVERRIDES_JSON="{}"
if [[ -n "${TOPOGRAM_GENERATOR_PACKAGE_ROOTS:-}" ]]; then
  GENERATOR_OVERRIDES_JSON="$(node --input-type=module - "$PACK_DIR" "$TOPOGRAM_GENERATOR_PACKAGE_ROOTS" <<'NODE'
import childProcess from "node:child_process";
import fs from "node:fs";
import path from "node:path";
const packDir = process.argv[2];
const roots = process.argv[3].split(path.delimiter).filter(Boolean);
const overrides = {};
for (const root of roots) {
  const pkg = JSON.parse(fs.readFileSync(path.join(root, "package.json"), "utf8"));
  const result = childProcess.spawnSync("npm", ["pack", "--silent", "--pack-destination", packDir], {
    cwd: root,
    encoding: "utf8",
    env: { ...process.env, PATH: process.env.PATH || "" }
  });
  if (result.status !== 0) {
    throw new Error([`npm pack failed for ${root}`, result.stdout, result.stderr].filter(Boolean).join("\n"));
  }
  const tarball = result.stdout.trim().split(/\r?\n/).filter(Boolean).at(-1);
  overrides[pkg.name] = `file:${path.join(packDir, tarball)}`;
}
process.stdout.write(JSON.stringify(overrides));
NODE
)"
fi

PACK_SOURCE_DIR="$ROOT_DIR"
if [[ "$GENERATOR_OVERRIDES_JSON" != "{}" ]]; then
  PACK_SOURCE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/topogram-template-source.XXXXXX")"
  node --input-type=module - "$ROOT_DIR" "$PACK_SOURCE_DIR" "$GENERATOR_OVERRIDES_JSON" <<'NODE'
import fs from "node:fs";
import path from "node:path";
const source = process.argv[2];
const target = process.argv[3];
const overrides = JSON.parse(process.argv[4]);
fs.rmSync(target, { recursive: true, force: true });
fs.cpSync(source, target, {
  recursive: true,
  filter(filePath) {
    const relative = path.relative(source, filePath);
    return !relative.split(path.sep).some((segment) => segment === ".git" || segment === ".tmp" || segment === "node_modules");
  }
});
const packagePath = path.join(target, "package.json");
const pkg = JSON.parse(fs.readFileSync(packagePath, "utf8"));
for (const sectionName of ["dependencies", "devDependencies"]) {
  const section = pkg[sectionName];
  if (!section || typeof section !== "object") continue;
  for (const [name, spec] of Object.entries(overrides)) {
    if (Object.prototype.hasOwnProperty.call(section, name)) section[name] = spec;
  }
}
fs.writeFileSync(packagePath, `${JSON.stringify(pkg, null, 2)}\n`, "utf8");
NODE
fi

echo "Packing @topogram/template-todo..."
PACK_NAME="$(cd "$PACK_SOURCE_DIR" && npm pack --silent --pack-destination "$PACK_DIR" | tail -n 1)"
TEMPLATE_TARBALL="$PACK_DIR/$PACK_NAME"

if [[ ! -f "$TEMPLATE_TARBALL" ]]; then
  echo "Expected template tarball was not created: $TEMPLATE_TARBALL" >&2
  exit 1
fi

if tar -tzf "$TEMPLATE_TARBALL" | awk -F/ '{ print $NF }' | grep -E '^(\.env.*|\.npmrc|\.DS_Store|.*\.(pem|key|p8|p12|pfx)|id_(rsa|dsa|ecdsa|ed25519)(\.pub)?|secrets\..*|credentials\..*)$' >/tmp/topogram-template-env-files.$$; then
  echo "Template package must not publish restricted local or secret files:" >&2
  cat /tmp/topogram-template-env-files.$$ >&2
  rm -f /tmp/topogram-template-env-files.$$
  exit 1
fi
rm -f /tmp/topogram-template-env-files.$$

echo "Installing Topogram CLI ($CLI_PACKAGE_SPEC) into a consumer project..."
(
	  cd "$CONSUMER_DIR"
	  npm init -y >/dev/null
	  npm install "$CLI_PACKAGE_SPEC" >/dev/null
	)

TOPOGRAM_BIN="$CONSUMER_DIR/node_modules/.bin/topogram"
if [[ ! -x "$TOPOGRAM_BIN" ]]; then
  echo "Expected topogram binary was not installed: $TOPOGRAM_BIN" >&2
  exit 1
fi
VERSION_JSON="$("$TOPOGRAM_BIN" version --json)"
node --input-type=module - "$VERSION_JSON" "$CLI_PACKAGE_SPEC" "${EXPECTED_TOPOGRAM_CLI_VERSION:-}" <<'NODE'
const payload = JSON.parse(process.argv[2]);
const packageSpec = process.argv[3];
const explicitExpected = process.argv[4] || "";
const inferred = packageSpec.startsWith("@topogram/cli@")
  ? packageSpec.slice("@topogram/cli@".length)
  : "";
const expected = explicitExpected || (/^\d+\.\d+\.\d+/.test(inferred) ? inferred : "");
if (payload.packageName !== "@topogram/cli") {
  throw new Error(`Expected @topogram/cli, got ${payload.packageName}`);
}
if (expected && payload.version !== expected) {
  throw new Error(`Expected Topogram CLI ${expected}, got ${payload.version}`);
}
if (!payload.executablePath || !payload.nodeVersion) {
  throw new Error("Expected executablePath and nodeVersion in topogram version output.");
}
console.log(`Using Topogram CLI ${payload.version} from ${payload.executablePath}`);
NODE

echo "Checking template conformance..."
(
  cd "$CONSUMER_DIR"
  "$TOPOGRAM_BIN" template check "$TEMPLATE_TARBALL"
)

echo "Creating a starter from the packed template..."
(
  cd "$CONSUMER_DIR"
  TOPOGRAM_CLI_PACKAGE_SPEC="$STARTER_CLI_PACKAGE_SPEC" "$TOPOGRAM_BIN" new ./starter --template "$TEMPLATE_TARBALL"
)

STARTER_DIR="$CONSUMER_DIR/starter"
if [[ ! -f "$STARTER_DIR/package.json" ]]; then
  echo "Expected starter package.json was not created." >&2
  exit 1
fi

node --input-type=module - "$STARTER_DIR/package.json" <<'NODE'
import fs from "node:fs";
const packagePath = process.argv[2];
const pkg = JSON.parse(fs.readFileSync(packagePath, "utf8"));
if (pkg.scripts?.["component:behavior:query"] !== "topogram query component-behavior ./topogram --projection proj_ui_web --json") {
  throw new Error("Expected Todo starter package.json to expose component:behavior:query.");
}
if (pkg.scripts?.["query:show"] !== "topogram query show") {
  throw new Error("Expected Todo starter package.json to expose query:show.");
}
NODE

echo "Installing starter dependencies..."
npm --prefix "$STARTER_DIR" install >/dev/null

echo "Checking and generating the starter..."
npm --prefix "$STARTER_DIR" run doctor
npm --prefix "$STARTER_DIR" run query:list
npm --prefix "$STARTER_DIR" run query:show -- component-behavior
npm --prefix "$STARTER_DIR" run source:status
npm --prefix "$STARTER_DIR" run template:detach:dry-run
npm --prefix "$STARTER_DIR" run check
npm --prefix "$STARTER_DIR" run component:behavior:query
npm --prefix "$STARTER_DIR" run generate
npm --prefix "$STARTER_DIR/app" run compile

if [[ ! -f "$STARTER_DIR/app/.topogram-generated.json" ]]; then
  echo "Expected generated app sentinel was not written." >&2
  exit 1
fi

echo
echo "Template package smoke passed: $TEMPLATE_TARBALL"
