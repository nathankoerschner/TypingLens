import { defineConfig, type Plugin } from "vite";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));

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
    rollupOptions: {
      input: {
        main: resolve(here, "index.html"),
        camera: resolve(here, "camera.html"),
      },
    },
  },
});
