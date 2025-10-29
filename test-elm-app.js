#!/usr/bin/env bun

import { spawn } from "bun";
import fs from "fs";
import path from "path";

async function main() {
  console.log("Compiling Elm app...");

  // Make sure the output directory exists
  const outputDir = path.join(process.cwd(), "elm-stuff", "compiled");
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // Compile the Elm app
  const elmMake = spawn({
    cmd: [
      "elm",
      "make",
      "src/TestApp.elm",
      "--output",
      path.join(outputDir, "TestApp.js"),
    ],
    stdout: "pipe",
    stderr: "pipe",
  });

  const elmMakeOutput = await elmMake.text();
  const elmMakeExitCode = await elmMake.exited;

  if (elmMakeExitCode !== 0) {
    console.error("Failed to compile Elm app:");
    console.error(elmMakeOutput);
    process.exit(1);
  }

  console.log("Elm app compiled successfully!");

  // Run the test runner
  console.log("Running tests...");
  const testRunner = spawn({
    cmd: ["bun", "run", "src/test-runner.js"],
    stdout: "pipe",
    stderr: "pipe",
  });

  const testOutput = await testRunner.text();
  const testExitCode = await testRunner.exited;

  console.log(testOutput);

  if (testExitCode !== 0) {
    console.error("Tests failed!");
    process.exit(1);
  }

  console.log("Tests passed!");
}

main().catch((error) => {
  console.error("Error:", error);
  process.exit(1);
});
