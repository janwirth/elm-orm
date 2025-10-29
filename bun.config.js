import { plugin } from "bun";
import { elmPlugin } from "@janwirth/bun-plugin-elm";

plugin(elmPlugin());
console.log("Generator: plugin loaded");
