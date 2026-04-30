# Topogram Todo Template

Private Topogram template pack for the generated Todo demo app.

## Usage

```bash
topogram new ./todo-demo --template @attebury/topogram-template-todo
cd ./todo-demo
npm install
npm run check
npm run generate
npm run verify
```

This template includes executable implementation provider JavaScript under `implementation/`.
Use it as trusted code from the `@attebury` package scope.

## Runtime Semantics

This template owns the Todo product semantics for the generated SvelteKit,
Hono, and Postgres app. Runtime checks are intentionally template-specific, not
engine tests.

The full generated runtime check exercises bearer-demo auth and lifecycle
behavior. Manager/admin endpoints such as export read/download/delete require
`TOPOGRAM_AUTH_ROLES=manager` and `TOPOGRAM_AUTH_ADMIN=true`; web-facing checks
still verify user-scoped behavior with the public demo auth environment.

## Verification

```bash
npm run pack:check
```

This runs reusable template conformance with `topogram template check`, packs the template, creates a disposable starter with `topogram new --template <tarball>`, installs the starter, runs `npm run check`, runs `npm run generate`, and verifies the generated app sentinel.

By default the smoke test installs `@attebury/topogram@0.2.33`. Override it with:

```bash
TOPOGRAM_CLI_PACKAGE_SPEC=/path/to/attebury-topogram-0.2.33.tgz npm run pack:check
```

## Release

```bash
npm run release:prepare -- 0.1.2
npm run release:check
npm run pack:check
```

Commit the updated package metadata, then publish with the `Publish Template Package` GitHub Actions workflow. The workflow publishes the committed version and can create a `topogram-template-todo-v<version>` tag.
