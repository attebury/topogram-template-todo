# Consumer Proof

This repo publishes an executable Todo template package. Verification must prove
that the packed template can create a project and that generated Todo output
compiles before the package is published.

## Required Gate

```bash
npm run pack:check
```

The check must:

- install the Topogram CLI package pinned in `topogram-cli.version`;
- pack `@topogram/template-todo`;
- run `topogram template check <tarball>`;
- create a disposable starter with `topogram new --template <tarball>`;
- install starter dependencies;
- run `doctor`, query/source/template trust commands, `check`, and
  component-behavior proof;
- run `npm run generate`;
- run `npm --prefix app run compile` after generation.

## Not Acceptable

- Treating the external demo repo as the only compile proof for this package.
- Generate-only package smoke tests.
- Sentinel-only checks such as only verifying `app/.topogram-generated.json`.
- Fake template/package installs in consumer-facing verification.
- Stale hard-coded `@topogram/cli@x.y.z` literals instead of
  `topogram-cli.version`.
