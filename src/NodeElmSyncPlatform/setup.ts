type ReadFileResult = { absolutePath: string; content: string };
type Methods = {
  readAllFilesInDirectory: {
    [key: string]: ReadFileResult[];
  };
};

const router: ProxyHandler<Methods> = {
  get(
    target,
    prop,
    receiver
  ): {
    readAllFilesInDirectory: {
      [key: string]: ReadFileResult[];
    };
  } {
    return new Proxy(target, handlers[prop as keyof typeof handlers]);
  },
};
import { readdirSync, readFileSync } from "fs";
const handlers = {
  readAllFilesInDirectory: {
    get(_: any, arg_path: string, __: any): ReadFileResult[] {
      console.log("readAllFilesInDirectory", arg_path);
      const files = readDirSyncRecursive(arg_path);
      console.log("files", files);
      return files;
    },
  },
};
import { statSync } from "fs";
const isDirectory = (path: string): boolean => {
  return statSync(path).isDirectory();
};

import path from "path";
const readDirSyncRecursive = (dir_path: string): ReadFileResult[] => {
  return readdirSync(dir_path).flatMap((file): ReadFileResult[] => {
    const filePath = path.join(dir_path, file);
    if (isDirectory(filePath)) {
      return readDirSyncRecursive(filePath);
    }
    console.log("readFileSync", filePath);
    return [
      {
        absolutePath: filePath,
        content: readFileSync(filePath, "utf8"),
      },
    ];
  });
};

export const interop = new Proxy<Methods>(
  {
    readAllFilesInDirectory: {},
  },
  // stub this to shut up the compiler, is a noop
  router
);

Object.defineProperty(Object.prototype, "__elm_node_platform", {
  value: interop,
});
