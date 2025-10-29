import { $ } from "bun";

export interface GenerateResult {
  queries: string;
  migrations: string;
}

export async function generate(filePath: string): Promise<GenerateResult> {
  // Read the ORM file content
  const ormContent = await Bun.file(filePath).text();
  
  // Ensure the generator is compiled
  await $`elm make src/Generator.elm --output=generator.js`;

  // Create a script to run the Elm worker
  const script = `
    const fs = require('fs');
    const vm = require('vm');
    
    // Read and execute the Elm compiled code
    const elmCode = fs.readFileSync('./generator.js', 'utf8');
    const sandbox = { 
      console, 
      require, 
      module: { exports: {} }, 
      exports: {},
      setTimeout,
      setInterval,
      clearTimeout,
      clearInterval,
      Buffer,
      process,
      global: {}
    };
    
    // Create Elm in the sandbox
    sandbox.this = sandbox;
    vm.createContext(sandbox);
    vm.runInContext(elmCode, sandbox);
    
    const { Elm } = sandbox;
    const app = Elm.Generator.init({ flags: ${JSON.stringify(ormContent)} });
    
    let queries = '';
    let migrations = '';
    let receivedCount = 0;
    
    app.ports.sendQueries.subscribe((data) => {
      queries = data;
      receivedCount++;
      if (receivedCount === 2) {
        console.log(JSON.stringify({ queries, migrations }));
        process.exit(0);
      }
    });
    
    app.ports.sendMigrations.subscribe((data) => {
      migrations = data;
      receivedCount++;
      if (receivedCount === 2) {
        console.log(JSON.stringify({ queries, migrations }));
        process.exit(0);
      }
    });
  `;

  // Run the script and parse the result
  const result = await $`node -e ${script}`.text();
  return JSON.parse(result.trim());
}