import { build } from "bun";
import { elmPlugin } from "@janwirth/bun-plugin-elm";

await build({
  entrypoints: ["./index.ts"],
  plugins: [elmPlugin()],
  outdir: "./dist",
  target: "bun"
});
console.log("built with elm plugin")
