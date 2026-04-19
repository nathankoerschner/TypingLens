# @typinglens/site

Marketing site for [TypingLens](https://github.com/nathankoerschner/TypingLens). Optional for Mac-app contributors.

## Commands

From the repo root:

- `pnpm dev` — local dev server on http://127.0.0.1:5173
- `pnpm build` — produces `packages/site/dist/`
- `pnpm test` — builds, then runs the privacy/CSP scan
- `pnpm lint` — Biome over JS/TS

## CI

`/.github/workflows/site.yml` at the repo root handles web CI. It is path-filtered so it does not trigger on Swift-only changes.
