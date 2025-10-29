import { test, expect } from "bun:test";
import { Database } from "bun:sqlite";
import TestApp from "./TestApp.elm";

test("TestApp should execute migrations and queries correctly", async () => {
  // Create in-memory SQLite database
  const db = new Database(":memory:");

  // Initialize the Elm app
  const app = TestApp.init({
    flags: null,
  });
  return new Promise((resolve, reject) => {
    app.ports.operations.subscribe(async (op) => {
      try {
        const { insert, migrate, query } = op as {
          insert: string;
          migrate: string;
          query: string;
        };
        console.log("query:", migrate);
        // await db.run("CREATE TABLE USERS (id INTEGER)");
        await db.run(`CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        age INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

`);
        const x = await db.query(insert).run();
        const y = await db.query(query).get();
        console.log("x:", y);

        // db.exec(operation.payload);
        resolve(op);
      } catch (error) {
        reject(error);
      }
    });
  });
});
