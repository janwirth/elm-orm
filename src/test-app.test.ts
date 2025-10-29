import { test, expect } from "bun:test";
import { Database } from "bun:sqlite";
console.log("Bun:", Bun);
import TestApp from "./TestApp.elm";

test("TestApp should execute migrations and queries correctly", async () => {
  // Create in-memory SQLite database
  const db = new Database(":memory:");

  // Initialize the Elm app
  const app = TestApp.init({
    flags: null,
  });

  // Set up port handlers
  app.ports.executeMigration.subscribe((migrationSql: string) => {
    try {
      db.exec(migrationSql);
      app.ports.queryResult.send({
        success: true,
        type: "migration",
        sql: migrationSql,
      });
    } catch (error) {
      app.ports.queryResult.send({
        success: false,
        type: "migration",
        error: String(error),
        sql: migrationSql,
      });
    }
  });

  app.ports.executeQuery.subscribe(
    ({ query, params }: { query: string; params: any[] }) => {
      try {
        const stmt = db.prepare(query);
        let result;

        if (query.trim().toLowerCase().startsWith("select")) {
          result = stmt.all(...params);
        } else {
          result = stmt.run(...params);
        }

        app.ports.queryResult.send({
          success: true,
          type: "query",
          sql: query,
          result: result,
        });
      } catch (error) {
        app.ports.queryResult.send({
          success: false,
          type: "query",
          error: String(error),
          sql: query,
        });
      }
    }
  );

  // Wait for test completion
  return new Promise<void>((resolve, reject) => {
    const timeout = setTimeout(() => {
      db.close();
      reject(new Error("Test timed out"));
    }, 5000);

    // Listen for test completion message
    app.ports.queryResult.subscribe((result: any) => {
      if (result.type === "testComplete") {
        clearTimeout(timeout);

        // Verify the database state
        const users = db.prepare("SELECT * FROM users").all();
        const todos = db.prepare("SELECT * FROM todos").all();

        expect(users.length).toBeGreaterThan(0);
        expect(todos.length).toBeGreaterThan(0);

        db.close();
        resolve();
      }
    });
  });
});
