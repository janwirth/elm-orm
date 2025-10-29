import { test, expect } from "bun:test";
import { generate } from "./generator";

test("Generated queries should match fixture exactly", async () => {
  const expectedQueries = await Bun.file("fixtures/expected-queries.elm").text();
  
  const result = await generate("src/ORM.elm");
  
  expect(result.queries.trim()).toBe(expectedQueries.trim());
});

test("Generated migrations should match fixture exactly", async () => {
  const expectedMigrations = await Bun.file("fixtures/expected-migrations.elm").text();
  
  const result = await generate("src/ORM.elm");
  
  expect(result.migrations.trim()).toBe(expectedMigrations.trim());
});