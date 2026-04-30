#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_ROOT="$ROOT_DIR/.tmp/template-package"
NPM_CACHE_DIR="$ROOT_DIR/.tmp/npm-cache"
CLI_PACKAGE_SPEC="${TOPOGRAM_CLI_PACKAGE_SPEC:-@attebury/topogram@0.2.41}"

mkdir -p "$WORK_ROOT" "$NPM_CACHE_DIR"
export npm_config_cache="$NPM_CACHE_DIR"

RUN_DIR="$(mktemp -d "$WORK_ROOT/run.XXXXXX")"
PACK_DIR="$RUN_DIR/pack"
CONSUMER_DIR="$RUN_DIR/consumer"
mkdir -p "$PACK_DIR" "$CONSUMER_DIR"

echo "Checking release metadata..."
"$ROOT_DIR/scripts/check-release-version.sh"

echo "Packing @attebury/topogram-template-todo..."
PACK_NAME="$(cd "$ROOT_DIR" && npm pack --silent --pack-destination "$PACK_DIR" | tail -n 1)"
TEMPLATE_TARBALL="$PACK_DIR/$PACK_NAME"

if [[ ! -f "$TEMPLATE_TARBALL" ]]; then
  echo "Expected template tarball was not created: $TEMPLATE_TARBALL" >&2
  exit 1
fi

echo "Installing Topogram CLI ($CLI_PACKAGE_SPEC) into a consumer project..."
(
  cd "$CONSUMER_DIR"
  npm init -y >/dev/null
  npm config set @attebury:registry https://npm.pkg.github.com --location=project
  if [[ -n "${NODE_AUTH_TOKEN:-}" ]]; then
    npm config set //npm.pkg.github.com/:_authToken "$NODE_AUTH_TOKEN" --location=project
  fi
  npm install "$CLI_PACKAGE_SPEC" >/dev/null
)

TOPOGRAM_BIN="$CONSUMER_DIR/node_modules/.bin/topogram"
if [[ ! -x "$TOPOGRAM_BIN" ]]; then
  echo "Expected topogram binary was not installed: $TOPOGRAM_BIN" >&2
  exit 1
fi

echo "Checking template conformance..."
(
  cd "$CONSUMER_DIR"
  "$TOPOGRAM_BIN" template check "$TEMPLATE_TARBALL"
)

echo "Creating a starter from the packed template..."
(
  cd "$CONSUMER_DIR"
  TOPOGRAM_CLI_PACKAGE_SPEC="$CLI_PACKAGE_SPEC" "$TOPOGRAM_BIN" new ./starter --template "$TEMPLATE_TARBALL"
)

STARTER_DIR="$CONSUMER_DIR/starter"
if [[ ! -f "$STARTER_DIR/package.json" ]]; then
  echo "Expected starter package.json was not created." >&2
  exit 1
fi

echo "Installing starter dependencies..."
npm --prefix "$STARTER_DIR" install >/dev/null

echo "Checking and generating the starter..."
npm --prefix "$STARTER_DIR" run check
npm --prefix "$STARTER_DIR" run generate

if [[ ! -f "$STARTER_DIR/app/.topogram-generated.json" ]]; then
  echo "Expected generated app sentinel was not written." >&2
  exit 1
fi

echo
echo "Template package smoke passed: $TEMPLATE_TARBALL"
