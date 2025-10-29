import { build } from "bun";
import { elmPlugin } from "@janwirth/bun-plugin-elm";

await build({
  entrypoints: ["./src/Generator.elm"],
  plugins: [elmPlugin()],
  outdir: "./dist",
});