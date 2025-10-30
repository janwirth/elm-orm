// Proxy element that will work like
import { test, expect } from "bun:test";
type Methods = {
  readAllFilesInDirectory: {
    [key: string]: { relativePath: string; content: string }[];
  };
};

const router: ProxyHandler<Methods> = {
  get(
    target,
    prop,
    receiver
  ): {
    readAllFilesInDirectory: {
      [key: string]: { relativePath: string; content: string }[];
    };
  } {
    return new Proxy(target, handlers[prop as keyof typeof handlers]);
  },
};
import { readdirSync, readFileSync } from "fs";
const handlers = {
  readAllFilesInDirectory: {
    get(
      target,
      arg_path: string,
      receiver
    ): { relativePath: string; content: string }[] {
      console.log("readAllFilesInDirectory", arg_path);
      return readDirSyncRecursive(arg_path);
    },
  },
};
import { statSync } from "fs";
const isDirectory = (path: string): boolean => {
  return statSync(path).isDirectory();
};

import path from "path";
const readDirSyncRecursive = (
  path: string
): { relativePath: string; content: string }[] => {
  return readdirSync(path).flatMap((file) => {
    if (isDirectory(file)) {
      return readDirSyncRecursive(path.join(path, file));
    }
    console.log("readFileSync", path.join(path, file));
    return [
      {
        relativePath: file,
        content: readFileSync(path.join(path, file), "utf8"),
      },
    ];
  });
};

const interop = new Proxy({}, router);
test.only("proxy fs access", () => {
  // we need this to load test fixtures
  const results: { relativePath: string; content: string }[] =
    interop.readAllFilesInDirectory["fixtures"];
  expect(results.length).toBeGreaterThan(5);
  const foundAdvancedSchema = results.find(
    (result) => result.relativePath === "fixtures/AdvancedSchema.elm"
  );
  expect(foundAdvancedSchema?.content).toInclude(
    "module AdvancedSchema exposing (..)"
  );
  const foundSchema = results.find(
    (result) => result.relativePath === "fixtures/Schema.elm"
  );
  expect(foundSchema?.content).toInclude("module Schema exposing (..)");
});
