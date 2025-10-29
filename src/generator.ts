import { mkdir } from "node:fs/promises";
import Generator from "./Generator.elm";
console.log("Generator:", Generator);

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

    // Initialize the Elm app
    const app = Generator.init({ flags: ormContent });

    return new Promise<GenerateResult>((resolve, reject) => {
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
    console.error("Error details:", error);
    throw new Error(`Failed to load Elm generator: ${error}`);
  }
}
