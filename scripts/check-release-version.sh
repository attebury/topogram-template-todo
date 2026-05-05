#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_JSON="$ROOT_DIR/package.json"
PACKAGE_LOCK="$ROOT_DIR/package-lock.json"
TEMPLATE_MANIFEST="$ROOT_DIR/topogram-template.json"

node --input-type=module - "$PACKAGE_JSON" "$PACKAGE_LOCK" "$TEMPLATE_MANIFEST" "${EXPECTED_TEMPLATE_VERSION:-}" "${GITHUB_REF_TYPE:-}" "${GITHUB_REF_NAME:-}" <<'NODE'
import fs from "node:fs";

const [packagePath, lockPath, manifestPath, expectedVersion, refType, refName] = process.argv.slice(2);
const pkg = JSON.parse(fs.readFileSync(packagePath, "utf8"));
const lock = JSON.parse(fs.readFileSync(lockPath, "utf8"));
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));

function fail(message) {
  console.error(message);
  process.exit(1);
}

if (pkg.name !== "@topogram/template-todo") {
  fail(`Expected package name @topogram/template-todo, found ${pkg.name}`);
}

if (manifest.id !== "@topogram/template-todo") {
  fail(`Expected template id @topogram/template-todo, found ${manifest.id}`);
}

const packageVersion = pkg.version;
const lockVersion = lock.version;
const lockRootVersion = lock.packages?.[""]?.version;
const manifestVersion = manifest.version;

if (!packageVersion) {
  fail("package.json is missing version");
}

if (lockVersion !== packageVersion) {
  fail(`package-lock.json version ${lockVersion} does not match package version ${packageVersion}`);
}

if (lockRootVersion !== packageVersion) {
  fail(`package-lock.json root package version ${lockRootVersion} does not match package version ${packageVersion}`);
}

if (manifestVersion !== packageVersion) {
  fail(`topogram-template.json version ${manifestVersion} does not match package version ${packageVersion}`);
}

if (expectedVersion && expectedVersion !== packageVersion) {
  fail(`Requested publish version ${expectedVersion} does not match committed package version ${packageVersion}. Run npm run release:prepare -- ${expectedVersion} and commit it first.`);
}

if (refType === "tag" && refName?.startsWith("topogram-template-todo-v")) {
  const tagVersion = refName.slice("topogram-template-todo-v".length);
  if (tagVersion !== packageVersion) {
    fail(`Release tag ${refName} does not match committed package version ${packageVersion}`);
  }
}

console.log(`Todo template release version check passed: ${packageVersion}`);
NODE
