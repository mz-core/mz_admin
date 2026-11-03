import { resolve } from "node:path"
import tailwindcss from "@tailwindcss/vite"
import react from "@vitejs/plugin-react"
import { defineConfig } from "vite"

// Build-only workspace for mz_admin. The output is copied directly into the
// FiveM resource runtime folder. Nothing here ships with the resource.
export default defineConfig({
  base: "./",
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      "@": resolve(import.meta.dirname, "./src"),
    },
  },
  build: {
    outDir: resolve(import.meta.dirname, "../web"),
    emptyOutDir: true,
    sourcemap: false,
    // Keep the bundle readable so the FiveM package can be audited and the
    // existing static NUI contract checks can inspect real implementation
    // strings without depending on a source map.
    minify: false,
    cssMinify: false,
    rollupOptions: {
      output: {
        entryFileNames: "app.js",
        chunkFileNames: "chunks/[name].js",
        assetFileNames: (assetInfo) => {
          const name = assetInfo.name ?? ""
          if (name.endsWith(".css")) return "style.css"
          return "assets/[name][extname]"
        },
      },
    },
  },
})
