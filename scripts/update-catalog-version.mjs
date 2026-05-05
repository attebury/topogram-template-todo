import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);
const checkOnly = args.includes("--check");
const catalogArg = args.find((arg) => !arg.startsWith("-"));

if (!catalogArg) {
  fail("Usage: node scripts/update-catalog-version.mjs <topograms.catalog.json> [--check]");
}

const catalogPath = path.resolve(process.cwd(), catalogArg);
if (!fs.existsSync(catalogPath)) {
  fail(`Catalog file not found: ${catalogPath}`);
}

const pkg = readJson(path.join(root, "package.json"));
const manifest = readJson(path.join(root, "topogram-template.json"));

if (pkg.name !== "@topogram/template-todo") {
  fail(`Expected package name @topogram/template-todo, found ${pkg.name}`);
}
if (manifest.id !== pkg.name) {
  fail(`Template manifest id ${manifest.id} must match package name ${pkg.name}.`);
}
if (!pkg.version) {
  fail("package.json is missing version.");
}
if (manifest.version !== pkg.version) {
  fail(`Template manifest version ${manifest.version} must match package version ${pkg.version}.`);
}

const catalog = readJson(catalogPath);
if (!Array.isArray(catalog.entries)) {
  fail("Catalog must contain an entries array.");
}

const todoEntry = catalog.entries.find((entry) => entry?.id === "todo");
if (!todoEntry) {
  fail("Catalog is missing the todo entry.");
}
if (todoEntry.package !== pkg.name) {
  fail(`Catalog todo entry package ${todoEntry.package} must be ${pkg.name}.`);
}

if (todoEntry.defaultVersion === pkg.version) {
  console.log(`Catalog todo version already matches ${pkg.version}.`);
  process.exit(0);
}

const from = todoEntry.defaultVersion || "(missing)";
if (checkOnly) {
  console.error(`todo: ${from} -> ${pkg.version}`);
  fail(`Catalog todo version is out of date in ${catalogPath}`);
}

todoEntry.defaultVersion = pkg.version;
fs.writeFileSync(catalogPath, `${JSON.stringify(catalog, null, 2)}\n`, "utf8");
console.log(`Updated catalog todo version in ${catalogPath}: ${from} -> ${pkg.version}`);

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function fail(message) {
  console.error(message);
  process.exit(1);
}
