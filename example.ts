import { generate } from "./src/generator";

async function main() {
  console.log("🚀 Generating Elm ORM code from src/ORM.elm...\n");
  
  try {
    const result = await generate("src/ORM.elm");
    
    console.log("✅ Generation completed!\n");
    
    console.log("📄 Generated Migrations:");
    console.log("=" .repeat(50));
    console.log(result.migrations);
    console.log("\n");
    
    console.log("📄 Generated Queries:");
    console.log("=" .repeat(50));
    console.log(result.queries);
    
  } catch (error) {
    console.error("❌ Generation failed:", error);
    process.exit(1);
  }
}

main();