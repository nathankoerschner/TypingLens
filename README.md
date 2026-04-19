<p align="center">
  <img src="https://raw.githubusercontent.com/nathankoerschner/TypingLens/main/docs/banner.png?v=3" alt="TypingLens" width="800">
</p>

<p align="center">
  <img alt="macOS" src="https://img.shields.io/badge/macOS-13%2B-18181b?style=flat-square">
  <img alt="Privacy" src="https://img.shields.io/badge/privacy-local--only-18181b?style=flat-square">
  <img alt="UI" src="https://img.shields.io/badge/UI-SwiftUI-18181b?style=flat-square">
  <img alt="CI" src="https://img.shields.io/github/actions/workflow/status/nathankoerschner/TypingLens/ci.yml?style=flat-square&label=CI">
</p>

## About

TypingLens is designed for proficient typists who want to improve beyond generic typing tests.
It analyzes your typing history locally, identifies the patterns and words that consistently slow you down, and turns them into focused practice.
Instead of drilling random word lists, you practice against your actual weaknesses.

## How it works

1. **Capture local typing data**  
   TypingLens records typing activity locally on your Mac.

2. **Rank what slows you down**  
   It analyzes your history to surface the words and typing patterns most associated with lost speed and mistakes.

3. **Practice against real weaknesses**  
   It generates drills and analytics from those results, giving you practice that reflects how you actually type.

## Marketing site

The marketing site lives in [`packages/site/`](packages/site/). See [`packages/site/README.md`](packages/site/README.md) for more.

From the repo root:

- `pnpm install` — install Node toolchain (requires Node 22 and pnpm 10)
- `pnpm build` — build the site into `packages/site/dist/`
- `pnpm test` — build, then run the privacy/CSP scan

## License

TypingLens is licensed under the GNU General Public License v3.0, in the same spirit as Monkeytype.
See [`LICENSE`](./LICENSE).
