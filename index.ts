#!/usr/bin/env bun
import { Command } from "commander";
import { mkdir } from "node:fs/promises";
import { generate, type GenerateResult } from "./src/generator";

const program = new Command();

program
  .name("elm-orm")
  .description("Generate Elm ORM migrations and queries from a schema file")
  .version("0.1.0")
  .argument("<schema-file>", "Path to the Elm schema file")
  .option(
    "-o, --output-dir <directory>",
    "Output directory for generated files",
    "./Generated"
  )
  .action(async (schemaFile: string, options: { outputDir: string }) => {
    try {
      console.log(`Generating ORM files from ${schemaFile}...`);

      // Generate the ORM files
      const result = await generate(schemaFile);

      // Ensure the output directory exists
      await mkdir(options.outputDir, { recursive: true });

      // Write the generated files
      const migrationsPath = `${options.outputDir}/Migrations.elm`;
      const queriesPath = `${options.outputDir}/Queries.elm`;

      await Bun.write(migrationsPath, result.migrations);
      await Bun.write(queriesPath, result.queries);

      console.log("Generated files successfully written to:");
      console.log(`- ${migrationsPath}`);
      console.log(`- ${queriesPath}`);
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : String(error);
      console.error(`Error: ${errorMessage}`);
      process.exit(1);
    }
  });

// Parse command line arguments
program.parse();
