console.log("Generator: module loaded");

import { mkdir } from "node:fs/promises";

export interface GenerateResult {
  queries: string;
  migrations: string;
}

export async function generate(filePath: string): Promise<GenerateResult> {
  // Read the ORM file content
  const ormContent = await Bun.file(filePath).text();

  try {
    // Import the Elm module directly using Bun's Elm plugin
    // @ts-ignore - Elm modules don't have TypeScript declarations
    const GeneratorModule = await import("../src/Generator.elm");

    // The plugin exports the module as default
    const Generator = GeneratorModule.default || GeneratorModule.Generator;

    if (!Generator) {
      throw new Error("Generator module not found in Elm compilation output");
    }

    return new Promise<GenerateResult>((resolve, reject) => {
      const app = Generator.init({ flags: ormContent });

      let queries = "";
      let migrations = "";
      let receivedCount = 0;

      const checkComplete = () => {
        if (receivedCount === 2) {
          resolve({ queries, migrations });
        }
      };

      app.ports.sendQueries.subscribe((data: string) => {
        queries = data;
        receivedCount++;
        checkComplete();
      });

      app.ports.sendMigrations.subscribe((data: string) => {
        migrations = data;
        receivedCount++;
        checkComplete();
      });

      // Add timeout to prevent hanging
      setTimeout(() => {
        reject(new Error("Generator timed out"));
      }, 10000);
    });
  } catch (error) {
    throw new Error(`Failed to load Elm generator: ${error}`);
  }
}
if (import.meta.main) {
  // Create and run the generator with the ORM file
  const result = await generate("./src/ORM.elm");

  // Ensure the Generated directory exists
  await mkdir("./Generated", { recursive: true });

  // Write the generated files
  await Bun.write("./Generated/Migrations.elm", result.migrations);
  await Bun.write("./Generated/Queries.elm", result.queries);

  console.log("Generated files successfully written to:");
  console.log("- Generated/Migrations.elm");
  console.log("- Generated/Queries.elm");
}
