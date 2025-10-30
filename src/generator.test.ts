import { test, expect } from "bun:test";
import { generate } from "./generator";

test("Generated queries should match fixture exactly", async () => {
  const expectedQueries = await Bun.file(
    "fixtures/Generated/Queries.elm"
  ).text();

  const result = await generate("fixtures/Schema.elm");

  expect(result.queries.trim()).toBe(expectedQueries.trim());
});

test("Generated migrations should match fixture exactly", async () => {
  const expectedMigrations = await Bun.file(
    "fixtures/Generated/Migrations.elm"
  ).text();

  const result = await generate("fixtures/Schema.elm");

  expect(result.migrations.trim()).toBe(expectedMigrations.trim());
});

test("Generated queries should match fixture exactly", async () => {
  const expectedQueries = await Bun.file(
    "fixtures/GeneratedAdvanced/Queries.elm"
  ).text();

  const result = await generate("fixtures/AdvancedSchema.elm");

  expect(result.queries.trim()).toBe(expectedQueries.trim());
});

test("Generated migrations should match fixture exactly", async () => {
  const expectedMigrations = await Bun.file(
    "fixtures/GeneratedAdvanced/AdvancedMigrations.elm"
  ).text();

  const result = await generate("fixtures/AdvancedSchema.elm");

  expect(result.migrations.trim()).toBe(expectedMigrations.trim());
});
