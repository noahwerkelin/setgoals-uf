// @lovable.dev/vite-tanstack-config already includes the following — do NOT add them manually
// or the app will break with duplicate plugins:
//   - tanstackStart, viteReact, tailwindcss, tsConfigPaths, nitro (build-only using cloudflare as a default target),
//     componentTagger (dev-only), VITE_* env injection, @ path alias, React/TanStack dedupe,
//     error logger plugins, and sandbox detection (port/host/strictPort).
// You can pass additional config via defineConfig({ vite: { ... }, etc... }) if needed.
import { defineConfig } from "@lovable.dev/vite-tanstack-config";
import { loadEnv } from "vite";
import path from "path";

// Server routes (e.g. /lovable/email/*) need non-VITE_ env vars such as
// LOVABLE_API_KEY in process.env. The wrapper only injects VITE_* vars for
// client code, so load the rest here for server-side use only. Never add
// these to a define block — that would leak secrets into the client bundle.
const serverEnv = loadEnv(process.env.NODE_ENV ?? "development", process.cwd(), "");
Object.assign(process.env, serverEnv);

export default defineConfig({
  tanstackStart: {
    // Redirect TanStack Start's bundled server entry to src/server.ts (our SSR error wrapper).
    // nitro/vite builds from this
    server: { entry: "server" },
  },
  vite: {
    resolve: {
      alias: [
        // htmlparser2 pulls in a nested entities v7 copy that breaks SSR
        // (v7 removed ./lib/decode.js). Force every import to the hoisted
        // v4.5.0 copy pinned via package.json overrides. Subpath aliases must
        // come before the root alias, and the root alias is exact-match only
        // so it doesn't rewrite "entities/decode" to a missing file.
        {
          find: "entities/lib/decode.js",
          replacement: path.resolve(__dirname, "node_modules/entities/lib/decode.js"),
        },
        {
          find: "entities/lib/encode.js",
          replacement: path.resolve(__dirname, "node_modules/entities/lib/encode.js"),
        },
        {
          find: "entities/decode",
          replacement: path.resolve(__dirname, "node_modules/entities/lib/decode.js"),
        },
        {
          find: "entities/encode",
          replacement: path.resolve(__dirname, "node_modules/entities/lib/encode.js"),
        },
        {
          find: /^entities$/,
          replacement: path.resolve(__dirname, "node_modules/entities"),
        },
      ],
    },
  },
});
