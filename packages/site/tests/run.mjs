import { readdir, readFile, stat } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const DIST = resolve(here, "..", "dist");

let failed = 0;
const check = (label, predicate) => {
  const ok = Boolean(predicate);
  console.log(`${ok ? "OK  " : "FAIL"} ${label}`);
  if (!ok) failed++;
};

const REPO_URL = "github.com/nathankoerschner/TypingLens";
const IMAGE_EXT = /\.(svg|png|webp)$/i;

let distStat;
try {
  distStat = await stat(DIST);
} catch {
  console.error(`dist/ missing at ${DIST} — run \`pnpm build\` first`);
  process.exit(1);
}
check("dist/ is a directory", distStat.isDirectory());

const indexPath = resolve(DIST, "index.html");
let html = "";
try {
  html = await readFile(indexPath, "utf8");
} catch {
  console.error("dist/index.html missing");
  process.exit(1);
}
check("dist/index.html is non-empty", html.length > 0);

check(
  "CSP meta sets connect-src 'none'",
  /<meta[^>]+Content-Security-Policy[\s\S]*?connect-src\s+'none'/i.test(html),
);
check(
  "CSP meta sets base-uri 'none'",
  /<meta[^>]+Content-Security-Policy[\s\S]*?base-uri\s+'none'/i.test(html),
);
check(
  "CSP meta sets form-action 'none'",
  /<meta[^>]+Content-Security-Policy[\s\S]*?form-action\s+'none'/i.test(html),
);
check(
  "CSP meta or _headers sets frame-ancestors 'none'",
  /<meta[^>]+Content-Security-Policy[\s\S]*?frame-ancestors\s+'none'/i.test(html) ||
    /frame-ancestors\s+'none'/.test(await readSafe(resolve(DIST, "_headers"))),
);

const headers = await readSafe(resolve(DIST, "_headers"));
check("dist/_headers exists", headers.length > 0);
check("dist/_headers enforces frame-ancestors 'none'", /frame-ancestors\s+'none'/.test(headers));

const assetsDir = resolve(DIST, "assets");
let assetEntries = [];
try {
  assetEntries = await readdir(assetsDir);
} catch {
  // No assets dir is fine — treat as zero JS files.
}
const jsFiles = assetEntries.filter((n) => n.endsWith(".js"));
const networkTokens = [
  "fetch(",
  "XMLHttpRequest",
  "navigator.sendBeacon",
  "WebSocket",
  "EventSource",
];
const storageTokens = ["localStorage", "indexedDB", "document.cookie"];

for (const name of jsFiles) {
  const body = await readFile(resolve(assetsDir, name), "utf8");
  for (const token of networkTokens) {
    check(`assets/${name} has no ${token}`, !body.includes(token));
  }
  for (const token of storageTokens) {
    check(`assets/${name} has no ${token}`, !body.includes(token));
  }
}
if (jsFiles.length === 0) {
  console.log("note  no dist/assets/*.js emitted — network/storage token scans vacuous");
}

const urls = [...html.matchAll(/https?:\/\/[^\s"'<>)]+/gi)].map((m) => m[0]);
const offending = urls.filter((u) => !u.startsWith(`https://${REPO_URL}`));
check(`index.html has no external URLs outside ${REPO_URL}`, offending.length === 0);
if (offending.length > 0) {
  for (const u of offending) console.log(`     offending URL: ${u}`);
}

const distFiles = await walk(DIST);
const distBasenames = new Set(distFiles.map((p) => p.split("/").pop()));
const htmlImageRefs = [...html.matchAll(/(?:src|href)=["']([^"']+)["']/gi)]
  .map((m) => m[1])
  .filter((u) => IMAGE_EXT.test(u))
  .filter((u) => !/^https?:\/\//i.test(u));
const referencedImageShipped = htmlImageRefs.some((u) => {
  const base = u.split("/").pop().split("?")[0].split("#")[0];
  return distBasenames.has(base);
});
check("index.html references a same-origin image asset present in dist/", referencedImageShipped);

check(`index.html links to ${REPO_URL}`, html.includes(REPO_URL));
check("index.html links to a /releases/latest URL", /releases\/latest(?!\/download\/)/.test(html));
check(
  "index.html has no /releases/latest/download/ asset URL",
  !html.includes("/releases/latest/download/"),
);
check("index.html has no versioned TypingLens release asset", !/TypingLens-(?:v|\d)/.test(html));

if (failed > 0) {
  console.error(`\n${failed} failure(s)`);
  process.exit(1);
}
console.log("\nall site static checks passed");

async function readSafe(path) {
  try {
    return await readFile(path, "utf8");
  } catch {
    return "";
  }
}

async function walk(dir) {
  const out = [];
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const path = resolve(dir, entry.name);
    if (entry.isDirectory()) out.push(...(await walk(path)));
    else out.push(path);
  }
  return out;
}
