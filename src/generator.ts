console.log("Generator: module loaded");

export interface GenerateResult {
  queries: string;
  migrations: string;
}
import Generator from "./Generator.elm";

export async function generate(filePath: string): Promise<GenerateResult> {
  // Read the ORM file content
  const ormContent = await Bun.file(filePath).text();

  try {
    // Import the Elm module directly using Bun's Elm plugin
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
  console.log("Generator:", Generator);
}
