// Proxy element that will work like
import { test, expect } from "bun:test";
import { interop } from "./Fs.elm.platform";

test.only("proxy fs access", () => {
  // we need this to load test fixtures
  const results = interop.readAllFilesInDirectory["fixtures"]!;
  expect(results.length).toBeGreaterThan(5);
  const foundAdvancedSchema = results.find(
    (result) => result.absolutePath === "fixtures/AdvancedSchema.elm"
  );
  expect(foundAdvancedSchema?.content).toInclude(
    "module AdvancedSchema exposing (..)"
  );
  const foundSchema = results.find(
    (result) => result.absolutePath === "fixtures/Schema.elm"
  );
  expect(foundSchema?.content).toInclude("module Schema exposing (..)");
});
