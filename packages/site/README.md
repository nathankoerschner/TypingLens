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

## CSP

A strict Content-Security-Policy with `connect-src 'none'`, `frame-ancestors 'none'`, `base-uri 'none'`, and `form-action 'none'` is set both in `public/_headers` (for hosting) and in the HTML `<meta http-equiv>` tag. The built JS does no network I/O and uses no browser storage APIs.

## Upstream attribution

Portions of this package (HTML scaffolding, `site.css`, the SVG assets) were adapted from the upstream project [`FlanaganSe/typing-lens`](https://github.com/FlanaganSe/TypingLens) under MIT. See `NOTICE`. Licence alignment with this repo's GPL-3.0 is **flagged for review** before public release.
