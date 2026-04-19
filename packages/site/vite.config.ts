import { defineConfig, type Plugin } from "vite";

const stripCspInDev: Plugin = {
  name: "strip-csp-in-dev",
  apply: "serve",
  transformIndexHtml(html) {
    return html.replace(/\s*<meta\s+http-equiv="Content-Security-Policy"[\s\S]*?>\s*/i, "\n    ");
  },
};

export default defineConfig({
  base: "./",
  plugins: [stripCspInDev],
  build: {
    emptyOutDir: true,
    modulePreload: { polyfill: false },
    outDir: "dist",
    sourcemap: false,
  },
});
